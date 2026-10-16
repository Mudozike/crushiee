import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../models/connection_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/post_card.dart';
import '../../widgets/contact_reveal_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/crushie_avatar.dart';
import '../../widgets/report_modal.dart';
import '../../models/report_model.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../premium/premium_subscription_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String? userId; // Null means current user profile
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenVerification;
  final VoidCallback? onOpenPremium;

  const ProfileScreen({
    Key? key,
    this.userId,
    this.onOpenSettings,
    this.onOpenVerification,
    this.onOpenPremium,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final postProv = Provider.of<PostProvider>(context);
    final connProv = Provider.of<ConnectionProvider>(context);
    final userProv = Provider.of<UserProvider>(context);
    final dbService = DatabaseService();

    final currentUser = authProv.currentUser;
    final targetUserId = userId ?? currentUser?.id ?? '';
    final isSelf = currentUser != null &&
        targetUserId.isNotEmpty &&
        currentUser.id == targetUserId;

    if (isSelf) {
      if (currentUser == null) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return _buildProfileScaffold(
        context: context,
        user: currentUser,
        isSelf: true,
        currentUser: currentUser,
        userProv: userProv,
        dbService: dbService,
        postProv: postProv,
        connProv: connProv,
        isDark: isDark,
      );
    }

    if (targetUserId.trim().isEmpty) {
      return const Scaffold(
        body: Center(child: Text('User profile not found.')),
      );
    }

    return StreamBuilder<UserModel?>(
      stream: FirestoreService().getUserProfileStream(targetUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          final cachedUser = dbService.getUser(targetUserId);
          if (cachedUser != null) {
            return _buildProfileScaffold(
              context: context,
              user: cachedUser,
              isSelf: false,
              currentUser: currentUser,
              userProv: userProv,
              dbService: dbService,
              postProv: postProv,
              connProv: connProv,
              isDark: isDark,
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final errorMsg = error is FirebaseException &&
                  error.code == 'permission-denied'
              ? 'Access denied: you do not have permission to view this profile.'
              : 'Error loading profile. Please check your connection.';
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      errorMsg,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.maybePop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: const Center(child: Text('User profile not found.')),
          );
        }

        // Cache loaded user
        dbService.updateUser(user);

        return _buildProfileScaffold(
          context: context,
          user: user,
          isSelf: false,
          currentUser: currentUser,
          userProv: userProv,
          dbService: dbService,
          postProv: postProv,
          connProv: connProv,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildProfileScaffold({
    required BuildContext context,
    required UserModel user,
    required bool isSelf,
    required UserModel? currentUser,
    required UserProvider userProv,
    required DatabaseService dbService,
    required PostProvider postProv,
    required ConnectionProvider connProv,
    required bool isDark,
  }) {
    final isBlocked =
        currentUser != null && userProv.isUserBlocked(currentUser.id, user.id);
    final isFollowing = userProv.isFollowing(user.id);
    final userPosts =
        postProv.filteredPosts.where((p) => p.userId == user.id).toList();

    final isConnected = currentUser != null &&
        dbService.connections.any((c) =>
            ((c.senderId == currentUser.id && c.recipientId == user.id) ||
                (c.senderId == user.id && c.recipientId == currentUser.id)) &&
            c.status == ConnectionStatus.accepted);

    // Contact details are strictly gated: Only Premium users (or self) can view contact details
    final canViewPrivateDetails = isSelf || (currentUser?.isPremium ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text('@${user.username}'),
        actions: [
          if (isSelf && onOpenSettings != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: onOpenSettings,
            )
          else if (!isSelf && currentUser != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (val) async {
                if (val == 'block') {
                  if (isBlocked) {
                    await userProv.unblockUser(currentUser.id, user.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unblocked @${user.username}')),
                      );
                    }
                  } else {
                    await userProv.blockUser(currentUser.id, user.id,
                        targetUsername: user.username);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Blocked @${user.username}')),
                      );
                    }
                  }
                } else if (val == 'report') {
                  ReportModal.show(
                    context: context,
                    targetType: ReportTargetType.user,
                    targetId: user.id,
                    reportedUserId: user.id,
                    targetPreview: '@${user.username}',
                  );
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(
                        isBlocked ? Icons.lock_open : Icons.block,
                        size: 18,
                        color: isBlocked ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(isBlocked ? 'Unblock User' : 'Block User'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Report Profile'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Cover Header & Avatar
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                ),
                Positioned(
                  bottom: -45,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: GestureDetector(
                          onTap: () =>
                              _showFullScreenImage(context, user.profilePicUrl),
                          child: user.profilePicUrl
                                  .startsWith('crushie_avatar_')
                              ? CrushieAvatar(
                                  index: int.tryParse(user.profilePicUrl
                                          .replaceAll('crushie_avatar_', '')) ??
                                      0,
                                  radius: 46,
                                )
                              : user.profilePicUrl.startsWith('http')
                                  ? CircleAvatar(
                                      radius: 46,
                                      backgroundImage:
                                          CachedNetworkImageProvider(
                                              user.profilePicUrl),
                                    )
                                  : CircleAvatar(
                                      radius: 46,
                                      backgroundImage:
                                          FileImage(File(user.profilePicUrl)),
                                    ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: StatusBadge(
                          isOnline: user.isOnline,
                          lastSeen: user.lastSeen,
                          showText: false,
                          dotSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 55),

            // Username, Verification, Premium Badges
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '@${user.username}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  if (user.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified,
                        color: AppColors.verifiedBlue, size: 20),
                  ],
                  if (user.isPremium) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'PREMIUM',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${user.city}, ${user.country} • ${user.age} yrs • ${user.gender}',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),

            StatusBadge(
                isOnline: user.isOnline,
                lastSeen: user.lastSeen,
                showText: true),
            const SizedBox(height: 16),

            // Self Status / Upgrade & Verification Action Buttons
            if (isSelf) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  VerificationModal.show(context, user),
                              icon: Icon(
                                Icons.verified,
                                color: user.isVerified
                                    ? AppColors.verifiedBlue
                                    : AppColors.primary,
                                size: 18,
                              ),
                              label: Text(
                                user.isVerified ? 'Verified' : 'Get Verified',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                side: BorderSide(
                                  color: user.isVerified
                                      ? AppColors.verifiedBlue
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PremiumSubscriptionScreen(
                                      onSubscriptionSuccess: () =>
                                          Navigator.pop(context),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.star,
                                  color: Colors.white, size: 18),
                              label: Text(
                                user.isPremium
                                    ? 'Premium Active'
                                    : 'Get Premium',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 12.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Premium + Verified Bundle Button (Save KES 49/mo)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              VerificationModal.show(context, user),
                          icon: const Icon(Icons.auto_awesome,
                              color: Colors.purple, size: 18),
                          label: const Text(
                            'Premium + Verified Bundle (KES 250/mo)',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                                fontSize: 12.5),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(
                                color: Colors.purple, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else if (currentUser != null) ...[
              // Follow / Connect Buttons for other user
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Provider.of<UserProvider>(context, listen: false)
                              .toggleFollow(
                            currentUser.id,
                            user.id,
                            targetUsername: user.username,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          side: BorderSide(
                              color:
                                  isFollowing ? Colors.grey : AppColors.primary,
                              width: 1.5),
                        ),
                        child: Text(
                          isFollowing ? 'Following' : '+ Follow',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                isFollowing ? Colors.grey : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          connProv.initiateConnect(
                            context: context,
                            sender: currentUser,
                            recipient: user,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          backgroundColor: AppColors.primary,
                        ),
                        child: Text(
                          currentUser.canConnectFree
                              ? 'Connect (FREE)'
                              : 'Connect',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 13.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Stats Counters (Posts, Followers, Following)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Posts', userPosts.length.toString(), isDark),
                  _buildStatItem(
                      'Followers', user.followersCount.toString(), isDark),
                  _buildStatItem(
                      'Following', user.followingCount.toString(), isDark),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bio Section
            if (user.bio.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    user.bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Gated Contact Details Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Private Contact Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (canViewPrivateDetails)
                    ContactRevealCard(
                      contactMethod: user.preferredContactMethod,
                      contactDetails: user.contactDetails,
                      username: user.username,
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.lock_outline,
                              size: 42, color: AppColors.primary),
                          const SizedBox(height: 10),
                          const Text(
                            'Contact Info Locked',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Preferred contact method is hidden. Only Crushie Premium members can view direct contact details (WhatsApp, Phone, Email, Telegram).',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GradientButton(
                            text: 'Upgrade to Premium to Unlock Contact',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PremiumSubscriptionScreen(
                                    onSubscriptionSuccess: () =>
                                        Navigator.pop(context),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile Posts Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Posts by @${user.username}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            if (userPosts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No public posts yet.',
                  style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                ),
              )
            else
              ...userPosts.map((p) => PostCard(post: p)).toList(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child:
                        Icon(Icons.broken_image, color: Colors.white, size: 64),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
