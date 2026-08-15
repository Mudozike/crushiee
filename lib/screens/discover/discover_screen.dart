import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../models/post_model.dart';
import '../../providers/post_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/crushie_avatar.dart';

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
  final FocusNode _searchFocusNode = FocusNode();

  String? _selectedCountry;
  String? _selectedGender;
  bool _verifiedOnly = false;
  bool _premiumOnly = false;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {
        _showSuggestions = _searchFocusNode.hasFocus && _searchController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Smart Ranking of Posts based on Relevance, Online Status & Verification
  List<PostModel> _rankPosts(List<PostModel> rawPosts, String query) {
    if (rawPosts.isEmpty) return [];

    final list = List<PostModel>.from(rawPosts);
    list.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;

      if (query.isNotEmpty) {
        if (a.username.toLowerCase().startsWith(query)) scoreA += 50;
        if (b.username.toLowerCase().startsWith(query)) scoreB += 50;
        if (a.location.toLowerCase().contains(query)) scoreA += 30;
        if (b.location.toLowerCase().contains(query)) scoreB += 30;
        if (a.lookingFor.toLowerCase().contains(query)) scoreA += 20;
        if (b.lookingFor.toLowerCase().contains(query)) scoreB += 20;
      }

      if (a.userIsOnline) scoreA += 15;
      if (b.userIsOnline) scoreB += 15;

      if (a.userIsVerified) scoreA += 10;
      if (b.userIsVerified) scoreB += 10;

      return scoreB.compareTo(scoreA);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postProvider = Provider.of<PostProvider>(context);
    final rawPosts = postProvider.filteredPosts;
    final query = _searchController.text.trim().toLowerCase();

    // 1. Autocomplete Profile Suggestions
    final matchingProfiles = query.isEmpty
        ? <Map<String, String>>[]
        : rawPosts
            .where((p) =>
                p.username.toLowerCase().contains(query) ||
                p.location.toLowerCase().contains(query) ||
                p.lookingFor.toLowerCase().contains(query))
            .map((p) => {
                  'username': p.username,
                  'userId': p.userId,
                  'pic': p.userProfilePic,
                  'location': p.location,
                  'vibe': p.lookingFor,
                })
            .fold<List<Map<String, String>>>(<Map<String, String>>[], (list, item) {
            if (!list.any((e) => e['userId'] == item['userId'])) {
              list.add(item);
            }
            return list;
          }).take(4).toList();

    // 2. Autocomplete Category / Vibe Suggestions
    final allCategoryNames = [
      ...AppConstants.communities.map((c) => c['name']!),
      ...AppConstants.lookingForOptions,
      'Nairobi', 'Mombasa', 'Kenya', 'Uganda', 'Tanzania'
    ];

    final matchingCategories = query.isEmpty
        ? <String>[]
        : allCategoryNames
            .where((cat) => cat.toLowerCase().contains(query))
            .toSet()
            .take(3)
            .toList();

    final hasSuggestions = query.isNotEmpty && (matchingProfiles.isNotEmpty || matchingCategories.isNotEmpty);

    // Smart Ranked Posts
    final rankedPosts = _rankPosts(rawPosts, query);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Filter Controls Header
            Container(
              padding: const EdgeInsets.all(16),
              color: isDark ? AppColors.darkSurface : Colors.white,
              child: Column(
                children: [
                  // Search Input Field
                  TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (val) {
                      postProvider.setSearchQuery(val);
                      setState(() {
                        _showSuggestions = val.trim().isNotEmpty;
                      });
                    },
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search username, location, or vibes...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                postProvider.setSearchQuery('');
                                setState(() => _showSuggestions = false);
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),

                  // Real-time Autocomplete Suggestions Dropdown
                  if (_showSuggestions && hasSuggestions) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // Matching Profiles Section
                          if (matchingProfiles.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
                              child: Text(
                                'SUGGESTED PROFILES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            ...matchingProfiles.map((prof) {
                              final picUrl = prof['pic']!;
                              final isMascot = picUrl.startsWith('crushie_avatar_');
                              final mascotIndex = isMascot
                                  ? (int.tryParse(picUrl.replaceAll('crushie_avatar_', '')) ?? 0)
                                  : 0;

                              return ListTile(
                                dense: true,
                                leading: isMascot
                                    ? CrushieAvatar(index: mascotIndex, radius: 16)
                                    : CircleAvatar(
                                        radius: 16,
                                        backgroundImage: NetworkImage(picUrl),
                                      ),
                                title: Text(
                                  '@${prof['username']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                subtitle: Text(
                                  '${prof['location']} • ${prof['vibe']}',
                                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                ),
                                trailing: const Icon(Icons.north_west, size: 14, color: Colors.grey),
                                onTap: () {
                                  _searchController.text = prof['username']!;
                                  postProvider.setSearchQuery(prof['username']!);
                                  setState(() => _showSuggestions = false);
                                  _searchFocusNode.unfocus();

                                  if (widget.onTapUser != null) {
                                    widget.onTapUser!(prof['userId']!);
                                  }
                                },
                              );
                            }).toList(),
                          ],

                          // Matching Categories Section
                          if (matchingCategories.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
                              child: Text(
                                'SUGGESTED CATEGORIES & VIBES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            ...matchingCategories.map((cat) {
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.favorite_rounded, size: 18, color: AppColors.secondary),
                                title: Text(
                                  cat,
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                                ),
                                trailing: const Icon(Icons.north_west, size: 14, color: Colors.grey),
                                onTap: () {
                                  _searchController.text = cat;
                                  postProvider.setSearchQuery(cat);
                                  setState(() => _showSuggestions = false);
                                  _searchFocusNode.unfocus();
                                },
                              );
                            }).toList(),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Quick Filter Control Chips Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Filter Dialog Trigger Button
                        ElevatedButton.icon(
                          onPressed: () => _showFilterDialog(context),
                          icon: const Icon(Icons.tune_rounded, size: 16, color: Colors.white),
                          label: const Text('Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            primary: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Verified Only Pill
                        FilterChip(
                          label: const Text('Verified Only'),
                          selected: _verifiedOnly,
                          onSelected: (val) {
                            setState(() => _verifiedOnly = val);
                            postProvider.setFilters(
                              verifiedOnly: val,
                              premiumOnly: _premiumOnly,
                              country: _selectedCountry,
                              gender: _selectedGender,
                            );
                          },
                          selectedColor: AppColors.verifiedBlue.withOpacity(0.2),
                          checkmarkColor: AppColors.verifiedBlue,
                        ),
                        const SizedBox(width: 8),

                        // Premium Only Pill
                        FilterChip(
                          label: const Text('Premium Only'),
                          selected: _premiumOnly,
                          onSelected: (val) {
                            setState(() => _premiumOnly = val);
                            postProvider.setFilters(
                              verifiedOnly: _verifiedOnly,
                              premiumOnly: val,
                              country: _selectedCountry,
                              gender: _selectedGender,
                            );
                          },
                          selectedColor: Colors.amber.withOpacity(0.2),
                          checkmarkColor: Colors.amber.shade800,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Discovery Results Feed with Friendly Empty State
            Expanded(
              child: rankedPosts.isEmpty
                  ? _buildFriendlyEmptyState(isDark, postProvider)
                  : ListView.builder(
                      itemCount: rankedPosts.length,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(top: 12, bottom: 90, left: 16, right: 16),
                      itemBuilder: (ctx, i) {
                        final post = rankedPosts[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: PostCard(
                            post: post,
                            onTapUser: () {
                              if (widget.onTapUser != null) {
                                widget.onTapUser!(post.userId);
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Friendly Empty State (No harsh "No results found")
  Widget _buildFriendlyEmptyState(bool isDark, PostProvider postProv) {
    final allPosts = postProv.allPosts; // Fallback posts to show related suggestions

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'No exact matches yet.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),

          Text(
            'Try these suggested vibes or clear your search filters:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Action: Reset Filters
          OutlinedButton.icon(
            onPressed: () {
              _searchController.clear();
              postProv.setSearchQuery('');
              postProv.clearFilters();
              setState(() {
                _verifiedOnly = false;
                _premiumOnly = false;
                _selectedCountry = null;
                _selectedGender = null;
              });
            },
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18),
            label: const Text('Reset All Search Filters', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 28),

          // Suggested Profiles / Posts Header
          Row(
            children: [
              Text(
                'RECOMMENDED PEOPLE FOR YOU',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Display 2-3 fallback posts/profiles
          ...allPosts.take(3).map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PostCard(
                post: p,
                onTapUser: () {
                  if (widget.onTapUser != null) {
                    widget.onTapUser!(p.userId);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Filter Bottom Sheet Dialog
  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
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
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      prefixIcon: Icon(Icons.public_outlined, color: AppColors.primary),
                    ),
                    items: AppConstants.countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setModalState(() => _selectedCountry = val),
                  ),
                  const SizedBox(height: 16),

                  // Gender Filter
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    hint: const Text('Select Gender'),
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                    ),
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
