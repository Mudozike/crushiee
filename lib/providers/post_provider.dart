import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/crush_comment_model.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';

class PostProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final FirestoreService _firestoreService = FirestoreService();

  String _selectedCommunity = 'All';
  String get selectedCommunity => _selectedCommunity;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Exposed error — null means no error
  String? _fetchError;
  String? get fetchError => _fetchError;

  DocumentSnapshot? _lastDocument;

  List<PostModel> get allPosts => _db.posts;

  PostProvider() {
    _db.addListener(_onDbChanged);
    fetchPosts(refresh: true);
  }

  void _onDbChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChanged);
    super.dispose();
  }

  Future<void> fetchPosts({bool refresh = false}) async {
    if (refresh) {
      _lastDocument = null;
    }
    _isLoading = true;
    _fetchError = null;
    notifyListeners();

    try {
      final result = await _firestoreService.getPostsPaginated(
        community: _selectedCommunity,
        lastDocument: _lastDocument,
        limit: 20,
      );

      if (refresh) {
        _db.setPosts(result.posts);
      } else {
        final current = List<PostModel>.from(_db.posts)..addAll(result.posts);
        _db.setPosts(current);
      }

      _lastDocument = result.lastDocument;
    } catch (e) {
      // Log the real error and expose it — do NOT silently return empty list.
      debugPrint('[POST_PROVIDER] Firestore fetchPosts FAILED: $e');
      _fetchError = _formatFetchError(e);
      // Keep whatever posts were loaded previously (don't clear existing cache)
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _formatFetchError(Object e) {
    final msg = e.toString();
    if (msg.contains('failed-precondition') || msg.contains('index')) {
      return 'Feed query failed: a required Firestore index is missing. '
          'Check firestore.indexes.json and deploy indexes. ($msg)';
    }
    if (msg.contains('permission-denied')) {
      return 'Feed query failed: permission denied. Check Firestore security rules.';
    }
    if (msg.contains('unauthenticated')) {
      return 'Feed query failed: user is not authenticated.';
    }
    if (msg.contains('network') || msg.contains('unavailable')) {
      return 'Feed query failed: network error. Check internet connection.';
    }
    return 'Feed query failed: $msg';
  }

  void selectCommunity(String community) {
    _selectedCommunity = community;
    fetchPosts(refresh: true);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // Filters
  String? _filterCountry;
  String? _filterGender;
  int? _filterMinAge;
  int? _filterMaxAge;
  bool _filterVerifiedOnly = false;
  bool _filterPremiumOnly = false;

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
    fetchPosts(refresh: true);
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

    // Age Filters
    if (_filterMinAge != null) {
      list = list.where((p) => p.ageRangeMax >= _filterMinAge!).toList();
    }
    if (_filterMaxAge != null) {
      list = list.where((p) => p.ageRangeMin <= _filterMaxAge!).toList();
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

  Future<void> toggleCrush(String postId, String userId, {String? username, String? userProfilePic}) async {
    _db.toggleCrush(postId, userId);
    notifyListeners();

    try {
      await _firestoreService.togglePostCrush(
        postId: postId,
        userId: userId,
        username: username,
        userProfilePic: userProfilePic,
      );
    } catch (e) {
      debugPrint('[POST_PROVIDER] Error toggling crush in Firestore: $e');
    }
  }

  List<CrushCommentModel> getPostComments(String postId) {
    return _db.getPostComments(postId);
  }

  Stream<List<CrushCommentModel>> getCommentsStream(String postId) {
    return _firestoreService.getCommentsStream(postId);
  }

  Future<void> addCrushComment({
    required String postId,
    required String userId,
    required String username,
    required String userProfilePic,
    required bool userIsVerified,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    final comment = CrushCommentModel(
      id: 'comment_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      userId: userId,
      username: username,
      userProfilePic: userProfilePic,
      userIsVerified: userIsVerified,
      text: text.trim(),
    );
    _db.addCrushComment(comment);
    notifyListeners();

    try {
      final index = _db.posts.indexWhere((p) => p.id == postId);
      final postAuthorId = index != -1 ? _db.posts[index].userId : null;
      await _firestoreService.addCrushComment(comment, postAuthorId: postAuthorId);
    } catch (e) {
      debugPrint('[POST_PROVIDER] Error adding comment to Firestore: $e');
    }
  }

  /// Creates a post in Firestore. The post is only added to the local cache AFTER
  /// Firestore confirms success, then the feed is refreshed from Firestore.
  /// This prevents duplicate Firestore writes: DatabaseService.createPost() no longer
  /// calls _firestoreService.createPost() — it is cache-only.
  Future<bool> createPost(PostModel post) async {
    try {
      _isLoading = true;
      _fetchError = null;
      notifyListeners();

      // Single Firestore write — PostProvider is the authority for this operation.
      await _firestoreService.createPost(post);

      // Update in-memory cache immediately for optimistic UI
      _db.addPostToCache(post);

      // Refresh feed from Firestore to pick up any server-side changes
      await fetchPosts(refresh: true);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[POST_PROVIDER] Error creating post: $e');
      _isLoading = false;
      _fetchError = 'Failed to publish post: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePost(PostModel post, String userId) async {
    try {
      _db.updatePost(post, userId);
      await _firestoreService.updatePost(post);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[POST_PROVIDER] Error updating post: $e');
      return false;
    }
  }

  Future<bool> deletePost(String postId, String userId) async {
    try {
      _db.deletePost(postId, userId);
      await _firestoreService.deletePost(postId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[POST_PROVIDER] Error deleting post: $e');
      return false;
    }
  }

  Future<void> editCrushComment({
    required String commentId,
    required String postId,
    required String userId,
    required String newText,
  }) async {
    _db.editCrushComment(
      commentId: commentId,
      postId: postId,
      userId: userId,
      newText: newText,
    );
    notifyListeners();

    try {
      await _firestoreService.updateCrushComment(
        postId: postId,
        commentId: commentId,
        newText: newText,
      );
    } catch (e) {
      debugPrint('[POST_PROVIDER] Error editing comment in Firestore: $e');
    }
  }

  Future<void> deleteCrushComment({
    required String commentId,
    required String postId,
    required String userId,
  }) async {
    _db.deleteCrushComment(
      commentId: commentId,
      postId: postId,
      userId: userId,
    );
    notifyListeners();

    try {
      await _firestoreService.deleteCrushComment(
        postId: postId,
        commentId: commentId,
      );
    } catch (e) {
      debugPrint('[POST_PROVIDER] Error deleting comment in Firestore: $e');
    }
  }

  void boostPost(String postId, int hours) {
    _db.boostPost(postId, hours);
  }
}
