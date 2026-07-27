import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../models/connection_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/connection_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/post_card.dart';
import '../../widgets/contact_reveal_card.dart';
import '../../widgets/gradient_button.dart';

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
    final dbService = DatabaseService();

    final currentUser = authProv.currentUser;
    final targetUserId = userId ?? currentUser?.id ?? 'current_user_1';
    final isSelf = currentUser != null && currentUser.id == targetUserId;

    final user = isSelf ? currentUser : dbService.getUser(targetUserId);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User profile not found.')),
      );
    }

    final isFollowing = dbService.isFollowing(user.id);
    final userPosts = postProv.filteredPosts.where((p) => p.userId == user.id).toList();

    // Connection & Access Logic
    // Premium users or connected users can see full private details
    final isConnected = currentUser != null &&
        dbService.connections.any((c) =>
            ((c.senderId == currentUser.id && c.recipientId == user.id) ||
                (c.senderId == user.id && c.recipientId == currentUser.id)) &&
            c.status == ConnectionStatus.accepted);

    final canViewPrivateDetails = isSelf || (currentUser?.isPremium ?? false) || isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text('@${user.username}'),
        actions: [
          if (isSelf && onOpenSettings != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: onOpenSettings,
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
                        child: CircleAvatar(
                          radius: 46,
                          backgroundImage: CachedNetworkImageProvider(user.profilePicUrl),
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

            // Username, Verification, Location
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                if (user.isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: AppColors.verifiedBlue, size: 20),
                ],
                if (user.isPremium) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'PREMIUM',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${user.city}, ${user.country} • ${user.age} yrs • ${user.gender}',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),

            StatusBadge(isOnline: user.isOnline, lastSeen: user.lastSeen, showText: true),
            const SizedBox(height: 16),

            // Follow / Action Buttons
            if (!isSelf && currentUser != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          dbService.toggleFollow(currentUser.id, user.id);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          side: BorderSide(color: isFollowing ? Colors.grey : AppColors.primary, width: 1.5),
                        ),
                        child: Text(
                          isFollowing ? 'Following' : '+ Follow @${user.username}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isFollowing ? Colors.grey : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        connProv.initiateConnect(
                          context: context,
                          sender: currentUser,
                          recipient: user,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        primary: AppColors.primary,
                      ),
                      child: const Text(
                        'Connect (KES 50)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
                  _buildStatItem('Followers', user.followersCount.toString(), isDark),
                  _buildStatItem('Following', user.followingCount.toString(), isDark),
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
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
                    // Locked Card for Unpaid / Non-Connected Users
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
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
                          const Icon(Icons.lock_outline, size: 42, color: AppColors.primary),
                          const SizedBox(height: 10),
                          const Text(
                            'Contact Info Locked',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Preferred contact method is ${user.preferredContactMethod}. Pay KES 50 connection fee or upgrade to Premium to unlock direct contact details.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GradientButton(
                            text: 'Connect to Unlock (KES 50)',
                            onPressed: () {
                              if (currentUser != null) {
                                connProv.initiateConnect(
                                  context: context,
                                  sender: currentUser,
                                  recipient: user,
                                );
                              }
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
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
                  style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
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
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}
