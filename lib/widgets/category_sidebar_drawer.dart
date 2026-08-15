import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class CategorySidebarDrawer extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onSelectCategory;

  const CategorySidebarDrawer({
    Key? key,
    required this.selectedCategory,
    required this.onSelectCategory,
  }) : super(key: key);

  static const List<String> meetupCategories = [
    'Hook Up',
    'Coffee Date',
    'Travel Partner',
    'Long-Term Relationship',
    'Casual Meet',
    'Tonight Meet',
    'Quick Meet',
    'Weekend',
  ];

  static const List<String> intentCategories = [
    'Relationship',
    'Friendship',
    'Something Casual',
    'Not Sure Yet',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Categories & Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Scrollable Categories Body
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                children: [
                  // Option 1: All
                  _buildCategoryTile(
                    context,
                    title: 'All Feed',
                    categoryKey: 'All',
                    icon: Icons.grid_view_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),

                  // Section 1: Meetups & Communities
                  _buildSectionHeader(context, 'Meetup Categories', isDark),
                  const SizedBox(height: 8),
                  ...meetupCategories.map(
                    (cat) => _buildCategoryTile(
                      context,
                      title: cat,
                      categoryKey: cat,
                      icon: Icons.local_fire_department_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 2: Intent & Vibe
                  _buildSectionHeader(context, 'Relationship & Vibe', isDark),
                  const SizedBox(height: 8),
                  ...intentCategories.map(
                    (cat) => _buildCategoryTile(
                      context,
                      title: cat,
                      categoryKey: cat,
                      icon: Icons.favorite_rounded,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

            // Apply Button Footer
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    primary: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context, {
    required String title,
    required String categoryKey,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = selectedCategory == categoryKey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelectCategory(categoryKey),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.14)
                  : (isDark ? AppColors.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppColors.primary : (isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
