import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../providers/post_provider.dart';
import '../../widgets/post_card.dart';

class CommunitiesScreen extends StatefulWidget {
  final VoidCallback onSelectCommunity;

  const CommunitiesScreen({
    Key? key,
    required this.onSelectCommunity,
  }) : super(key: key);

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  String? _selectedCommunityName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postProv = Provider.of<PostProvider>(context);
    final allPosts = postProv.filteredPosts;

    final displayedPosts = _selectedCommunityName == null
        ? allPosts
        : allPosts.where((p) => p.community == _selectedCommunityName).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explore Communities',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Browse community groups & view live post samples.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Horizontal Community Groups List (No Emojis)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // "All Communities" Chip
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedCommunityName = null);
                      postProv.selectCommunity('All');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        gradient: _selectedCommunityName == null ? AppColors.primaryGradient : null,
                        color: _selectedCommunityName == null
                            ? null
                            : (isDark ? AppColors.darkCard : Colors.grey.withOpacity(0.12)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'All Groups',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedCommunityName == null ? FontWeight.bold : FontWeight.w500,
                          color: _selectedCommunityName == null
                              ? Colors.white
                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                      ),
                    ),
                  ),

                  // Community Group Chips without emojis
                  ...AppConstants.communities.map((c) {
                    final name = c['name']!;
                    final isSelected = _selectedCommunityName == name;

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCommunityName = name);
                        postProv.selectCommunity(name);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppColors.primaryGradient : null,
                          color: isSelected
                              ? null
                              : (isDark ? AppColors.darkCard : Colors.grey.withOpacity(0.12)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            // Header for Sample Posts
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedCommunityName == null
                        ? 'Sample Posts in All Communities'
                        : 'Sample Posts in $_selectedCommunityName',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  Text(
                    '${displayedPosts.length} posts',
                    style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // Live Post Samples List
            Expanded(
              child: displayedPosts.isEmpty
                  ? Center(
                      child: Text(
                        'No sample posts found in this community group.',
                        style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: displayedPosts.length,
                      padding: const EdgeInsets.only(bottom: 20),
                      itemBuilder: (ctx, i) {
                        return PostCard(post: displayedPosts[i]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
