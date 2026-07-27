import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../models/crush_comment_model.dart';
import '../services/database_service.dart';

class PostProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  String _selectedCommunity = 'All';
  String get selectedCommunity => _selectedCommunity;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // Filters
  String? _filterCountry;
  String? _filterGender;
  int? _filterMinAge;
  int? _filterMaxAge;
  bool _filterVerifiedOnly = false;
  bool _filterPremiumOnly = false;

  PostProvider() {
    _db.addListener(_onDbChanged);
  }

  void _onDbChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChanged);
    super.dispose();
  }

  void selectCommunity(String community) {
    _selectedCommunity = community;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilters({
    String? country,
    String? gender,
    int? minAge,
    int? maxAge,
    bool verifiedOnly = false,
    bool premiumOnly = false,
  }) {
    _filterCountry = country;
    _filterGender = gender;
    _filterMinAge = minAge;
    _filterMaxAge = maxAge;
    _filterVerifiedOnly = verifiedOnly;
    _filterPremiumOnly = premiumOnly;
    notifyListeners();
  }

  void clearFilters() {
    _filterCountry = null;
    _filterGender = null;
    _filterMinAge = null;
    _filterMaxAge = null;
    _filterVerifiedOnly = false;
    _filterPremiumOnly = false;
    _searchQuery = '';
    _selectedCommunity = 'All';
    notifyListeners();
  }

  List<PostModel> get filteredPosts {
    List<PostModel> list = List<PostModel>.from(_db.posts);

    // Community Filter
    if (_selectedCommunity != 'All') {
      list = list.where((p) => p.community == _selectedCommunity).toList();
    }

    // Search Query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) =>
        p.username.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q) ||
        p.lookingFor.toLowerCase().contains(q) ||
        p.location.toLowerCase().contains(q)
      ).toList();
    }

    // Country Filter
    if (_filterCountry != null && _filterCountry!.isNotEmpty) {
      list = list.where((p) => p.userCountry.toLowerCase() == _filterCountry!.toLowerCase()).toList();
    }

    // Verified Filter
    if (_filterVerifiedOnly) {
      list = list.where((p) => p.userIsVerified).toList();
    }

    // Sort boosted posts first
    list.sort((a, b) {
      if (a.currentlyBoosted && !b.currentlyBoosted) return -1;
      if (!a.currentlyBoosted && b.currentlyBoosted) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    return list;
  }

  void toggleCrush(String postId, String userId) {
    _db.toggleCrush(postId, userId);
  }

  List<CrushCommentModel> getPostComments(String postId) {
    return _db.getPostComments(postId);
  }

  void addCrushComment({
    required String postId,
    required String userId,
    required String username,
    required String userProfilePic,
    required bool userIsVerified,
    required String text,
  }) {
    final comment = CrushCommentModel(
      id: 'comment_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      userId: userId,
      username: username,
      userProfilePic: userProfilePic,
      userIsVerified: userIsVerified,
      text: text,
    );
    _db.addCrushComment(comment);
  }

  void createPost(PostModel post) {
    _db.createPost(post);
  }

  void boostPost(String postId, int hours) {
    _db.boostPost(postId, hours);
  }
}
