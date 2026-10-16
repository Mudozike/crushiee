import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:crushie/models/user_model.dart';
import 'package:crushie/models/post_model.dart';
import 'package:crushie/widgets/crushie_avatar.dart';
import 'package:crushie/providers/post_provider.dart';
import 'package:crushie/screens/feed/home_feed_screen.dart';

class FakePostProvider extends ChangeNotifier implements PostProvider {
  @override
  List<PostModel> get filteredPosts => [];

  @override
  List<PostModel> get allPosts => [];

  @override
  String get selectedCommunity => 'All';

  @override
  String get searchQuery => '';

  @override
  bool get isLoading => false;

  @override
  String? get fetchError =>
      'Feed query failed: a required Firestore index is missing.';

  bool retryCalled = false;

  @override
  Future<void> fetchPosts({bool refresh = false}) async {
    retryCalled = true;
    notifyListeners();
  }

  @override
  void selectCommunity(String community) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Phase 1 - UserModel profileCompleted Tests', () {
    test('profileCompleted defaults to false for new drafts', () {
      final user = UserModel(
        id: 'user_123',
        username: 'alex',
        email: 'alex@example.com',
        country: 'Kenya',
        city: 'Nairobi',
        dateOfBirth: DateTime(2000, 1, 1),
        gender: 'Male',
        bio: 'Hello',
        profilePicUrl: 'crushie_avatar_0',
        preferredContactMethod: 'WhatsApp',
        contactDetails: '+254712345678',
      );
      expect(user.profileCompleted, isFalse);
    });

    test('profileCompleted serializes and deserializes accurately', () {
      final user = UserModel(
        id: 'user_456',
        username: 'sarah',
        email: 'sarah@example.com',
        country: 'Kenya',
        city: 'Mombasa',
        dateOfBirth: DateTime(1998, 5, 10),
        gender: 'Female',
        bio: 'Tech enthusiast',
        profilePicUrl: 'crushie_avatar_1',
        preferredContactMethod: 'WhatsApp',
        contactDetails: '+254712345679',
        profileCompleted: true,
      );

      final map = user.toMap();
      expect(map['profileCompleted'], isTrue);

      final reconstructed = UserModel.fromMap(map, 'user_456');
      expect(reconstructed.profileCompleted, isTrue);
    });

    test(
        'profileCompleted fallback works for legacy maps without profileCompleted key',
        () {
      final legacyMapWithBio = {
        'username': 'legacy_user',
        'email': 'legacy@example.com',
        'country': 'Kenya',
        'city': 'Kisumu',
        'dateOfBirth': '1999-01-01T00:00:00.000',
        'gender': 'Other',
        'bio': 'Existing persisted bio',
        'profilePicUrl': 'crushie_avatar_2',
        'preferredContactMethod': 'WhatsApp',
        'contactDetails': '+254700000000',
      };

      final user = UserModel.fromMap(legacyMapWithBio, 'legacy_uid');
      expect(user.profileCompleted, isTrue);

      final legacyMapEmptyBio = {
        'username': 'draft_user',
        'email': 'draft@example.com',
        'country': 'Kenya',
        'city': 'Nairobi',
        'dateOfBirth': '2000-01-01T00:00:00.000',
        'gender': 'Other',
        'bio': '   ',
        'profilePicUrl': 'crushie_avatar_0',
        'preferredContactMethod': 'WhatsApp',
        'contactDetails': '+254700000000',
      };

      final draftUser = UserModel.fromMap(legacyMapEmptyBio, 'draft_uid');
      expect(draftUser.profileCompleted, isFalse);
    });

    test('copyWith preserves or updates profileCompleted', () {
      final user = UserModel(
        id: 'user_789',
        username: 'john',
        email: 'john@example.com',
        country: 'Kenya',
        city: 'Nakuru',
        dateOfBirth: DateTime(1995, 3, 15),
        gender: 'Male',
        bio: '',
        profilePicUrl: 'crushie_avatar_0',
        preferredContactMethod: 'WhatsApp',
        contactDetails: '+254711111111',
        profileCompleted: false,
      );

      final completedUser = user.copyWith(profileCompleted: true);
      expect(completedUser.profileCompleted, isTrue);
      expect(completedUser.id, equals('user_789'));

      final updatedBio = completedUser.copyWith(bio: 'Updated bio');
      expect(updatedBio.profileCompleted, isTrue);
    });
  });

  group('Phase 1 - Avatar Selector Overflow Verification', () {
    testWidgets(
        'Avatar preset "Electric Crush" selected inside 92px height has ZERO overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 92,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: CrushieAvatar.avatarPresets.length,
                itemBuilder: (context, index) {
                  final isSelected = index == 1; // "Electric Crush"
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CrushieAvatar(
                          index: index,
                          radius: 28,
                          isSelected: isSelected,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CrushieAvatar.avatarPresets[index]['name'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify no Flutter error (RenderFlex overflow) occurred
      expect(tester.takeException(), isNull);
      expect(find.text('Electric Crush'), findsOneWidget);
    });
  });

  group('Phase 1 - HomeFeedScreen Error vs Empty State Verification', () {
    testWidgets(
        'HomeFeedScreen displays error banner and retry action when query fails',
        (tester) async {
      final fakeProvider = FakePostProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<PostProvider>.value(
              value: fakeProvider,
              child: const HomeFeedScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Feed'), findsOneWidget);
      expect(
          find.text(
              'Feed query failed: a required Firestore index is missing.'),
          findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();
      expect(fakeProvider.retryCalled, isTrue);
    });
  });
}
