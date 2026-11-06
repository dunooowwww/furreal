import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/catch_result/data/catch_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';
import 'package:furreal/features/collection/data/collection_models.dart';
import 'package:furreal/features/collection/data/cutout.dart';
import 'package:furreal/features/collection/ui/animal_card.dart';
import 'package:furreal/shared/widgets/remote_photo.dart';

import 'helpers/fakes.dart';

const lab = Circle(id: 'c', name: 'lab', inviteCode: 'LAB234');

Future<void> pump(
  WidgetTester tester, {
  FakeCollectionRepository? collection,
  FakeCatchRepository? catches,
  FakeCutoutMaker? maker,
  FakeCutoutRepository? cutouts,
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
  circles: FakeCircleRepository(circles: [lab]),
  collection: collection,
  catches: catches,
  cutoutMaker: maker,
  cutouts: cutouts,
);

Future<void> openCollection(WidgetTester tester) async {
  await tester.tap(find.text('koleksi').last);
  await tester.pumpAndSettle();
}

Future<void> catchAndPost(WidgetTester tester, {String name = 'Milo'}) async {
  await tapText(tester, 'buka kamera');
  await tapFinder(tester, find.byKey(const Key('shutter')));
  await enter(tester, 'animal-name', name);
  await tapText(tester, 'posting ke circle');
}

Finder inKey(String key, Finder finder) =>
    find.descendant(of: find.byKey(Key(key)), matching: finder);

void main() {
  group('kartu koleksi', () {
    testWidgets('pakai potongan hewan kalau ada, foto biasa kalau belum', (
      tester,
    ) async {
      await pump(
        tester,
        collection: FakeCollectionRepository(
          animals: [
            animal(
              id: 'mochi',
              name: 'Mochi',
              type: 'kucing',
              catchId: 'c1',
              cutoutPath: 'u/c1/cutout.png',
            ),
            animal(
              id: 'kiko',
              name: 'Kiko',
              type: 'burung',
              catchId: 'c2',
              cutoutAttempted: true,
            ),
          ],
        ),
      );
      await openCollection(tester);

      expect(
        inKey('animal-mochi', find.byKey(const Key('photo-u/c1/cutout.png'))),
        findsOneWidget,
      );
      // Foto asli tetap ada sebagai latar buram di belakang potongan.
      expect(
        inKey(
          'animal-mochi',
          find.byKey(const Key('photo-u/mochi/animal.jpg')),
        ),
        findsOneWidget,
      );
      expect(
        inKey('animal-mochi', find.byKey(const Key('card-cutout'))),
        findsOneWidget,
      );
      expect(
        inKey('animal-kiko', find.byKey(const Key('card-cutout'))),
        findsNothing,
      );
      expect(
        inKey('animal-kiko', find.byKey(const Key('photo-u/kiko/animal.jpg'))),
        findsOneWidget,
      );
      // Grid: kilau statis, tanpa gestur & tanpa teks kepribadian.
      expect(
        inKey('animal-mochi', find.byKey(const Key('holo-gesture'))),
        findsNothing,
      );
      expect(
        inKey('animal-mochi', find.byKey(const Key('holo-sheen'))),
        findsOneWidget,
      );
    });

    testWidgets(
      'detail: kartu miring & berkilau mengikuti jari, lalu kembali',
      (tester) async {
        await pump(
          tester,
          collection: FakeCollectionRepository(
            animals: [
              animal(
                id: 'mochi',
                name: 'Mochi',
                type: 'kucing',
                personality: 'bos kamar 4b.',
              ),
            ],
          ),
        );
        await openCollection(tester);
        await tapFinder(tester, find.byKey(const Key('animal-mochi')));

        final detail = find.byKey(const Key('animal-detail'));
        final holo = find.descendant(
          of: detail,
          matching: find.byType(HoloCard),
        );
        HoloCardState state() => tester.state<HoloCardState>(holo);
        expect(state().tilt, Offset.zero);
        expect(
          find.descendant(
            of: detail,
            matching: find.byKey(const Key('card-personality')),
          ),
          findsOneWidget,
        );

        final card = find.descendant(
          of: detail,
          matching: find.byKey(const Key('holo-gesture')),
        );
        final gesture = await tester.startGesture(
          tester.getTopLeft(card) + const Offset(10, 10),
        );
        await gesture.moveBy(const Offset(5, 5));
        await tester.pump();
        expect(state().tilt.dx, lessThan(-0.5), reason: 'jari di kiri atas');
        expect(state().tilt.dy, lessThan(-0.5));

        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          state().tilt.distance,
          lessThan(0.01),
          reason: 'kembali pelan ke tengah',
        );
      },
    );

    test('nomor koleksi: urut dari hewan yang paling dulu ditemui', () {
      final numbers = collectionNumbers([
        animal(id: 'baru', name: 'B'),
        CollectionAnimal(
          id: 'lama',
          name: 'L',
          kind: AnimalKind.pet,
          animalType: null,
          encounterCount: 1,
          firstSeenAt: DateTime(2026, 1, 1),
          lastSeenAt: DateTime(2026, 1, 1),
          lastPhotoPath: null,
          lastPersonality: null,
        ),
      ]);
      expect(numbers, {'lama': 1, 'baru': 2});
      expect(cardNumber(7), '#0007');
    });

    test('splitPersonality', () {
      expect(splitPersonality('bos kamar 4b. nolak makanan murah.'), (
        tagline: 'bos kamar 4b.',
        traits: 'nolak makanan murah.',
      ));
      expect(splitPersonality('satu kalimat aja'), (
        tagline: 'satu kalimat aja',
        traits: null,
      ));
      expect(splitPersonality(null), (tagline: null, traits: null));
    });

    testWidgets(
      'kartu lengkap: tagline, info jenis/lokasi/tanggal, kepribadian',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              remotePhotoBuilderProvider.overrideWithValue(fakeRemotePhoto),
              remoteCutoutBuilderProvider.overrideWithValue(fakeRemotePhoto),
            ],
            child: MaterialApp(
              home: Center(
                child: SizedBox(
                  width: 320,
                  child: AnimalCard(
                    data: AnimalCardData(
                      name: 'Milo',
                      kind: AnimalKind.pet,
                      encounterCount: 2,
                      animalType: 'kucing',
                      personality:
                          'raja tidur kampus. bangun kalau ada makanan.',
                      number: 1,
                      date: DateTime(2026, 10, 30),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Furreal'), findsOneWidget);
        expect(find.text('#0001'), findsOneWidget);
        expect(find.text('raja tidur kampus.'), findsOneWidget);
        expect(find.text('Kepribadian:'), findsOneWidget);
        expect(find.text('bangun kalau ada makanan.'), findsOneWidget);
        expect(find.text('kucing'), findsOneWidget);
        expect(
          find.text('rahasia'),
          findsOneWidget,
          reason: 'lokasi disembunyikan',
        );
        expect(find.text('30 okt 2026'), findsOneWidget);
      },
    );

    test('warna kartu: jenis dikenal tetap, jenis lain stabil', () {
      expect(paletteFor('Kucing').deep, paletteFor('kucing').deep);
      expect(paletteFor('kucing').deep, isNot(paletteFor('burung').deep));
      expect(paletteFor('trenggiling').deep, paletteFor('trenggiling').deep);
      expect(paletteFor(null), isNotNull);
    });
  });

  group('kartu baru setelah posting', () {
    testWidgets('hewan dipotong, kartu "baru dapet!", potongan disimpan', (
      tester,
    ) async {
      final maker = FakeCutoutMaker();
      final cutouts = FakeCutoutRepository();
      await pump(tester, maker: maker, cutouts: cutouts);
      await catchAndPost(tester);

      expect(find.text('BARU DAPET!'), findsOneWidget);
      expect(
        inKey('new-card', find.byKey(const Key('card-cutout'))),
        findsOneWidget,
      );
      expect(inKey('new-card', find.text('Milo')), findsOneWidget);
      expect(inKey('new-card', find.text('#0001')), findsOneWidget);
      // Kepribadian AI dipecah: kalimat pertama = tagline, sisanya = sifat.
      expect(
        inKey('new-card', find.text('si penjaga parkiran.')),
        findsOneWidget,
      );
      expect(
        inKey('new-card', find.text('hobi: tidur di jok motor orang.')),
        findsOneWidget,
      );
      expect(maker.inputs, hasLength(1));
      expect(cutouts.saved, [(catchId: 'catch-1', hasCutout: true)]);

      await tapFinder(tester, find.byKey(const Key('new-card-done')));
      expect(find.text('catch terposting ke circle!'), findsOneWidget);
      expect(find.text('CATCH HARI INI · BERES'), findsOneWidget);
    });

    testWidgets(
      'tidak ada hewan terdeteksi → kartu pakai foto, ditandai sudah dicoba',
      (tester) async {
        final cutouts = FakeCutoutRepository();
        await pump(
          tester,
          maker: FakeCutoutMaker(found: false),
          cutouts: cutouts,
        );
        await catchAndPost(tester);

        expect(
          inKey('new-card', find.byKey(const Key('card-cutout'))),
          findsNothing,
        );
        expect(cutouts.saved, [(catchId: 'catch-1', hasCutout: false)]);
      },
    );

    testWidgets('ML Kit error → kartu tetap tampil, catch tetap terposting', (
      tester,
    ) async {
      final catches = FakeCatchRepository();
      await pump(
        tester,
        catches: catches,
        maker: FakeCutoutMaker()..error = Exception('model belum siap'),
      );
      await catchAndPost(tester);

      expect(find.text('BARU DAPET!'), findsOneWidget);
      expect(catches.submitted, hasLength(1));
    });

    testWidgets('ketemu lagi → "ketemu lagi!" dengan pertemuan bertambah', (
      tester,
    ) async {
      await pump(
        tester,
        collection: FakeCollectionRepository(
          animals: [
            animal(id: 'mochi', name: 'Mochi', type: 'kucing', encounters: 2),
          ],
        ),
      );
      await tapText(tester, 'buka kamera');
      await tapFinder(tester, find.byKey(const Key('shutter')));
      await tapText(tester, 'ketemu lagi');
      await tapFinder(tester, find.byKey(const Key('reencounter-mochi')));
      await tapText(tester, 'posting ke circle');

      expect(find.text('KETEMU LAGI!'), findsOneWidget);
      // Nomor koleksi Mochi tetap; kepribadian kosong → baris pertemuan.
      expect(inKey('new-card', find.text('#0001')), findsOneWidget);
    });
  });

  group('catch lama dipotong saat koleksi dibuka', () {
    testWidgets('hanya yang belum punya potongan & belum dicoba', (
      tester,
    ) async {
      final cutouts = FakeCutoutRepository();
      final maker = FakeCutoutMaker();
      await pump(
        tester,
        maker: maker,
        cutouts: cutouts,
        collection: FakeCollectionRepository(
          animals: [
            animal(id: 'a', name: 'A', catchId: 'c-a'),
            animal(
              id: 'b',
              name: 'B',
              catchId: 'c-b',
              cutoutPath: 'u/c-b/cutout.png',
            ),
            animal(id: 'c', name: 'C', catchId: 'c-c', cutoutAttempted: true),
          ],
        ),
      );
      await openCollection(tester);

      expect(cutouts.downloads, ['u/a/animal.jpg']);
      expect(cutouts.saved, [(catchId: 'c-a', hasCutout: true)]);
    });
  });

  group('CutoutService', () {
    test('pickMainSubject: subjek terbesar, tolak yang terlalu kecil', () {
      expect(
        pickMainSubject(
          [(width: 100, height: 100), (width: 400, height: 300)],
          imageWidth: 1000,
          imageHeight: 1000,
        ),
        1,
      );
      expect(
        pickMainSubject(
          [(width: 50, height: 50)],
          imageWidth: 1000,
          imageHeight: 1000,
        ),
        isNull,
        reason: '0.25% foto',
      );
      expect(pickMainSubject([], imageWidth: 10, imageHeight: 10), isNull);
    });

    test('backfill: ML Kit error tidak menandai catch (dicoba sesi lain), tidak diulang di sesi yang sama', () async {
      final maker = FakeCutoutMaker()..error = Exception('belum siap');
      final repo = FakeCutoutRepository();
      final service = CutoutService(maker, repo);
      final animals = [animal(id: 'a', name: 'A', catchId: 'c-a')];

      expect(await service.backfill(animals), 0);
      expect(repo.saved, isEmpty);
      expect(await service.backfill(animals), 0);
      expect(
        maker.inputs,
        hasLength(1),
        reason: 'tidak diulang di sesi yang sama',
      );
    });

    test('backfill dibatasi per panggilan', () async {
      final repo = FakeCutoutRepository();
      final service = CutoutService(FakeCutoutMaker(), repo);
      final animals = [
        for (var i = 0; i < 12; i++)
          animal(id: 'a$i', name: 'A$i', catchId: 'c$i'),
      ];
      expect(await service.backfill(animals, limit: 5), 5);
      expect(await service.backfill(animals, limit: 5), 5);
      expect(repo.saved, hasLength(10));
    });

    test('make: error ML Kit → null, tidak melempar', () async {
      final service = CutoutService(
        FakeCutoutMaker()..error = Exception('x'),
        FakeCutoutRepository(),
      );
      expect(await service.make(testPhoto), isNull);
    });
  });

  test('AnimalKind label tetap dipakai di kartu', () {
    expect(AnimalKind.wild.label, 'liar');
  });
}
