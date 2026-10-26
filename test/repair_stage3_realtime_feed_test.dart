import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crushie/models/user_model.dart';
import 'package:crushie/models/post_model.dart';
import 'package:crushie/models/crush_comment_model.dart';
import 'package:crushie/providers/auth_provider.dart';
import 'package:crushie/providers/user_provider.dart';
import 'package:crushie/providers/connection_provider.dart';
import 'package:crushie/providers/post_provider.dart';
import 'package:crushie/screens/feed/home_feed_screen.dart';
import 'package:crushie/services/database_service.dart';
import 'package:crushie/services/firestore_service.dart';

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  final UserModel? _user;
  _MockAuthProvider(this._user);

  @override
  UserModel? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// --- TEST MOCKS & HARNESS ---

class _FakeFirestoreService extends FirestoreService {
  _FakeFirestoreService() : super.forTesting();

  final Map<String, StreamController<FeedSnapshotResult>> _feedControllers = {};
  final Map<String, StreamController<PostModel?>> _postControllers = {};
  final Map<String, StreamController<List<CrushCommentModel>>> _commentControllers = {};

  int feedStreamRequestCount = 0;
  String? lastRequestedCommunity;
  int getPostsPaginatedCallCount = 0;
  List<PostModel> nextPaginatedResult = [];

  StreamController<FeedSnapshotResult> getFeedController(String community) {
    return _feedControllers.putIfAbsent(
      community,
      () => StreamController<FeedSnapshotResult>.broadcast(),
    );
  }

  StreamController<PostModel?> getPostController(String postId) {
    return _postControllers.putIfAbsent(
      postId,
      () => StreamController<PostModel?>.broadcast(),
    );
  }

  StreamController<List<CrushCommentModel>> getCommentController(String postId) {
    return _commentControllers.putIfAbsent(
      postId,
      () => StreamController<List<CrushCommentModel>>.broadcast(),
    );
  }

  @override
  Stream<FeedSnapshotResult> getFeedSnapshotStream({
    String? community,
    int limit = 20,
  }) {
    feedStreamRequestCount++;
    lastRequestedCommunity = community ?? 'All';
    return getFeedController(lastRequestedCommunity!).stream;
  }

  @override
  Stream<List<PostModel>> getFeedPostsStream({
    String? community,
    int limit = 20,
  }) {
    return getFeedSnapshotStream(community: community, limit: limit)
        .map((r) => r.posts);
  }

  @override
  Stream<PostModel?> getPostStream(String postId) {
    return getPostController(postId).stream;
  }

  @override
  Stream<List<CrushCommentModel>> getCommentsStream(String postId) {
    return getCommentController(postId).stream;
  }

  @override
  Future<PaginatedPostsResult> getPostsPaginated({
    String? community,
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    getPostsPaginatedCallCount++;
    return PaginatedPostsResult(posts: nextPaginatedResult, lastDocument: null);
  }

  void disposeAll() {
    for (final c in _feedControllers.values) {
      c.close();
    }
    for (final c in _postControllers.values) {
      c.close();
    }
    for (final c in _commentControllers.values) {
      c.close();
    }
  }
}

PostModel _createTestPost({
  required String id,
  required String userId,
  String username = 'testuser',
  String community = 'Coffee Date',
  String description = 'Coffee meetup today',
  int crushCount = 0,
  int crushesCount = 0,
  bool isBoosted = false,
  DateTime? boostExpiresAt,
  DateTime? createdAt,
}) {
  return PostModel(
    id: id,
    userId: userId,
    username: username,
    userProfilePic: 'crushie_avatar_1',
    userCountry: 'US',
    userCity: 'New York',
    community: community,
    lookingFor: 'Coffee Date',
    location: 'Central Park',
    ageRangeMin: 20,
    ageRangeMax: 35,
    availability: 'Today',
    description: description,
    crushCount: crushCount,
    crushesCount: crushesCount,
    isBoosted: isBoosted,
    boostExpiresAt: boostExpiresAt,
    createdAt: createdAt ?? DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Real-Time Post Updates: Additions, Modifications, and Deletions', () {
    test('Newly published post appears automatically from stream snapshot', () async {
      final fakeFirestore = _FakeFirestoreService();
      final db = DatabaseService();
      db.setPosts([]);

      final postProvider = PostProvider(firestoreService: fakeFirestore, db: db);
      final feedController = fakeFirestore.getFeedController('All');

      expect(postProvider.allPosts.isEmpty, isTrue);

      final post1 = _createTestPost(id: 'post_1', userId: 'user_a', description: 'First post');
      feedController.add(FeedSnapshotResult(posts: [post1], lastDocument: null));
      await Future<void>.delayed(Duration.zero);

      expect(postProvider.allPosts.length, 1);
      expect(postProvider.allPosts.first.id, 'post_1');
      expect(postProvider.allPosts.first.description, 'First post');

      // Newly published second post arrives via stream
      final post2 = _createTestPost(
        id: 'post_2',
        userId: 'user_b',
        description: 'Second post newer',
        createdAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      feedController.add(FeedSnapshotResult(posts: [post2, post1], lastDocument: null));
      await Future<void>.delayed(Duration.zero);

      expect(postProvider.allPosts.length, 2);
      expect(postProvider.allPosts.first.id, 'post_2');

      postProvider.dispose();
      fakeFirestore.disposeAll();
    });

    test('Modifications to existing post (likes, comments, content) update automatically', () async {
      final fakeFirestore = _FakeFirestoreService();
      final db = DatabaseService();
      db.setPosts([]);

      final postProvider = PostProvider(firestoreService: fakeFirestore, db: db);
      final feedController = fakeFirestore.getFeedController('All');

      final initialPost = _createTestPost(id: 'post_live', userId: 'user_a', crushCount: 0, crushesCount: 0);
      feedController.add(FeedSnapshotResult(posts: [initialPost], lastDocument: null));
      await Future<void>.delayed(Duration.zero);

      expect(postProvider.allPosts.first.crushCount, 0);

      // Other user crushes/likes the post in real-time
      final updatedPost = initialPost.copyWith(crushCount: 5, crushesCount: 2);
      feedController.add(FeedSnapshotResult(posts: [updatedPost], lastDocument: null));
      await Future<void>.delayed(Duration.zero);

      expect(postProvider.allPosts.first.crushCount, 5);
      expect(postProvider.allPosts.first.crushesCount, 2);

      postProvider.dispose();
      fakeFirestore.disposeAll();
    });

    test('Deleted post is automatically removed from the live feed', () async {
      final fakeFirestore = _FakeFirestoreService();
      final db = DatabaseService();
      db.setPosts([]);

      final postProvider = PostProvider(firestoreService: fakeFirestore, db: db);
      final feedController = fakeFirestore.getFeedController('All');

      final postA = _createTestPost(id: 'post_a', userId: 'user_a');
      final postB = _createTestPost(id: 'post_b', userId: 'user_b');
      feedController.add(FeedSnapshotResult(posts: [postA, postB], lastDocument: null));
      await Future<void>.delayed(Duration.zero);

      expect(postProvider.allPosts.length, 2);

      // Post A deleted in Firestore — snapshot now only contains Post B
      feedController.add(FeedSnapshotResult(posts: [postB], lastDocument: null));
      await Future<void>.delayed(Duration.zero);

      expect(postProvider.allPosts.length, 1);
      expect(postProvider.allPosts.first.id, 'post_b');

      postProvider.dispose();
      fakeFirestore.disposeAll();
    });
  });

  group('2. Post Ordering, Boost Prioritization, and Deduplication', () {
    test('Boosted posts are prioritized first, followed by createdAt descending', () async {
      final fakeFirestore = _FakeFirestoreService();
      final db = DatabaseService();
      db.setPosts([]);

      final postProvider = PostProvider(firestoreService: fakeFirestore, db: db);
      final feedController = fakeFirestore.getFeedController('All');

      final regularNewer = _createTestPost(
        id: 'post_reg_newer',
        userId: 'u1',
        createdAt: DateTime(2026, 10, 26, 15, 0),
        isBoosted: false,
      );
      final regularOlder = _createTestPost(
        id: 'post_reg_older',
        userId: 'u2',
        createdAt: DateTime(2026, 10, 26, 12, 0),
        isBoosted: false,
      );
      final boostedOlder = _createTestPost(
        id: 'post_boosted',
        userId: 'u3',
        createdAt: DateTime(2026, 10, 26, 10, 0),
        isBoosted: true,
        boostExpiresAt: DateTime.now().add(const Duration(hours: 2)),
      );

      feedController.add(FeedSnapshotResult(
        posts: [regularOlder, regularNewer, boostedOlder],
        lastDocument: null,
      ));
      await Future<void>.delayed(Duration.zero);

      final sorted = postProvider.allPosts;
      expect(sorted.length, 3);
      // Boosted post is first despite older createdAt
      expect(sorted[0].id, 'post_boosted');
      // Then newer regular post
      expect(sorted[1].id, 'post_reg_newer');
      // Then older regular post
      expect(sorted[2].id, 'post_reg_older');

      postProvider.dispose();
      fakeFirestore.disposeAll();
    });

    test('Deduplicates identical post IDs between live stream and paginated items', () async {
      final fakeFirestore = _FakeFirestoreService();
      final db = DatabaseService();
      db.setPosts([]);

      final postProvider = PostProvider(firestoreService: fakeFirestore, db: db);
      final feedController = fakeFirestore.getFeedController('All');

      final post1 = _createTestPost(id: 'post_shared', userId: 'u1');
      fakeFirestore.nextPaginatedResult = [post1];

      feedController.add(FeedSnapshotResult(posts: [post1], lastDocument: null));
      await Future<void>.delayed(Duration.zero);

      // Load older posts returning the same post ID
      await postProvider.loadOlderPosts();

      // Must remain exactly 1 post without duplicate keys
      expect(postProvider.allPosts.length, 1);
      expect(postProvider.allPosts.first.id, 'post_shared');

      postProvider.dispose();
      fakeFirestore.disposeAll();
    });
  });

  group('3. Pagination Coexisting with Real-Time Updates', () {
    test('Loading older posts preserves paginated items when live stream emits newer updates', () async {
      final fakeFirestore = _FakeFirestoreService();
      final db = DatabaseService();
      db.setPosts([]);

      final postProvider = PostProvider(firestoreService: fakeFirestore, db: db);
      final feedController = fakeFirestore.getFeedController('All');

      final topPost = _createTestPost(
        id: 'post_top',
        userId: 'u1',
        createdAt: DateTime(2026, 10, 26, 14, 0),
      );

      // Initial stream emission
      feedController.add(FeedSnapshotResult(posts: [topPost], lastDocument: null));
      await Future<void>.delayed(Duration.zero);

      expect(postProvider.allPosts.length, 1);

      // Older posts loaded via cursor pagination
      final olderPost = _createTestPost(
        id: 'post_older',
        userId: 'u2',
        createdAt: DateTime(2026, 10, 26, 10, 0),
      );
      fakeFirestore.nextPaginatedResult = [olderPost];
      await postProvider.loadOlderPosts();

      expect(postProvider.allPosts.length, 2);
      expect(postProvider.allPosts.map((p) => p.id).toList(), ['post_top', 'post_older']);

      // Live stream emits a brand new post at the top
      final brandNewPost = _createTestPost(
        id: 'post_brand_new',
        userId: 'u3',
        createdAt: DateTime(2026, 10, 26, 16, 0),
      );
      feedController.add(FeedSnapshotResult(posts: [brandNewPost, topPost], lastDocument: null));
      await Future<void>.delayed(Duration.zero);

      // Older paginated post is NOT lost! All 3 posts exist in correct order
      expect(postProvider.allPosts.length, 3);
      expect(
        postProvider.allPosts.map((p) => p.id).toList(),
        ['post_brand_new', 'post_top', 'post_older'],
      );

      postProvider.dispose();
      fakeFirestore.disposeAll();
    });
  });

  group('4. Feed Context Switching & Listener Disposal Lifecycle', () {
    test('Switching community cleanly switches listener and isolates community feed', () async {
      final fakeFirestore = _FakeFirestoreService();
      final db = DatabaseService();
      db.setPosts([]);

      final postProvider = PostProvider(firestoreService: fakeFirestore, db: db);
      expect(fakeFirestore.lastRequestedCommunity, 'All');

      final coffeePost = _createTestPost(id: 'c1', userId: 'u1', community: 'Coffee Date');
      final hookupPost = _createTestPost(id: 'h1', userId: 'u2', community: 'Hook Up');

      fakeFirestore.getFeedController('All').add(FeedSnapshotResult(
        posts: [coffeePost, hookupPost],
        lastDocument: null,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(postProvider.allPosts.length, 2);

      // Switch to 'Coffee Date' community
      postProvider.selectCommunity('Coffee Date');
      expect(fakeFirestore.lastRequestedCommunity, 'Coffee Date');

      fakeFirestore.getFeedController('Coffee Date').add(FeedSnapshotResult(
        posts: [coffeePost],
        lastDocument: null,
      ));
      await Future<void>.delayed(Duration.zero);

      // Only 'Coffee Date' posts are in the feed
      expect(postProvider.allPosts.length, 1);
      expect(postProvider.allPosts.first.id, 'c1');

      postProvider.dispose();
      fakeFirestore.disposeAll();
    });

    test('Disposing PostProvider cancels the stream subscription without leaks', () {
      final fakeFirestore = _FakeFirestoreService();
      final db = DatabaseService();
      final postProvider = PostProvider(firestoreService: fakeFirestore, db: db);

      expect(() => postProvider.dispose(), returnsNormally);
      fakeFirestore.disposeAll();
    });
  });

  group('5. Error Handling and Recoverability', () {
    test('Stream error with no cached posts exposes formatted fetchError', () async {
      final fakeFirestore = _FakeFirestoreService();
      final db = DatabaseService();
      db.setPosts([]);

      final postProvider = PostProvider(firestoreService: fakeFirestore, db: db);
      final feedController = fakeFirestore.getFeedController('All');

      feedController.addError(Exception('permission-denied: insufficient permissions'));
      await Future<void>.delayed(Duration.zero);

      expect(postProvider.fetchError, isNotNull);
      expect(postProvider.fetchError!.contains('permission denied'), isTrue);

      postProvider.dispose();
      fakeFirestore.disposeAll();
    });

    test('Stream error when cached posts exist does not wipe out or blank the feed', () async {
      final fakeFirestore = _FakeFirestoreService();
      final db = DatabaseService();
      db.setPosts([]);

      final postProvider = PostProvider(firestoreService: fakeFirestore, db: db);
      final feedController = fakeFirestore.getFeedController('All');

      final post = _createTestPost(id: 'p_persist', userId: 'u1');
      feedController.add(FeedSnapshotResult(posts: [post], lastDocument: null));
      await Future<void>.delayed(Duration.zero);

      expect(postProvider.allPosts.length, 1);

      // Stream encounters temporary network disconnect
      feedController.addError(Exception('network error unavailable'));
      await Future<void>.delayed(Duration.zero);

      // Cached posts remain visible — screen does not blank out!
      expect(postProvider.allPosts.length, 1);
      expect(postProvider.allPosts.first.id, 'p_persist');
      expect(postProvider.fetchError, isNotNull);

      postProvider.dispose();
      fakeFirestore.disposeAll();
    });
  });

  group('6. Single Post and Comments Real-Time Streams', () {
    test('getPostStream emits updated post details in real time', () async {
      final fakeFirestore = _FakeFirestoreService();
      final db = DatabaseService();
      final postProvider = PostProvider(firestoreService: fakeFirestore, db: db);

      final controller = fakeFirestore.getPostController('target_post');
      final stream = postProvider.getPostStream('target_post');

      final emitted = <PostModel?>[];
      final sub = stream.listen(emitted.add);

      final p1 = _createTestPost(id: 'target_post', userId: 'u1', crushCount: 1);
      controller.add(p1);
      await Future<void>.delayed(Duration.zero);

      final p2 = p1.copyWith(crushCount: 2);
      controller.add(p2);
      await Future<void>.delayed(Duration.zero);

      expect(emitted.length, 2);
      expect(emitted[0]?.crushCount, 1);
      expect(emitted[1]?.crushCount, 2);

      await sub.cancel();
      postProvider.dispose();
      fakeFirestore.disposeAll();
    });

    test('getCommentsStream emits new comments in real time', () async {
      final fakeFirestore = _FakeFirestoreService();
      final db = DatabaseService();
      final postProvider = PostProvider(firestoreService: fakeFirestore, db: db);

      final controller = fakeFirestore.getCommentController('target_post');
      final stream = postProvider.getCommentsStream('target_post');

      final emitted = <List<CrushCommentModel>>[];
      final sub = stream.listen(emitted.add);

      final c1 = CrushCommentModel(
        id: 'c1',
        postId: 'target_post',
        userId: 'u2',
        username: 'bob',
        userProfilePic: '',
        text: 'Great photo!',
      );
      controller.add([c1]);
      await Future<void>.delayed(Duration.zero);

      final c2 = CrushCommentModel(
        id: 'c2',
        postId: 'target_post',
        userId: 'u3',
        username: 'carol',
        userProfilePic: '',
        text: 'Love this!',
      );
      controller.add([c1, c2]);
      await Future<void>.delayed(Duration.zero);

      expect(emitted.length, 2);
      expect(emitted[0].length, 1);
      expect(emitted[1].length, 2);

      await sub.cancel();
      postProvider.dispose();
      fakeFirestore.disposeAll();
    });
  });

  group('7. HomeFeedScreen Widget Tests: Pull-to-Refresh & Pagination Scroll', () {
    testWidgets('HomeFeedScreen displays real-time posts and supports pull-to-refresh', (tester) async {
      final fakeFirestore = _FakeFirestoreService();
      final db = DatabaseService();
      db.setPosts([]);

      final testUser = UserModel(
        id: 'u_tester',
        username: 'tester',
        email: 'tester@example.com',
        gender: 'Male',
        country: 'Kenya',
        city: 'Nairobi',
        contactDetails: '+254712345678',
        preferredContactMethod: 'WhatsApp',
        bio: 'Hello world',
        profilePicUrl: '',
        dateOfBirth: DateTime(2000, 1, 1),
      );
      final authProv = _MockAuthProvider(testUser);
      final userProv = UserProvider(firestoreService: fakeFirestore, db: db);
      final connProv = ConnectionProvider();
      final postProvider = PostProvider(firestoreService: fakeFirestore, db: db);
      final feedController = fakeFirestore.getFeedController('All');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<UserProvider>.value(value: userProv),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProv),
            ChangeNotifierProvider<PostProvider>.value(value: postProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(body: HomeFeedScreen()),
          ),
        ),
      );
      await tester.pump();

      // Initially empty state
      expect(find.text('No posts in your feed yet'), findsOneWidget);

      // Real-time post arrives from stream
      final livePost = _createTestPost(
        id: 'live_card',
        userId: 'u_tester',
        username: 'live_author',
        description: 'Real-time post rendered on screen',
      );
      feedController.add(FeedSnapshotResult(posts: [livePost], lastDocument: null));
      await tester.pump();
      await tester.pump();

      // Post card appears without manual refresh
      expect(find.text('Real-time post rendered on screen'), findsOneWidget);
      expect(find.text('@live_author'), findsOneWidget);

      // Verify RefreshIndicator is present and properly wired to refreshFeed
      expect(find.byType(RefreshIndicator), findsOneWidget);
      final refreshIndicator =
          tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      expect(refreshIndicator.onRefresh, isNotNull);

      final initialFetchCount = fakeFirestore.getPostsPaginatedCallCount;
      await refreshIndicator.onRefresh();
      expect(
          fakeFirestore.getPostsPaginatedCallCount, greaterThan(initialFetchCount));

      postProvider.dispose();
      userProv.dispose();
      fakeFirestore.disposeAll();
    });
  });
}
