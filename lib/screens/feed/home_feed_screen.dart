import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../providers/post_provider.dart';
import '../../widgets/community_chip.dart';
import '../../widgets/post_card.dart';

class HomeFeedScreen extends StatelessWidget {
  final Function(String userId)? onTapUser;

  const HomeFeedScreen({
    Key? key,
    this.onTapUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<PostProvider>(
      builder: (context, postProvider, child) {
        final posts = postProvider.filteredPosts;
        final selectedCommunity = postProvider.selectedCommunity;

        return Column(
          children: [
            // Top Communities Chips Bar
            Container(
              height: 56,
              color: isDark ? AppColors.darkSurface : Colors.white,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  CommunityChip(
                    name: 'All',
                    icon: '🔥',
                    isSelected: selectedCommunity == 'All',
                    onTap: () => postProvider.selectCommunity('All'),
                  ),
                  ...AppConstants.communities.map((c) {
                    final name = c['name']!;
                    final icon = c['icon']!;
                    return CommunityChip(
                      name: name,
                      icon: icon,
                      isSelected: selectedCommunity == name,
                      onTap: () => postProvider.selectCommunity(name),
                    );
                  }).toList(),
                ],
              ),
            ),
            const Divider(height: 1),

            // Main Posts Feed List
            Expanded(
              child: posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 64,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No posts found in this community.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to create a post!',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: posts.length,
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      itemBuilder: (ctx, index) {
                        final post = posts[index];
                        return PostCard(
                          post: post,
                          onTapUser: () {
                            if (onTapUser != null) {
                              onTapUser!(post.userId);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
