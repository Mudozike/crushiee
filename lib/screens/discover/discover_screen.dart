import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../providers/post_provider.dart';
import '../../widgets/post_card.dart';

class DiscoverScreen extends StatefulWidget {
  final Function(String userId)? onTapUser;

  const DiscoverScreen({
    Key? key,
    this.onTapUser,
  }) : super(key: key);

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();

  String? _selectedCountry;
  String? _selectedGender;
  bool _verifiedOnly = false;
  bool _premiumOnly = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postProvider = Provider.of<PostProvider>(context);
    final posts = postProvider.filteredPosts;

    return Scaffold(
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? AppColors.darkSurface : Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) => postProvider.setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Search username, location, or vibes...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              postProvider.setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Filter Chips Bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Filter Modal Button
                      ElevatedButton.icon(
                        onPressed: () => _showFilterDialog(context),
                        icon: const Icon(Icons.tune, size: 16, color: Colors.white),
                        label: const Text('Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          primary: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Verified Pill
                      FilterChip(
                        label: const Text('Verified Only'),
                        selected: _verifiedOnly,
                        onSelected: (val) {
                          setState(() => _verifiedOnly = val);
                          postProvider.setFilters(verifiedOnly: val, premiumOnly: _premiumOnly, country: _selectedCountry, gender: _selectedGender);
                        },
                        selectedColor: AppColors.verifiedBlue.withOpacity(0.2),
                        checkmarkColor: AppColors.verifiedBlue,
                      ),
                      const SizedBox(width: 8),

                      // Premium Pill
                      FilterChip(
                        label: const Text('Premium Only'),
                        selected: _premiumOnly,
                        onSelected: (val) {
                          setState(() => _premiumOnly = val);
                          postProvider.setFilters(verifiedOnly: _verifiedOnly, premiumOnly: val, country: _selectedCountry, gender: _selectedGender);
                        },
                        selectedColor: AppColors.premiumGold.withOpacity(0.2),
                        checkmarkColor: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Results List
          Expanded(
            child: posts.isEmpty
                ? Center(
                    child: Text(
                      'No matching posts or profiles found.',
                      style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: posts.length,
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemBuilder: (ctx, i) {
                      final post = posts[i];
                      return PostCard(
                        post: post,
                        onTapUser: () {
                          if (widget.onTapUser != null) {
                            widget.onTapUser!(post.userId);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final postProv = Provider.of<PostProvider>(context, listen: false);

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Filter Discover Feed',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Country Filter
                  DropdownButtonFormField<String>(
                    value: _selectedCountry,
                    hint: const Text('Select Country'),
                    decoration: const InputDecoration(labelText: 'Country'),
                    items: AppConstants.countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setModalState(() => _selectedCountry = val),
                  ),
                  const SizedBox(height: 16),

                  // Gender Filter
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    hint: const Text('Select Gender'),
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: AppConstants.genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) => setModalState(() => _selectedGender = val),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedCountry = null;
                              _selectedGender = null;
                              _verifiedOnly = false;
                              _premiumOnly = false;
                            });
                            postProv.clearFilters();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Reset All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            postProv.setFilters(
                              country: _selectedCountry,
                              gender: _selectedGender,
                              verifiedOnly: _verifiedOnly,
                              premiumOnly: _premiumOnly,
                            );
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(primary: AppColors.primary),
                          child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
