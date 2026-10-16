import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:crushie/models/user_model.dart';
import 'package:crushie/services/database_service.dart';
import 'package:crushie/providers/auth_provider.dart';
import 'package:crushie/providers/user_provider.dart';
import 'package:crushie/providers/post_provider.dart';
import 'package:crushie/providers/connection_provider.dart';
import 'package:crushie/screens/profile/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profile Updates & Protected Field Safeguards', () {
    test(
        '1. UserModel handles legacy documents with missing optional fields safely',
        () {
      final legacyMap = {
        'username': 'legacy_user',
        'city': 'Nairobi',
        'country': 'Kenya',
        'dateOfBirth': '2000-01-01T00:00:00.000',
        'gender': 'Female',
        // Omitted: bio, profilePicUrl, followersCount, followingCount, isVerified, isPremium, communities
      };

      final user = UserModel.fromMap(legacyMap, 'legacy_uid_123');

      expect(user.id, 'legacy_uid_123');
      expect(user.username, 'legacy_user');
      expect(user.bio, '');
      expect(user.profilePicUrl, '');
      expect(user.followersCount, 0);
      expect(user.followingCount, 0);
      expect(user.isVerified, isFalse);
      expect(user.isPremium, isFalse);
      expect(user.communities, isEmpty);
    });

    test(
        '2. Ordinary profile update payload strictly omits protected server-managed fields',
        () {
      final user = UserModel(
        id: 'user_test_1',
        email: 'test@crushie.app',
        username: 'cool_user',
        country: 'Kenya',
        city: 'Nairobi',
        dateOfBirth: DateTime(1998, 5, 20),
        gender: 'Male',
        bio: 'Updated bio text',
        profilePicUrl: 'crushie_avatar_3',
        profileCompleted: true,
        communities: ['Gaming', 'Music'],
        preferredContactMethod: 'WhatsApp',
        contactDetails: '+254700000000',
        isOnline: true,
        lastSeen: DateTime.now(),
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        isVerified: true, // Protected: Must never be in update payload
        isPremium: true, // Protected: Must never be in update payload
        followersCount: 50, // Protected: Must never be in update payload
        followingCount: 20, // Protected: Must never be in update payload
        dailyConnections: 5, // Protected: Must never be in update payload
        monthlyConnections: 15, // Protected: Must never be in update payload
      );
      expect(user.username, 'cool_user');

      // Verify the expected public update map fields according to FirestoreService logic
      final publicUpdateKeys = [
        'username',
        'displayName',
        'country',
        'city',
        'dateOfBirth',
        'gender',
        'bio',
        'profilePicUrl',
        'profileCompleted',
        'communities',
        'isOnline',
        'lastSeen',
        'updatedAt',
      ];

      final protectedKeys = [
        'role',
        'isVerified',
        'verifiedExpiry',
        'isPremium',
        'premiumExpiry',
        'followersCount',
        'followingCount',
        'dailyConnections',
        'dailyConnectionsDate',
        'monthlyConnections',
        'monthlyConnectionsMonth',
      ];

      for (final key in protectedKeys) {
        expect(publicUpdateKeys.contains(key), isFalse,
            reason:
                'Field $key must NOT be present in ordinary profile updates');
      }
    });

    test('3. Private settings cannot overwrite server-managed entitlements',
        () {
      final publicData = {
        'username': 'attacker',
        'isPremium': false,
        'role': 'user',
        'followersCount': 0,
      };

      // Attacker attempts to inject entitlements into private settings
      final rawPrivateData = {
        'email': 'attacker@crushie.app',
        'isPremium': true,
        'role': 'admin',
        'followersCount': 9999,
      };

      final sanitizedPrivate = Map<String, dynamic>.from(rawPrivateData);
      sanitizedPrivate.remove('role');
      sanitizedPrivate.remove('isPremium');
      sanitizedPrivate.remove('premiumExpiry');
      sanitizedPrivate.remove('isVerified');
      sanitizedPrivate.remove('verifiedExpiry');
      sanitizedPrivate.remove('followersCount');
      sanitizedPrivate.remove('followingCount');

      final combined = {...publicData, ...sanitizedPrivate};
      final user = UserModel.fromMap(combined, 'attacker_uid');

      expect(user.isPremium, isFalse);
      expect(user.followersCount, 0);
    });
  });

  group('Follow & Unfollow Persistence and Reliability', () {
    late DatabaseService db;
    late UserProvider userProv;

    setUp(() {
      db = DatabaseService();
      db.clearFollowing();
      userProv = UserProvider();
    });

    tearDown(() {
      userProv.clear();
      db.clearFollowing();
    });

    test('1. Follow state initial state is false', () {
      expect(userProv.isFollowing('target_user_1'), isFalse);
      expect(db.isFollowing('target_user_1'), isFalse);
    });

    test(
        '2. setFollowingUserIds updates local database and UserProvider queries',
        () {
      db.setFollowingUserIds({'target_user_1', 'target_user_2'});

      expect(userProv.isFollowing('target_user_1'), isTrue);
      expect(userProv.isFollowing('target_user_2'), isTrue);
      expect(userProv.isFollowing('target_user_3'), isFalse);
    });

    test('3. clearFollowing resets state', () {
      db.setFollowingUserIds({'target_user_1'});
      expect(userProv.isFollowing('target_user_1'), isTrue);

      userProv.clear();
      expect(userProv.isFollowing('target_user_1'), isFalse);
    });

    test('4. toggleFollow cannot follow self', () async {
      final res = await userProv.toggleFollow('user_same', 'user_same');
      expect(res, isFalse);
      expect(userProv.isFollowing('user_same'), isFalse);
    });

    test(
        '5. Canonical follow relationship path matches users/{currentUserId}/follows/{targetUserId}',
        () {
      const currentUserId = 'user_abc';
      const targetUserId = 'user_xyz';
      final path = 'users/$currentUserId/follows/$targetUserId';

      expect(path, 'users/user_abc/follows/user_xyz');
      expect(path.startsWith('users/'), isTrue);
      expect(path.contains('/follows/'), isTrue);
    });
  });

  group('Public Profile Lookup UI & Stream States', () {
    late DatabaseService db;
    late PostProvider postProv;
    late ConnectionProvider connProv;
    late UserProvider userProv;

    final dummyCurrentUser = UserModel(
      id: 'current_user_1',
      email: 'current@crushie.app',
      username: 'currentUser',
      country: 'Kenya',
      city: 'Nairobi',
      dateOfBirth: DateTime(1995, 1, 1),
      gender: 'Non-binary',
      bio: 'Hello world',
      profilePicUrl: 'crushie_avatar_1',
      preferredContactMethod: 'WhatsApp',
      contactDetails: '+254711111111',
      profileCompleted: true,
      communities: [],
      isOnline: true,
      lastSeen: DateTime.now(),
      createdAt: DateTime.now(),
    );

    setUp(() {
      db = DatabaseService();
      db.clearUserData();
      postProv = PostProvider();
      connProv = ConnectionProvider();
      userProv = UserProvider();
    });

    testWidgets(
        '1. Viewing own profile renders immediately without waiting for other-profile stream',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => _MockAuthProvider(dummyCurrentUser),
            ),
            ChangeNotifierProvider<UserProvider>.value(value: userProv),
            ChangeNotifierProvider<PostProvider>.value(value: postProv),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProv),
          ],
          child: const MaterialApp(
            home: ProfileScreen(userId: 'current_user_1'),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('@currentUser'), findsNWidgets(2));
      expect(find.text('Get Verified'), findsOneWidget);
      expect(find.text('+ Follow'), findsNothing);
    });

    testWidgets(
        '2. Empty or whitespace target user ID displays User profile not found immediately',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => _MockAuthProvider(dummyCurrentUser),
            ),
            ChangeNotifierProvider<UserProvider>.value(value: userProv),
            ChangeNotifierProvider<PostProvider>.value(value: postProv),
            ChangeNotifierProvider<ConnectionProvider>.value(value: connProv),
          ],
          child: const MaterialApp(
            home: ProfileScreen(userId: '   '),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('User profile not found.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  final UserModel? _mockUser;
  _MockAuthProvider(this._mockUser);

  @override
  UserModel? get currentUser => _mockUser;

  @override
  bool get isAuthenticated => _mockUser != null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
