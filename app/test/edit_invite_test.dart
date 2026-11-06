import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/catch_result/data/catch_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';
import 'package:furreal/features/circles/ui/invite_share.dart';
import 'package:furreal/features/feed/data/feed_models.dart';

import 'helpers/fakes.dart';

const kos = Circle(id: 'kos', name: 'kos', inviteCode: 'KSM234');
const bob = Profile(id: 'user-1', username: 'bob', displayName: 'Bob');
const today = TodayCatch(
  id: 'mine',
  animalId: 'animal-1',
  animalPhotoPath: 'a',
  selfiePhotoPath: 's',
  animalName: 'Milo',
  kind: AnimalKind.pet,
  animalType: 'kucing',
  caption: 'nunggu jatah',
);

FeedItem feedItem({required String id, required String userId}) => FeedItem(
  catchId: id,
  userId: userId,
  displayName: userId,
  createdAt: DateTime(2026, 11, 6, 9),
  isLate: false,
  lateMinutes: null,
  animalName: 'Milo',
  animalType: 'kucing',
  encounterCount: 1,
  caption: null,
  animalPhotoPath: '$userId/$id/animal.jpg',
  selfiePhotoPath: '$userId/$id/selfie.jpg',
  likeCount: 0,
  laughCount: 0,
  commentCount: 0,
  likedByMe: false,
  laughedByMe: false,
);

Future<FakeCatchRepository> pumpHome(
  WidgetTester tester, {
  FakeCatchRepository? catches,
  FakeCatchSharer? sharer,
}) async {
  final repo = catches ?? FakeCatchRepository(today: today);
  await pumpApp(
    tester,
    auth: FakeAuthRepository(userId: 'user-1'),
    profiles: FakeProfileRepository(profiles: {'user-1': bob}),
    circles: FakeCircleRepository(circles: [kos]),
    catches: repo,
    feed: FakeFeedRepository(
      feeds: {
        'kos': [
          feedItem(id: 'mine', userId: 'user-1'),
          feedItem(id: 'dinda', userId: 'u-dinda'),
        ],
      },
    ),
    sharer: sharer,
  );
  return repo;
}

void main() {
  group('edit & hapus catch sendiri', () {
    testWidgets('beranda: edit nama & caption', (tester) async {
      final catches = await pumpHome(tester);
      expect(find.text('"nunggu jatah"'), findsOneWidget);

      await tapFinder(tester, find.byKey(const Key('today-edit')));
      await enter(tester, 'edit-animal-name', '   ');
      await tapFinder(tester, find.byKey(const Key('edit-save')));
      expect(find.text('nama hewan nggak boleh kosong.'), findsOneWidget);
      expect(catches.edits, isEmpty);

      await enter(tester, 'edit-animal-name', ' Milo Gendut ');
      await enter(tester, 'edit-caption', '  ');
      await tapFinder(tester, find.byKey(const Key('edit-save')));

      expect(catches.edits, [(animalName: 'Milo Gendut', caption: null)]);
      expect(find.text('catch diperbarui.'), findsOneWidget);
      expect(find.text('Milo Gendut'), findsOneWidget);
      expect(find.byKey(const Key('today-caption')), findsNothing);
    });

    testWidgets('edit gagal → tetap di sheet dengan pesan', (tester) async {
      await pumpHome(
        tester,
        catches: FakeCatchRepository(today: today)
          ..editError = Exception('offline'),
      );
      await tapFinder(tester, find.byKey(const Key('today-edit')));
      await tapFinder(tester, find.byKey(const Key('edit-save')));
      expect(find.byKey(const Key('edit-error')), findsOneWidget);
      expect(find.byKey(const Key('edit-save')), findsOneWidget);
    });

    testWidgets('beranda: hapus perlu konfirmasi, lalu bisa catch lagi', (
      tester,
    ) async {
      final catches = await pumpHome(tester);

      await tapFinder(tester, find.byKey(const Key('today-delete')));
      expect(find.text('hapus catch hari ini?'), findsOneWidget);
      await tapText(tester, 'batal');
      expect(catches.deleted, 0);

      await tapFinder(tester, find.byKey(const Key('today-delete')));
      await tapFinder(tester, find.byKey(const Key('confirm-delete-catch')));
      expect(catches.deleted, 1);
      expect(find.text('catch hari ini dihapus.'), findsOneWidget);
      expect(find.text('buka kamera'), findsOneWidget);
    });

    testWidgets('feed: menu hanya di catch sendiri, bisa edit & hapus', (
      tester,
    ) async {
      final catches = await pumpHome(tester);
      await tester.tap(find.text('feed').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit-mine')), findsOneWidget);
      expect(find.byKey(const Key('edit-dinda')), findsNothing);

      await tapFinder(tester, find.byKey(const Key('edit-mine')));
      await tapFinder(tester, find.byKey(const Key('menu-edit')));
      await enter(tester, 'edit-caption', 'kenyang');
      await tapFinder(tester, find.byKey(const Key('edit-save')));
      expect(catches.edits, [(animalName: 'Milo', caption: 'kenyang')]);

      await tapFinder(tester, find.byKey(const Key('edit-mine')));
      await tapFinder(tester, find.byKey(const Key('menu-delete')));
      await tapFinder(tester, find.byKey(const Key('confirm-delete-catch')));
      expect(catches.deleted, 1);
    });
  });

  group('ajak teman', () {
    test('pesan undangan berisi nama, kode, dan link opsional', () {
      final plain = inviteMessage(kos, link: '');
      expect(plain, contains('"kos"'));
      expect(plain, contains('kode undangan: KSM234'));
      expect(plain, isNot(contains('download app')));
      expect(
        inviteMessage(kos, link: ' https://contoh.app/furreal '),
        endsWith('download app: https://contoh.app/furreal'),
      );
    });

    testWidgets('bagikan dari pengaturan circle', (tester) async {
      final sharer = FakeCatchSharer();
      await pumpHome(tester, sharer: sharer);
      await tapFinder(tester, find.byTooltip('pengaturan'));
      await tapText(tester, 'circle lo');
      await tapFinder(tester, find.byKey(const Key('invite-kos')));
      expect(sharer.sharedTexts.single, contains('KSM234'));
    });

    testWidgets('bagikan setelah membuat circle', (tester) async {
      final sharer = FakeCatchSharer();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(userId: 'user-1'),
        profiles: FakeProfileRepository(profiles: {'user-1': bob}),
        circles: FakeCircleRepository(),
        sharer: sharer,
      );
      await enter(tester, 'circle-name', 'kos ceria');
      await tapText(tester, 'buat circle');
      await tapText(tester, 'ajak teman');
      expect(sharer.sharedTexts.single, contains('"kos ceria"'));
    });
  });
}
