import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/catch_result/data/catch_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';
import 'package:furreal/features/collection/data/collection_models.dart';

import 'helpers/fakes.dart';

final collectionSample = [
  animal(
    id: 'kiko',
    name: 'Kiko',
    type: 'burung',
    kind: AnimalKind.pet,
    encounters: 2,
    lastSeenAgo: const Duration(hours: 1),
  ),
  animal(
    id: 'mochi',
    name: 'Mochi',
    type: 'kucing',
    kind: AnimalKind.pet,
    encounters: 5,
    lastSeenAgo: const Duration(days: 1),
    personality: 'bos kamar 4b.',
  ),
  animal(
    id: 'oyen',
    name: 'Oyen',
    type: 'kucing',
    kind: AnimalKind.wild,
    encounters: 1,
    lastSeenAgo: const Duration(days: 3),
  ),
];

Future<void> pumpHome(
  WidgetTester tester, {
  FakeCollectionRepository? collection,
  FakeCatchRepository? catches,
}) => pumpApp(
  tester,
  auth: FakeAuthRepository(userId: 'user-1'),
  profiles: FakeProfileRepository(
    profiles: {
      'user-1': const Profile(
        id: 'user-1',
        username: 'bob',
        displayName: 'bob',
      ),
    },
  ),
  circles: FakeCircleRepository(
    circles: [const Circle(id: 'c', name: 'lab', inviteCode: 'LAB234')],
  ),
  catches: catches,
  collection: collection,
);

Future<void> openCollection(WidgetTester tester) async {
  await tester.tap(find.text('koleksi').last);
  await tester.pumpAndSettle();
}

Finder inKey(String key, Finder finder) =>
    find.descendant(of: find.byKey(Key(key)), matching: finder);

void main() {
  group('koleksi', () {
    testWidgets('statistik, grid, dan filter', (tester) async {
      await pumpHome(
        tester,
        collection: FakeCollectionRepository(
          animals: collectionSample,
          streak: const Streak(current: 4, longest: 9),
        ),
      );
      await openCollection(tester);

      expect(inKey('stat-animals', find.text('3')), findsOneWidget);
      expect(inKey('stat-types', find.text('2')), findsOneWidget);
      expect(inKey('stat-streak', find.text('4')), findsOneWidget);

      expect(inKey('animal-mochi', find.text('Mochi')), findsOneWidget);
      expect(inKey('animal-mochi', find.text('kucing')), findsOneWidget);
      expect(
        inKey('animal-mochi', find.text('ketemu 5x · peliharaan')),
        findsOneWidget,
      );
      expect(
        inKey(
          'animal-mochi',
          find.byKey(const Key('photo-u/mochi/animal.jpg')),
        ),
        findsOneWidget,
      );

      await tapFinder(tester, find.byKey(const Key('filter-liar')));
      expect(find.byKey(const Key('animal-oyen')), findsOneWidget);
      expect(find.byKey(const Key('animal-mochi')), findsNothing);
      expect(find.byKey(const Key('animal-kiko')), findsNothing);

      await tapFinder(tester, find.byKey(const Key('filter-peliharaan')));
      expect(find.byKey(const Key('animal-mochi')), findsOneWidget);
      expect(find.byKey(const Key('animal-kiko')), findsOneWidget);
      expect(find.byKey(const Key('animal-oyen')), findsNothing);

      await tapFinder(tester, find.byKey(const Key('filter-semua')));
      expect(find.byKey(const Key('animal-oyen')), findsOneWidget);
    });

    testWidgets('filter tanpa hasil', (tester) async {
      await pumpHome(
        tester,
        collection: FakeCollectionRepository(animals: [collectionSample.first]),
      );
      await openCollection(tester);
      await tapFinder(tester, find.byKey(const Key('filter-liar')));
      expect(find.text('belum ada hewan liar'), findsOneWidget);
    });

    testWidgets('empty state kalau belum ada hewan', (tester) async {
      await pumpHome(tester);
      await openCollection(tester);
      expect(find.text('koleksi lo masih kosong'), findsOneWidget);
      expect(inKey('stat-animals', find.text('0')), findsOneWidget);
    });

    testWidgets('tap kartu → detail hewan', (tester) async {
      await pumpHome(
        tester,
        collection: FakeCollectionRepository(animals: collectionSample),
      );
      await openCollection(tester);
      await tapFinder(tester, find.byKey(const Key('animal-mochi')));

      final detail = find.byKey(const Key('animal-detail'));
      expect(detail, findsOneWidget);
      Finder inDetail(Finder f) => find.descendant(of: detail, matching: f);
      expect(inDetail(find.text('Mochi')), findsOneWidget);
      expect(inDetail(find.text('kucing · peliharaan')), findsOneWidget);
      expect(inDetail(find.text('5x')), findsOneWidget);
      expect(inDetail(find.text('1 sep 2026')), findsOneWidget);
      expect(inDetail(find.text('bos kamar 4b.')), findsOneWidget);
    });
  });

  group('beranda', () {
    testWidgets('chip streak, kartu kemarin', (tester) async {
      await pumpHome(
        tester,
        collection: FakeCollectionRepository(
          streak: const Streak(current: 4, longest: 4),
          yesterday: const YesterdayCatch(
            animalName: 'Mochi',
            animalType: 'kucing',
            encounterCount: 3,
            photoPath: 'u/y/animal.jpg',
          ),
        ),
      );

      expect(inKey('streak-chip', find.text('4')), findsOneWidget);
      expect(inKey('yesterday-card', find.text('Mochi')), findsOneWidget);
      expect(
        inKey('yesterday-card', find.text('kucing · ketemu ke-3x')),
        findsOneWidget,
      );
      expect(find.text('waktunya\ncatch!'), findsOneWidget);
    });

    testWidgets('tanpa catch kemarin → kartu disembunyikan, streak 0', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(find.byKey(const Key('yesterday-card')), findsNothing);
      expect(inKey('streak-chip', find.text('0')), findsOneWidget);
    });

    testWidgets('sudah catch → kartu "catch hari ini · beres"', (tester) async {
      await pumpHome(
        tester,
        catches: FakeCatchRepository(
          today: const TodayCatch(
            id: 't',
            animalPhotoPath: 'a',
            selfiePhotoPath: 's',
            animalName: 'Kiko',
            animalType: 'burung',
            kind: AnimalKind.pet,
          ),
        ),
      );
      expect(find.text('CATCH HARI INI · BERES'), findsOneWidget);
      expect(find.text('Kiko'), findsOneWidget);
      expect(find.text('burung · peliharaan'), findsOneWidget);
      expect(find.text('buka kamera'), findsNothing);
    });
  });

  group('ketemu lagi', () {
    Future<void> toResult(WidgetTester tester) async {
      await tapText(tester, 'buka kamera');
      await tapFinder(tester, find.byKey(const Key('shutter')));
      await tapFinder(tester, find.byKey(const Key('shutter')));
    }

    testWidgets('daftar hewan sendiri, jenis sama AI di atas, lalu posting', (
      tester,
    ) async {
      final catches = FakeCatchRepository(); // AI: kucing
      final collection = FakeCollectionRepository(animals: collectionSample);
      await pumpHome(tester, catches: catches, collection: collection);
      await toResult(tester);

      expect(find.text('hewan baru'), findsWidgets);
      await tapText(tester, 'ketemu lagi');
      await reveal(tester, find.byKey(const Key('reencounter-list')));

      // nama & peliharaan/liar disembunyikan
      expect(find.byKey(const Key('animal-name')), findsNothing);
      expect(find.text('PELIHARAAN ATAU LIAR?'), findsNothing);

      // kucing (sesuai AI) di atas, walau Kiko terakhir ditemui paling baru
      final mochiY = tester
          .getTopLeft(find.byKey(const Key('reencounter-mochi')))
          .dy;
      final oyenY = tester
          .getTopLeft(find.byKey(const Key('reencounter-oyen')))
          .dy;
      final kikoY = tester
          .getTopLeft(find.byKey(const Key('reencounter-kiko')))
          .dy;
      expect(mochiY, lessThan(oyenY));
      expect(oyenY, lessThan(kikoY));
      expect(
        find.descendant(
          of: find.byKey(const Key('reencounter-mochi')),
          matching: find.text('ketemu 5x'),
        ),
        findsOneWidget,
      );

      await tapText(tester, 'posting ke circle');
      expect(
        find.text('pilih dulu hewan yang lo temuin lagi.'),
        findsOneWidget,
      );
      expect(catches.submitted, isEmpty);

      await tapFinder(tester, find.byKey(const Key('reencounter-mochi')));
      final loadsBefore = collection.loads;
      await tapText(tester, 'posting ke circle');

      final posted = catches.submitted.single;
      expect(posted.existingAnimalId, 'mochi');
      expect(posted.animalName, 'Mochi');
      expect(posted.kind, AnimalKind.pet);
      // koleksi & streak dimuat ulang setelah posting
      expect(collection.loads, greaterThan(loadsBefore));
    });

    testWidgets('ketemu lagi tapi koleksi kosong', (tester) async {
      await pumpHome(tester);
      await toResult(tester);
      await tapText(tester, 'ketemu lagi');
      await reveal(tester, find.byKey(const Key('reencounter-empty')));
      expect(
        find.text('koleksi lo masih kosong. pilih "hewan baru" dulu ya.'),
        findsOneWidget,
      );
    });

    testWidgets('balik ke hewan baru → posting hewan baru', (tester) async {
      final catches = FakeCatchRepository();
      await pumpHome(
        tester,
        catches: catches,
        collection: FakeCollectionRepository(animals: collectionSample),
      );
      await toResult(tester);
      await tapText(tester, 'ketemu lagi');
      await tapFinder(tester, find.byKey(const Key('reencounter-mochi')));
      await tapFinder(tester, find.text('hewan baru').last);
      await enter(tester, 'animal-name', 'Luna');
      await tapText(tester, 'posting ke circle');

      expect(catches.submitted.single.existingAnimalId, isNull);
      expect(catches.submitted.single.animalName, 'Luna');
    });

    test('urutan: jenis sama dulu, lalu terakhir ditemui', () {
      final sorted = sortForReencounter(collectionSample, 'Kucing ');
      expect(sorted.map((a) => a.id), ['mochi', 'oyen', 'kiko']);
      expect(sortForReencounter(collectionSample, null).map((a) => a.id), [
        'kiko',
        'mochi',
        'oyen',
      ]);
    });
  });
}
