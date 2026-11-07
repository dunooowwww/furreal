import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/catch_result/data/catch_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';
import 'package:furreal/features/collection/data/collection_models.dart';
import 'package:furreal/features/friends/data/friend_repository.dart';

import 'collection_test.dart' show collectionSample;
import 'helpers/fakes.dart';
import 'history_test.dart' show historyCatch;
import 'share_feedback_test.dart' show feedItem;

const kos = Circle(id: 'kos', name: 'kos', inviteCode: 'KSM234');
const bob = Profile(id: 'user-1', username: 'bob', displayName: 'Bob');
const dinda = FriendUser(
  id: 'u-dinda',
  username: 'dinda',
  displayName: 'Dinda',
  relation: FriendRelation.none,
);

Future<void> pumpProfileApp(
  WidgetTester tester, {
  FakeFriendRepository? friends,
  FakeCollectionRepository? collection,
  FakeFeedRepository? feed,
  FakeCatchRepository? catches,
}) => pumpApp(
  tester,
  auth: FakeAuthRepository(userId: 'user-1'),
  profiles: FakeProfileRepository(profiles: {'user-1': bob}),
  circles: FakeCircleRepository(circles: [kos]),
  friends: friends,
  collection: collection,
  feed: feed,
  catches: catches,
);

Future<void> openProfile(WidgetTester tester) =>
    tapFinder(tester, find.byTooltip('profil'));

void main() {
  group('profil sendiri', () {
    testWidgets('foto di beranda → profil (bukan pengaturan), lalu ⚙️', (
      tester,
    ) async {
      final collection =
          FakeCollectionRepository(animals: [...collectionSample])
            ..streak = const Streak(current: 4, longest: 9)
            ..history = [historyCatch('c1', DateTime.utc(2026, 11, 6))];
      await pumpProfileApp(
        tester,
        collection: collection,
        friends: FakeFriendRepository(
          friends: [dinda.withRelation(FriendRelation.friend)],
        ),
      );
      await openProfile(tester);

      expect(find.text('pengaturan'), findsNothing, reason: 'bukan pengaturan');
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('@bob'), findsOneWidget);
      expect(find.text('🔥 4'), findsOneWidget);
      expect(find.text('1 teman · 3 hewan · 9 streak terlama'), findsOneWidget);
      await reveal(tester, find.byKey(const Key('history-c1')));
      expect(find.byKey(const Key('history-c1')), findsOneWidget);

      await tapFinder(tester, find.byKey(const Key('profile-settings')));
      expect(find.text('pengaturan'), findsOneWidget);
    });

    testWidgets('pin dari detail koleksi & dari slot "+" di profil', (
      tester,
    ) async {
      final collection = FakeCollectionRepository(
        animals: [...collectionSample],
      );
      await pumpProfileApp(tester, collection: collection);

      // Dari koleksi → detail → pin ke profil.
      await tester.tap(find.text('koleksi').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('showcase')), findsNothing);
      await tapFinder(tester, find.byKey(const Key('animal-mochi')));
      await tapFinder(tester, find.byKey(const Key('animal-pin')));
      expect(find.text('Mochi di-pin ke profil.'), findsOneWidget);
      expect(find.text('lepas dari profil'), findsOneWidget);
      await tapFinder(tester, find.byKey(const Key('detail-back')));

      await tester.tap(find.text('beranda').last);
      await tester.pumpAndSettle();
      await openProfile(tester);
      expect(find.byKey(const Key('pin-mochi')), findsOneWidget);

      // Slot "+" → pilih kartu lain.
      await tapFinder(tester, find.byKey(const Key('pin-add')));
      expect(find.byKey(const Key('pick-mochi')), findsNothing);
      await tapFinder(tester, find.byKey(const Key('pick-kiko')));
      expect(find.byKey(const Key('pin-kiko')), findsOneWidget);
      expect(collection.pinCalls, [('mochi', true), ('kiko', true)]);
    });

    testWidgets('pin ke-4 ditolak dengan pesan jelas', (tester) async {
      final collection = FakeCollectionRepository(
        animals: [
          for (final a in collectionSample)
            a.copyWith(pinnedAt: () => DateTime(2026, 11, 1)),
          animal(id: 'baru', name: 'Baru', type: 'ikan'),
        ],
      );
      await pumpProfileApp(tester, collection: collection);
      await tester.tap(find.text('koleksi').last);
      await tester.pumpAndSettle();
      await tapFinder(tester, find.byKey(const Key('animal-baru')));
      await tapFinder(tester, find.byKey(const Key('animal-pin')));
      expect(
        find.text('pajangan maksimal 3 kartu. lepas satu dulu ya.'),
        findsOneWidget,
      );
    });
  });

  group('teman', () {
    testWidgets('cari username → tambah teman → batal', (tester) async {
      final friends = FakeFriendRepository(users: {'dinda': dinda});
      await pumpProfileApp(tester, friends: friends);
      await openProfile(tester);
      await tapFinder(tester, find.byKey(const Key('profile-friends')));

      await enter(tester, 'friend-search', 'nggakada');
      await tapFinder(tester, find.byKey(const Key('friend-search-go')));
      expect(find.text('username @nggakada nggak ketemu.'), findsOneWidget);

      await enter(tester, 'friend-search', 'Dinda');
      await tapFinder(tester, find.byKey(const Key('friend-search-go')));
      await tapFinder(
        tester,
        find.byKey(const Key('friend-action-u-dinda')).first,
      );
      expect(friends.calls, contains('send:u-dinda'));
      expect(find.text('batal minta'), findsWidgets);
      expect(find.text('TERKIRIM · 1'), findsOneWidget);

      await tapFinder(tester, find.text('batal minta').first);
      expect(friends.calls, contains('remove:u-dinda'));
      expect(find.text('TERKIRIM · 1'), findsNothing);
    });

    testWidgets('permintaan masuk: titik merah, terima → jadi teman', (
      tester,
    ) async {
      final friends = FakeFriendRepository(
        friends: [dinda.withRelation(FriendRelation.incoming)],
      );
      await pumpProfileApp(tester, friends: friends);
      expect(
        find.descendant(
          of: find.byKey(const Key('open-profile')),
          matching: find.byType(Badge),
        ),
        findsOneWidget,
      );
      await openProfile(tester);
      await tapFinder(tester, find.byKey(const Key('profile-friends')));
      expect(find.text('PERMINTAAN MASUK · 1'), findsOneWidget);

      await tapFinder(tester, find.byKey(const Key('friend-action-u-dinda')));
      expect(friends.calls, ['accept:u-dinda']);
      expect(find.text('TEMAN · 1'), findsOneWidget);
      expect(find.text('PERMINTAAN MASUK · 1'), findsNothing);
    });

    testWidgets('tap nama di feed → profil teman (hanya lihat)', (
      tester,
    ) async {
      final friends = FakeFriendRepository(
        profiles: {
          'u-dinda': const UserProfile(
            id: 'u-dinda',
            username: 'dinda',
            displayName: 'Dinda',
            streak: 12,
            animalCount: 1,
            catchCount: 1,
            friendCount: 3,
            relation: FriendRelation.friend,
          ),
        },
        collections: {
          'u-dinda': [
            animal(
              id: 'oyen',
              name: 'Oyen',
              type: 'kucing',
            ).copyWith(pinnedAt: () => DateTime(2026, 11, 2)),
          ],
        },
        catches: {
          'u-dinda': [historyCatch('dc1', DateTime.utc(2026, 11, 5))],
        },
      );
      await pumpProfileApp(
        tester,
        friends: friends,
        catches: FakeCatchRepository(
          today: const TodayCatch(
            id: 'mine',
            animalPhotoPath: 'a',
            selfiePhotoPath: 's',
            animalName: 'Milo',
            kind: AnimalKind.pet,
          ),
        ),
        feed: FakeFeedRepository(
          feeds: {
            'kos': [feedItem(id: 'd1', userId: 'u-dinda')],
          },
        ),
      );
      await tester.tap(find.text('feed').last);
      await tester.pumpAndSettle();
      await tapFinder(tester, find.byKey(const Key('open-user-d1')));

      expect(find.text('Dinda'), findsOneWidget);
      expect(find.text('🔥 12'), findsOneWidget);
      expect(find.text('3 teman · 1 hewan · 1 catch'), findsOneWidget);
      expect(find.byKey(const Key('profile-settings')), findsNothing);
      expect(find.text('teman'), findsWidgets, reason: 'tombol status teman');

      await tapFinder(tester, find.byKey(const Key('pin-oyen')));
      expect(find.byKey(const Key('animal-detail')), findsOneWidget);
      expect(find.byKey(const Key('animal-pin')), findsNothing);
      expect(find.byKey(const Key('animal-edit')), findsNothing);
      await tapFinder(tester, find.byKey(const Key('detail-back')));

      await reveal(tester, find.byKey(const Key('history-dc1')));
      await tapFinder(tester, find.byKey(const Key('history-dc1')));
      expect(find.byKey(const Key('history-detail')), findsOneWidget);
      expect(find.byKey(const Key('history-delete')), findsNothing);
      expect(find.byKey(const Key('history-share')), findsNothing);
    });

    testWidgets('profil yang tidak boleh dilihat → pesan', (tester) async {
      await pumpProfileApp(
        tester,
        catches: FakeCatchRepository(
          today: const TodayCatch(
            id: 'mine',
            animalPhotoPath: 'a',
            selfiePhotoPath: 's',
            animalName: 'Milo',
            kind: AnimalKind.pet,
          ),
        ),
        feed: FakeFeedRepository(
          feeds: {
            'kos': [feedItem(id: 'd1', userId: 'u-asing')],
          },
        ),
      );
      await tester.tap(find.text('feed').last);
      await tester.pumpAndSettle();
      await tapFinder(tester, find.byKey(const Key('open-user-d1')));
      expect(find.byKey(const Key('profile-unavailable')), findsOneWidget);
    });

    testWidgets('feed "teman": pilih dari pemilih circle', (tester) async {
      await pumpProfileApp(
        tester,
        catches: FakeCatchRepository(
          today: const TodayCatch(
            id: 'mine',
            animalPhotoPath: 'a',
            selfiePhotoPath: 's',
            animalName: 'Milo',
            kind: AnimalKind.pet,
          ),
        ),
        feed: FakeFeedRepository(
          feeds: {
            'kos': [feedItem(id: 'k1', userId: 'u-kos')],
            'teman': [feedItem(id: 't1', userId: 'u-dinda')],
          },
          members: {'teman': 2},
        ),
      );
      await tester.tap(find.text('feed').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feed-card-k1')), findsOneWidget);

      await tapFinder(tester, find.byKey(const Key('circle-picker')));
      await tapFinder(tester, find.byKey(const Key('pick-friends')));
      expect(find.byKey(const Key('feed-card-t1')), findsOneWidget);
      expect(find.byKey(const Key('feed-card-k1')), findsNothing);
      expect(find.text('hari ini · 1 dari 2 udah catch'), findsOneWidget);
    });
  });

  testWidgets('feed "teman" kosong tanpa teman → tombol tambah teman', (
    tester,
  ) async {
    await pumpProfileApp(
      tester,
      feed: FakeFeedRepository(members: {'teman': 1}),
    );
    await tester.tap(find.text('feed').last);
    await tester.pumpAndSettle();
    await tapFinder(tester, find.byKey(const Key('circle-picker')));
    await tapFinder(tester, find.byKey(const Key('pick-friends')));
    expect(find.text('belum ada teman'), findsOneWidget);
    await tapFinder(tester, find.byKey(const Key('feed-add-friends')));
    expect(find.byKey(const Key('friend-search')), findsOneWidget);
  });
}
