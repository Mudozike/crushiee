import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_colors.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/crush_comment_model.dart';
import '../models/report_model.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/post_provider.dart';
import '../providers/connection_provider.dart';
import '../services/database_service.dart';
import 'status_badge.dart';
import 'crushie_avatar.dart';
import 'boost_post_modal.dart';
import 'post_video_player.dart';
import 'report_modal.dart';

import '../screens/post/create_post_screen.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onTapUser;

  const PostCard({
    Key? key,
    required this.post,
    this.onTapUser,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isExpanded = false;

  String _formatPostTime(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  bool get isDatingCommunity {
    final lower = widget.post.community.toLowerCase();
    return !lower.contains('advice') &&
        !lower.contains('confession') &&
        !lower.contains('stress');
  }

  void _confirmDeletePost(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text(
            'Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<PostProvider>(context, listen: false)
                  .deletePost(widget.post.id, userId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post deleted.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openEditPost(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          existingPost: widget.post,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final postProvider = Provider.of<PostProvider>(context);
    final connProvider = Provider.of<ConnectionProvider>(context);
    final dbService = DatabaseService();
    final currentUser = authProvider.currentUser;

    final isCrushed = currentUser != null &&
        widget.post.crushedUserIds.contains(currentUser.id);
    final isSelf = currentUser != null && currentUser.id == widget.post.userId;
    final isFollowing = userProvider.isFollowing(widget.post.userId);

    final isMascotAvatar =
        widget.post.userProfilePic.startsWith('crushie_avatar_');
    final mascotIndex = isMascotAvatar
        ? (int.tryParse(
                widget.post.userProfilePic.replaceAll('crushie_avatar_', '')) ??
            0)
        : 0;

    final bool isLongText = widget.post.description.length > 160;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.post.currentlyBoosted
              ? AppColors.boostOrange.withOpacity(0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: widget.post.currentlyBoosted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.post.currentlyBoosted
                ? AppColors.boostOrange.withOpacity(0.15)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Boosted indicator header
            if (widget.post.currentlyBoosted) ...[
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
              const SizedBox(height: 8),
            ],

            // User Profile Row
            Row(
              children: [
                // Avatar with online status indicator dot
                GestureDetector(
                  onTap: widget.onTapUser,
                  child: Stack(
                    children: [
                      if (isMascotAvatar)
                        CrushieAvatar(
                          index: mascotIndex,
                          radius: 24,
                        )
                      else
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          backgroundImage: (widget
                                      .post.userProfilePic.isNotEmpty &&
                                  (widget.post.userProfilePic
                                          .startsWith('http') ||
                                      widget.post.userProfilePic
                                          .startsWith('https')))
                              ? CachedNetworkImageProvider(
                                  widget.post.userProfilePic)
                              : null,
                          child: (widget.post.userProfilePic.isEmpty ||
                                  (!widget.post.userProfilePic
                                          .startsWith('http') &&
                                      !widget.post.userProfilePic
                                          .startsWith('https')))
                              ? Text(
                                  widget.post.username.isNotEmpty
                                      ? widget.post.username[0].toUpperCase()
                                      : 'C',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary),
                                )
                              : null,
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: StatusBadge(
                          isOnline: widget.post.userIsOnline,
                          lastSeen: widget.post.userLastSeen,
                          showText: false,
                          dotSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Username, Verification Badge, Location & Post Timestamp
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onTapUser,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '@${widget.post.username}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                            if (widget.post.userIsVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  color: AppColors.verifiedBlue, size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 13,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                widget.post.location,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                            Text(
                              ' · ${_formatPostTime(widget.post.createdAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Follow / Owner Options Button
                if (!isSelf && currentUser != null) ...[
                  if (!isFollowing)
                    OutlinedButton(
                      onPressed: () {
                        userProvider.toggleFollow(
                          currentUser.id,
                          widget.post.userId,
                          targetUsername: widget.post.username,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: const Size(60, 30),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.2,
                        ),
                      ),
                      child: const Text(
                        '+ Follow',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (val) {
                      if (val == 'report') {
                        ReportModal.show(
                          context: context,
                          targetType: ReportTargetType.post,
                          targetId: widget.post.id,
                          reportedUserId: widget.post.userId,
                          targetPreview: widget.post.description.isNotEmpty
                              ? widget.post.description
                              : 'Post by @${widget.post.username}',
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.flag_outlined,
                                size: 18, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Report Post'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else if (isSelf && currentUser != null) ...[
                  ElevatedButton.icon(
                    onPressed: () =>
                        BoostPostModal.show(context, widget.post, currentUser),
                    icon: const Icon(Icons.bolt, size: 14, color: Colors.white),
                    label: const Text('Boost',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.boostOrange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(55, 28),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (val) {
                      if (val == 'edit') {
                        _openEditPost(context);
                      } else if (val == 'delete') {
                        _confirmDeletePost(context, currentUser.id);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit,
                                size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Edit Post'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete Post',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // Metadata Chips (Community Tag + Dating Pills if dating community)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Community Tag Pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.post.community,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),

                if (isDatingCommunity) ...[
                  // Looking For Pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          TextSpan(
                            text: widget.post.lookingFor,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Age: ${widget.post.ageRangeMin} - ${widget.post.ageRangeMax}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),

                  // Availability Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getAvailabilityColor(widget.post.availability)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color:
                              _getAvailabilityColor(widget.post.availability),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.post.availability,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color:
                                _getAvailabilityColor(widget.post.availability),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Post Description / Content with Read More Expansion
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (!isLongText || _isExpanded)
                      ? widget.post.description
                      : '${widget.post.description.substring(0, 150)}...',
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.4,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                if (isLongText) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Text(
                      _isExpanded ? 'Show less' : 'Read more',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Attached Media (Photo or Video)
            if (widget.post.hasMedia) ...[
              const SizedBox(height: 8),
              if (widget.post.isVideo)
                PostVideoPlayer(
                  videoUrl: widget.post.mediaUrl!,
                  thumbnailUrl: widget.post.thumbnailUrl,
                )
              else if (widget.post.isImage)
                GestureDetector(
                  onTap: () =>
                      _showFullScreenImage(context, widget.post.mediaUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: widget.post.mediaUrl!,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 220,
                        color: isDark
                            ? AppColors.darkSurface
                            : Colors.grey.shade200,
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => const SizedBox(),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 10),

            // Action Buttons Row: Crush, Crushes, Connect (Hidden if self)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Crush Button
                InkWell(
                  onTap: () {
                    if (currentUser != null) {
                      postProvider.toggleCrush(widget.post.id, currentUser.id);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          isCrushed ? Icons.favorite : Icons.favorite_border,
                          color: isCrushed
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                          size: 19,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.post.crushCount}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                isCrushed ? FontWeight.bold : FontWeight.w500,
                            color: isCrushed
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Crushes Button (Comments)
                InkWell(
                  onTap: () => _showCrushesSheet(context, widget.post),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          size: 19,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.post.crushesCount}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Connect CTA Button (Only shown if NOT self)
                if (!isSelf)
                  ElevatedButton(
                    onPressed: () {
                      if (currentUser == null) return;

                      final targetUser =
                          dbService.getUser(widget.post.userId) ??
                              UserModel(
                                id: widget.post.userId,
                                username: widget.post.username,
                                email: '',
                                country: widget.post.userCountry,
                                city: widget.post.userCity,
                                dateOfBirth: DateTime(1998, 1, 1),
                                gender: 'Female',
                                bio: '',
                                profilePicUrl: widget.post.userProfilePic,
                                preferredContactMethod: 'WhatsApp',
                                contactDetails: '+254712345678',
                                isVerified: widget.post.userIsVerified,
                              );

                      connProvider.initiateConnect(
                        context: context,
                        sender: currentUser,
                        recipient: targetUser,
                        postId: widget.post.id,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      backgroundColor: AppColors.primary,
                      elevation: 1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.favorite, color: Colors.white, size: 15),
                        SizedBox(width: 4),
                        Text(
                          'Connect',
                          style: TextStyle(
                            fontSize: 12.5,
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
            final currentUser = authProv.currentUser;

            return StreamBuilder<List<CrushCommentModel>>(
              stream: postProv.getCommentsStream(post.id),
              initialData: postProv.getPostComments(post.id),
              builder: (context, snapshot) {
                final comments =
                    snapshot.data ?? postProv.getPostComments(post.id);

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
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: comments.isEmpty
                              ? Center(
                                  child: Text(
                                    'No Crushes yet. Be the first to reply.',
                                    style: TextStyle(
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: comments.length,
                                  itemBuilder: (ctx, i) {
                                    final c = comments[i];
                                    final isCommentOwner =
                                        currentUser != null &&
                                            c.userId == currentUser.id;
                                    final isMascot = c.userProfilePic
                                        .startsWith('crushie_avatar_');
                                    final mascotIdx = isMascot
                                        ? (int.tryParse(c.userProfilePic
                                                .replaceAll(
                                                    'crushie_avatar_', '')) ??
                                            0)
                                        : 0;

                                    return ListTile(
                                      leading: isMascot
                                          ? CrushieAvatar(
                                              index: mascotIdx, radius: 18)
                                          : CircleAvatar(
                                              radius: 18,
                                              backgroundImage:
                                                  CachedNetworkImageProvider(
                                                      c.userProfilePic),
                                            ),
                                      title: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '@${c.username}',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '· ${_formatRelativeTime(c.createdAt)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? AppColors.darkTextSecondary
                                                  : AppColors
                                                      .lightTextSecondary,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(c.text),
                                      trailing: isCommentOwner
                                          ? PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert,
                                                  size: 18),
                                              onSelected: (val) {
                                                if (val == 'edit') {
                                                  _showEditCommentDialog(
                                                      context, postProv, c);
                                                } else if (val == 'delete') {
                                                  _confirmDeleteComment(
                                                      context,
                                                      postProv,
                                                      c,
                                                      currentUser.id);
                                                }
                                              },
                                              itemBuilder: (ctx) => [
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Text('Edit Comment'),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Delete Comment',
                                                      style: TextStyle(
                                                          color: Colors.red)),
                                                ),
                                              ],
                                            )
                                          : PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert,
                                                  size: 18),
                                              onSelected: (val) {
                                                if (val == 'report') {
                                                  ReportModal.show(
                                                    context: context,
                                                    targetType: ReportTargetType
                                                        .comment,
                                                    targetId: c.id,
                                                    reportedUserId: c.userId,
                                                    targetPreview: c.text,
                                                  );
                                                }
                                              },
                                              itemBuilder: (ctx) => [
                                                const PopupMenuItem(
                                                  value: 'report',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.flag_outlined,
                                                          size: 16,
                                                          color: Colors.orange),
                                                      SizedBox(width: 8),
                                                      Text('Report Comment'),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
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
                                icon: const Icon(Icons.send,
                                    color: AppColors.primary),
                                onPressed: () {
                                  if (commentController.text
                                          .trim()
                                          .isNotEmpty &&
                                      currentUser != null) {
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
      },
    );
  }

  void _showEditCommentDialog(
      BuildContext context, PostProvider postProv, dynamic comment) {
    final TextEditingController controller =
        TextEditingController(text: comment.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Update comment...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                postProv.editCrushComment(
                  commentId: comment.id,
                  postId: comment.postId,
                  userId: comment.userId,
                  newText: controller.text.trim(),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteComment(BuildContext context, PostProvider postProv,
      dynamic comment, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment?'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              postProv.deleteCrushComment(
                commentId: comment.id,
                postId: comment.postId,
                userId: userId,
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 52) return '${weeks}w';
    final years = (diff.inDays / 365).floor();
    return '${years}y';
  }
}
