import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_colors.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/post_provider.dart';
import '../providers/connection_provider.dart';
import '../services/database_service.dart';
import 'status_badge.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onTapUser;

  const PostCard({
    Key? key,
    required this.post,
    this.onTapUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final postProvider = Provider.of<PostProvider>(context);
    final connProvider = Provider.of<ConnectionProvider>(context);
    final dbService = DatabaseService();
    final currentUser = authProvider.currentUser;

    final isCrushed = currentUser != null && post.crushedUserIds.contains(currentUser.id);
    final isSelf = currentUser != null && currentUser.id == post.userId;
    final isFollowing = dbService.isFollowing(post.userId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: post.currentlyBoosted
              ? AppColors.boostOrange.withOpacity(0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: post.currentlyBoosted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: post.currentlyBoosted
                ? AppColors.boostOrange.withOpacity(0.15)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Boosted indicator header
            if (post.currentlyBoosted) ...[
              Row(
                children: const [
                  Icon(Icons.bolt, color: AppColors.boostOrange, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'BOOSTED POST',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.boostOrange,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // User Profile Row with Follow Button
            Row(
              children: [
                // Avatar with online status indicator
                GestureDetector(
                  onTap: onTapUser,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        backgroundImage: post.userProfilePic.isNotEmpty
                            ? CachedNetworkImageProvider(post.userProfilePic)
                            : null,
                        child: post.userProfilePic.isEmpty
                            ? Text(
                                post.username.isNotEmpty ? post.username[0].toUpperCase() : 'U',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: StatusBadge(
                          isOnline: post.userIsOnline,
                          lastSeen: post.userLastSeen,
                          showText: false,
                          dotSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Username, Verification Badge, Location & Status
                Expanded(
                  child: GestureDetector(
                    onTap: onTapUser,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '@${post.username}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            if (post.userIsVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: AppColors.verifiedBlue, size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            const SizedBox(width: 2),
                            Text(
                              post.location,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(
                              isOnline: post.userIsOnline,
                              lastSeen: post.userLastSeen,
                              showText: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Follow Button right next to username
                if (!isSelf && currentUser != null)
                  OutlinedButton(
                    onPressed: () {
                      dbService.toggleFollow(currentUser.id, post.userId);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(60, 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(
                        color: isFollowing ? Colors.grey : AppColors.primary,
                        width: 1.2,
                      ),
                      primary: isFollowing ? Colors.grey : AppColors.primary,
                    ),
                    child: Text(
                      isFollowing ? 'Following' : '+ Follow',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isFollowing ? Colors.grey : AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Looking For & Age Range & Availability Row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Community Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    post.community,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),

                // Looking For Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Looking for: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        TextSpan(
                          text: post.lookingFor,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Preferred Age Range Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Age: ${post.ageRangeMin} - ${post.ageRangeMax}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),

                // Availability Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getAvailabilityColor(post.availability).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 13,
                        color: _getAvailabilityColor(post.availability),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.availability,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getAvailabilityColor(post.availability),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Post Description (Unlimited Length)
            Text(
              post.description,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),

            // Attached Picture (If Present)
            if (post.postImageUrl != null && post.postImageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: post.postImageUrl!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 220,
                    color: isDark ? AppColors.darkSurface : Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => const SizedBox(),
                ),
              ),
            ],
            const SizedBox(height: 16),

            const Divider(height: 1),
            const SizedBox(height: 10),

            // Action Buttons Row: Crush, Crushes, Connect
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Crush Button
                InkWell(
                  onTap: () {
                    if (currentUser != null) {
                      postProvider.toggleCrush(post.id, currentUser.id);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          isCrushed ? Icons.favorite : Icons.favorite_border,
                          color: isCrushed ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.crushCount}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isCrushed ? FontWeight.bold : FontWeight.w500,
                            color: isCrushed ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Crushes Button (Comments)
                InkWell(
                  onTap: () => _showCrushesSheet(context, post),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.crushesCount} Crushes',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Connect CTA Button (Triggers KES 50 Payment Flow)
                ElevatedButton(
                  onPressed: () {
                    if (currentUser == null) return;
                    
                    final targetUser = dbService.getUser(post.userId) ?? UserModel(
                      id: post.userId,
                      username: post.username,
                      email: '',
                      country: post.userCountry,
                      city: post.userCity,
                      dateOfBirth: DateTime(1998, 1, 1),
                      gender: 'Female',
                      bio: '',
                      profilePicUrl: post.userProfilePic,
                      preferredContactMethod: 'WhatsApp',
                      contactDetails: '+254712345678',
                      isVerified: post.userIsVerified,
                    );

                    connProvider.initiateConnect(
                      context: context,
                      sender: currentUser,
                      recipient: targetUser,
                      postId: post.id,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    primary: AppColors.primary,
                    elevation: 2,
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.favorite, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Connect',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getAvailabilityColor(String availability) {
    switch (availability.toLowerCase()) {
      case 'today':
        return Colors.green;
      case 'tonight':
        return Colors.purple;
      case 'weekend':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  // Crushes (Comments) Modal Sheet
  void _showCrushesSheet(BuildContext context, PostModel post) {
    final TextEditingController commentController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer2<PostProvider, AuthProvider>(
          builder: (context, postProv, authProv, child) {
            final comments = postProv.getPostComments(post.id);
            final currentUser = authProv.currentUser;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.6,
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Crushes (${comments.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: comments.isEmpty
                          ? Center(
                              child: Text(
                                'No Crushes yet. Be the first to reply.',
                                style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              ),
                            )
                          : ListView.builder(
                              itemCount: comments.length,
                              itemBuilder: (ctx, i) {
                                final c = comments[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: CachedNetworkImageProvider(c.userProfilePic),
                                  ),
                                  title: Text('@${c.username}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(c.text),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commentController,
                              decoration: const InputDecoration(
                                hintText: 'Write a Crush reply...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send, color: AppColors.primary),
                            onPressed: () {
                              if (commentController.text.trim().isNotEmpty && currentUser != null) {
                                postProv.addCrushComment(
                                  postId: post.id,
                                  userId: currentUser.id,
                                  username: currentUser.username,
                                  userProfilePic: currentUser.profilePicUrl,
                                  userIsVerified: currentUser.isVerified,
                                  text: commentController.text.trim(),
                                );
                                commentController.clear();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
