import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/crush_comment_model.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';

class PostProvider extends ChangeNotifier {
  final DatabaseService _db;
  final FirestoreService _firestoreService;

  String _selectedCommunity = 'All';
  String get selectedCommunity => _selectedCommunity;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingOlder = false;
  bool get isLoadingOlder => _isLoadingOlder;

  bool _hasMoreOlder = true;
  bool get hasMoreOlder => _hasMoreOlder;

  // Exposed error — null means no error
  String? _fetchError;
  String? get fetchError => _fetchError;

  DocumentSnapshot? _lastDocument;

  StreamSubscription<FeedSnapshotResult>? _feedSubscription;
  final Map<String, PostModel> _streamPostsMap = {};
  final Map<String, PostModel> _olderPostsMap = {};

  List<PostModel> get allPosts => _db.posts;

  PostProvider({
    FirestoreService? firestoreService,
    DatabaseService? db,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _db = db ?? DatabaseService() {
    _db.addListener(_onDbChanged);
    initFeedStream();
  }

  void _onDbChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _feedSubscription?.cancel();
    _feedSubscription = null;
    _db.removeListener(_onDbChanged);
    super.dispose();
  }

  /// Initialize real-time feed snapshot listener for the selected community
  void initFeedStream({bool isRefresh = false}) {
    _feedSubscription?.cancel();

    if (isRefresh) {
      _lastDocument = null;
      _olderPostsMap.clear();
      _hasMoreOlder = true;
    }

    try {
      _feedSubscription = _firestoreService
          .getFeedSnapshotStream(community: _selectedCommunity, limit: 20)
          .listen(
        (snapshotResult) {
          _onSnapshotReceived(snapshotResult);
        },
        onError: (e) {
          debugPrint('[POST_PROVIDER] Feed snapshot error: $e');
          _fetchError = _formatFetchError(e);
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('[POST_PROVIDER] Error initializing feed snapshot: $e');
      _fetchError = _formatFetchError(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onSnapshotReceived(FeedSnapshotResult result) {
    _streamPostsMap.clear();
    for (final p in result.posts) {
      _streamPostsMap[p.id] = p;
      // Prevent duplication in paginated older posts
      _olderPostsMap.remove(p.id);
    }

    if (_lastDocument == null) {
      _lastDocument = result.lastDocument;
    }

    _mergeAndPublishPosts();
    _isLoading = false;
    _fetchError = null;
    notifyListeners();
  }

  void _mergeAndPublishPosts() {
    final merged = <String, PostModel>{..._olderPostsMap, ..._streamPostsMap};
    final list = merged.values.where((p) => !p.isExpired).toList();

    // Sort boosted posts first, then createdAt descending
    list.sort((a, b) {
      if (a.currentlyBoosted && !b.currentlyBoosted) return -1;
      if (!a.currentlyBoosted && b.currentlyBoosted) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    _db.setPosts(list);
  }

  /// Pull-to-refresh or explicit refresh of the feed
  Future<void> refreshFeed() async {
    _isLoading = _db.posts.isEmpty;
    _fetchError = null;
    _hasMoreOlder = true;
    notifyListeners();

    initFeedStream(isRefresh: true);

    // Initial query fetch to quickly populate feed if stream takes a moment
    try {
      final result = await _firestoreService.getPostsPaginated(
        community: _selectedCommunity,
        lastDocument: null,
        limit: 20,
      );
      if (result.posts.isNotEmpty) {
        _onSnapshotReceived(FeedSnapshotResult(
          posts: result.posts,
          lastDocument: result.lastDocument,
        ));
      }
    } catch (e) {
      debugPrint('[POST_PROVIDER] Initial feed fetch note: $e');
      if (_db.posts.isEmpty) {
        _fetchError = _formatFetchError(e);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Backward-compatible fetchPosts API
  Future<void> fetchPosts({bool refresh = false}) async {
    if (refresh) {
      await refreshFeed();
    } else {
      await loadOlderPosts();
    }
  }

  /// Load older posts using cursor-based pagination
  Future<void> loadOlderPosts() async {
    if (_isLoadingOlder || !_hasMoreOlder) return;
    if (_streamPostsMap.isEmpty && _olderPostsMap.isEmpty && _lastDocument == null) return;

    _isLoadingOlder = true;
    notifyListeners();

    try {
      final result = await _firestoreService.getPostsPaginated(
        community: _selectedCommunity,
        lastDocument: _lastDocument,
        limit: 20,
      );

      if (result.posts.isEmpty || result.posts.length < 20) {
        _hasMoreOlder = false;
      }

      if (result.posts.isNotEmpty) {
        for (final p in result.posts) {
          if (!_streamPostsMap.containsKey(p.id)) {
            _olderPostsMap[p.id] = p;
          }
        }
        _lastDocument = result.lastDocument;
        _mergeAndPublishPosts();
      }
    } catch (e) {
      debugPrint('[POST_PROVIDER] Error loading older posts: $e');
    } finally {
      _isLoadingOlder = false;
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
    if (_selectedCommunity == community && _feedSubscription != null) return;
    _selectedCommunity = community;
    _streamPostsMap.clear();
    _olderPostsMap.clear();
    _lastDocument = null;
    _hasMoreOlder = true;
    _db.setPosts([]);
    refreshFeed();
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

  /// Real-time stream for an individual post document
  Stream<PostModel?> getPostStream(String postId) {
    return _firestoreService.getPostStream(postId);
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

  /// Creates a post in Firestore. The post is added to the local cache and stream map,
  /// then pushed to Firestore where the real-time listener updates other clients.
  Future<bool> createPost(PostModel post) async {
    try {
      _isLoading = true;
      _fetchError = null;
      notifyListeners();

      // Single Firestore write — PostProvider is the authority for this operation.
      await _firestoreService.createPost(post);

      // Update in-memory cache and stream map immediately for optimistic UI
      _db.addPostToCache(post);
      _streamPostsMap[post.id] = post;
      _mergeAndPublishPosts();

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
      if (_streamPostsMap.containsKey(post.id)) {
        _streamPostsMap[post.id] = post;
      }
      if (_olderPostsMap.containsKey(post.id)) {
        _olderPostsMap[post.id] = post;
      }
      _mergeAndPublishPosts();
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
      _streamPostsMap.remove(postId);
      _olderPostsMap.remove(postId);
      _mergeAndPublishPosts();
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
