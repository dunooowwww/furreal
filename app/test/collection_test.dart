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
      expect(
        inKey('animal-mochi', find.text('kucing · ketemu 5x')),
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
      // Nama di kartu dan di judul detail.
      expect(inDetail(find.text('Mochi')), findsNWidgets(2));
      expect(inDetail(find.byKey(const Key('holo-gesture'))), findsOneWidget);
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

      await postToCircle(tester);
      expect(
        find.text('pilih dulu hewan yang lo temuin lagi.'),
        findsOneWidget,
      );
      expect(catches.submitted, isEmpty);

      await tapFinder(tester, find.byKey(const Key('reencounter-mochi')));
      final loadsBefore = collection.loads;
      await postToCircle(tester);

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
      await postToCircle(tester);

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

  group('edit & hapus kartu koleksi', () {
    Future<FakeCollectionRepository> openDetail(
      WidgetTester tester, {
      Object? error,
    }) async {
      final repo = FakeCollectionRepository(animals: [...collectionSample])
        ..error = error;
      await pumpHome(tester, collection: repo);
      await openCollection(tester);
      await tapFinder(tester, find.byKey(const Key('animal-mochi')));
      return repo;
    }

    testWidgets('edit nama, kind, jenis, kepribadian', (tester) async {
      final repo = await openDetail(tester);
      await tapFinder(tester, find.byKey(const Key('animal-edit')));
      expect(
        find.descendant(
          of: find.byKey(const Key('animal-edit-personality')),
          matching: find.text('bos kamar 4b.'),
        ),
        findsOneWidget,
        reason: 'terisi kepribadian sekarang',
      );

      await enter(tester, 'animal-edit-name', '   ');
      await tapFinder(tester, find.byKey(const Key('animal-edit-save')));
      expect(find.text('nama hewan nggak boleh kosong.'), findsOneWidget);
      expect(repo.edited, isEmpty);

      await enter(tester, 'animal-edit-name', ' Mochi Gendut ');
      await tapFinder(tester, find.text('liar').last);
      await enter(tester, 'animal-edit-type', ' Musang ');
      await enter(tester, 'animal-edit-personality', 'raja genteng.');
      await tapFinder(tester, find.byKey(const Key('animal-edit-save')));

      expect(repo.edited, ['mochi']);
      final mochi = repo.animals.firstWhere((a) => a.id == 'mochi');
      expect(mochi.name, 'Mochi Gendut');
      expect(mochi.kind, AnimalKind.wild);
      expect(mochi.animalType, 'musang');
      expect(mochi.lastPersonality, 'raja genteng.');
      expect(find.text('kartu diperbarui.'), findsOneWidget);
      // Detail ikut berubah tanpa ditutup.
      expect(
        find.descendant(
          of: find.byKey(const Key('animal-detail')),
          matching: find.text('musang · liar'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('edit gagal → pesan di sheet', (tester) async {
      await openDetail(tester, error: Exception('offline'));
      await tapFinder(tester, find.byKey(const Key('animal-edit')));
      await tapFinder(tester, find.byKey(const Key('animal-edit-save')));
      expect(find.byKey(const Key('animal-edit-error')), findsOneWidget);
    });

    testWidgets('hapus perlu konfirmasi, lalu hilang dari koleksi', (
      tester,
    ) async {
      final repo = await openDetail(tester);
      await tapFinder(tester, find.byKey(const Key('animal-remove')));
      expect(find.text('hapus Mochi dari koleksi?'), findsOneWidget);
      await tapText(tester, 'batal');
      expect(repo.removed, isEmpty);

      await tapFinder(tester, find.byKey(const Key('animal-remove')));
      await tapFinder(tester, find.byKey(const Key('confirm-remove-animal')));
      expect(repo.removed, ['mochi']);
      expect(find.byKey(const Key('animal-detail')), findsNothing);
      expect(find.byKey(const Key('animal-mochi')), findsNothing);
      expect(find.text('Mochi dihapus dari koleksi.'), findsOneWidget);
    });
  });

  group('navigasi detail', () {
    testWidgets('detail kartu: tombol kembali menutup halaman', (tester) async {
      await pumpHome(
        tester,
        collection: FakeCollectionRepository(animals: [...collectionSample]),
      );
      await openCollection(tester);
      await tapFinder(tester, find.byKey(const Key('animal-mochi')));
      expect(find.byKey(const Key('animal-detail')), findsOneWidget);

      await tapFinder(tester, find.byKey(const Key('detail-back')));
      expect(find.byKey(const Key('animal-detail')), findsNothing);
      expect(find.byKey(const Key('animal-mochi')), findsOneWidget);
    });

    testWidgets('scroll yang mulai dari atas kartu tetap menggulir halaman', (
      tester,
    ) async {
      await pumpHome(
        tester,
        collection: FakeCollectionRepository(animals: [...collectionSample]),
      );
      // HP pendek supaya isi detail lebih panjang dari layar.
      tester.view.physicalSize = const Size(1080, 1500);
      await tester.pumpAndSettle();
      await openCollection(tester);
      await tapFinder(tester, find.byKey(const Key('animal-mochi')));

      final detail = find.byKey(const Key('animal-detail'));
      final card = find.descendant(
        of: detail,
        matching: find.byKey(const Key('holo-gesture')),
      );
      await tester.drag(card, const Offset(0, -200));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: detail, matching: find.byType(Scrollable)),
          )
          .position;
      expect(
        position.maxScrollExtent,
        greaterThan(0),
        reason: "isi lebih panjang dari layar",
      );
      expect(position.pixels, greaterThan(0));
    });
  });

  group('kartu favorit (pajangan)', () {
    testWidgets('pajang dari detail, tampil di atas koleksi, lalu lepas', (
      tester,
    ) async {
      final repo = FakeCollectionRepository(animals: [...collectionSample]);
      await pumpHome(tester, collection: repo);
      await openCollection(tester);
      expect(find.byKey(const Key('showcase')), findsNothing);

      await tapFinder(tester, find.byKey(const Key('animal-mochi')));
      await tapFinder(tester, find.byKey(const Key('animal-pin')));
      expect(find.text('Mochi dipajang di atas koleksi.'), findsOneWidget);
      expect(find.text('lepas dari pajangan'), findsOneWidget);

      await tapFinder(tester, find.byKey(const Key('detail-back')));
      expect(find.byKey(const Key('showcase')), findsOneWidget);
      expect(find.text('📌 PAJANGAN · 1/3'), findsOneWidget);
      expect(find.byKey(const Key('showcase-mochi')), findsOneWidget);

      // Tap kartu di pajangan → detail → lepas.
      await tapFinder(tester, find.byKey(const Key('showcase-mochi')));
      await tapFinder(tester, find.byKey(const Key('animal-pin')));
      await tapFinder(tester, find.byKey(const Key('detail-back')));
      expect(find.byKey(const Key('showcase')), findsNothing);
      expect(repo.pinCalls, [('mochi', true), ('mochi', false)]);
    });

    testWidgets('maksimal 3 kartu → pesan jelas', (tester) async {
      final repo = FakeCollectionRepository(
        animals: [
          for (final a in collectionSample)
            a.copyWith(pinnedAt: () => DateTime(2026, 11, 1)),
          animal(id: 'baru', name: 'Baru', type: 'ikan'),
        ],
      );
      await pumpHome(tester, collection: repo);
      await openCollection(tester);
      expect(find.text('📌 PAJANGAN · 3/3'), findsOneWidget);

      await tapFinder(tester, find.byKey(const Key('animal-baru')));
      await tapFinder(tester, find.byKey(const Key('animal-pin')));
      expect(
        find.text('pajangan maksimal 3 kartu. lepas satu dulu ya.'),
        findsOneWidget,
      );
      expect(find.text('pajang kartu ini'), findsOneWidget);
    });
  });
}
