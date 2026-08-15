import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/post_provider.dart';
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

        return posts.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite_border,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        selectedCommunity == 'All'
                            ? 'No posts in your feed yet'
                            : 'No posts in "$selectedCommunity"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to share a post or try changing filters in the top menu!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      if (selectedCommunity != 'All') ...[
                        const SizedBox(height: 18),
                        OutlinedButton(
                          onPressed: () => postProvider.selectCommunity('All'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Show All Posts', style: TextStyle(color: AppColors.primary)),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : ListView.builder(
                itemCount: posts.length,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(top: 12, bottom: 90, left: 16, right: 16),
                itemBuilder: (ctx, index) {
                  final post = posts[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: PostCard(
                      post: post,
                      onTapUser: () {
                        if (onTapUser != null) {
                          onTapUser!(post.userId);
                        }
                      },
                    ),
                  );
                },
              );
      },
    );
  }
}
