import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/account/data/feedback_repository.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/catch_result/data/catch_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';
import 'package:furreal/features/feed/data/catch_share.dart';
import 'package:furreal/features/feed/data/feed_models.dart';

import 'helpers/fakes.dart';

const kos = Circle(id: 'kos', name: 'kos', inviteCode: 'KSM234');
const bob = Profile(id: 'user-1', username: 'bob', displayName: 'Bob');
const caught = TodayCatch(
  id: 'mine',
  animalPhotoPath: 'a',
  selfiePhotoPath: 's',
  animalName: 'Milo',
  kind: AnimalKind.pet,
);

FeedItem feedItem({
  required String id,
  required String userId,
  String? caption,
}) => FeedItem(
  catchId: id,
  userId: userId,
  displayName: userId,
  createdAt: DateTime(2026, 11, 6, 9),
  isLate: false,
  lateMinutes: null,
  animalName: 'Milo',
  animalType: 'kucing',
  encounterCount: 1,
  caption: caption,
  animalPhotoPath: '$userId/$id/animal.jpg',
  selfiePhotoPath: '$userId/$id/selfie.jpg',
  likeCount: 0,
  laughCount: 0,
  commentCount: 0,
  likedByMe: false,
  laughedByMe: false,
);

void main() {
  group('simpan / bagikan catch sendiri', () {
    Future<(FakeFeedRepository, FakeCatchSharer)> openFeed(
      WidgetTester tester, {
      FakeCatchSharer? sharer,
    }) async {
      composedShares.clear();
      final feed = FakeFeedRepository(
        feeds: {
          'kos': [
            feedItem(id: 'mine', userId: 'user-1', caption: 'nunggu jatah'),
            feedItem(id: 'dinda', userId: 'u-dinda'),
          ],
        },
      );
      final s = sharer ?? FakeCatchSharer();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(userId: 'user-1'),
        profiles: FakeProfileRepository(profiles: {'user-1': bob}),
        circles: FakeCircleRepository(circles: [kos]),
        catches: FakeCatchRepository(today: caught),
        feed: feed,
        sharer: s,
      );
      await tester.tap(find.text('feed').last);
      await tester.pumpAndSettle();
      return (feed, s);
    }

    testWidgets('tombol hanya di catch sendiri', (tester) async {
      await openFeed(tester);
      expect(find.byKey(const Key('share-mine')), findsOneWidget);
      expect(find.byKey(const Key('share-dinda')), findsNothing);
    });

    testWidgets('pratinjau gambar dari foto sendiri, lalu simpan & bagikan', (
      tester,
    ) async {
      final (feed, sharer) = await openFeed(tester);
      await tapFinder(tester, find.byKey(const Key('share-mine')));

      expect(feed.downloads, [
        'user-1/mine/animal.jpg',
        'user-1/mine/selfie.jpg',
      ]);
      expect(composedShares, [(animalName: 'Milo', caption: 'nunggu jatah')]);
      expect(find.byKey(const Key('share-preview')), findsOneWidget);

      await tapFinder(tester, find.byKey(const Key('share-save')));
      expect(sharer.saved, ['furreal-milo']);
      expect(find.text('tersimpan di galeri (album furreal).'), findsOneWidget);

      await tapFinder(tester, find.byKey(const Key('share-send')));
      expect(sharer.shared, ['furreal-milo']);
    });

    testWidgets('izin galeri ditolak → pesan ramah', (tester) async {
      await openFeed(
        tester,
        sharer: FakeCatchSharer()..saveError = Exception('denied'),
      );
      await tapFinder(tester, find.byKey(const Key('share-mine')));
      await tapFinder(tester, find.byKey(const Key('share-save')));
      expect(
        find.text('gagal menyimpan. izinin akses galeri dulu ya.'),
        findsOneWidget,
      );
    });

    testWidgets('gambar asli: 1080×1350 PNG (foto, selfie, watermark, teks)', (
      tester,
    ) async {
      final png = await tester.runAsync(
        () => composeShareImage(
          animalPhoto: testPhoto,
          selfiePhoto: testPhotoFront,
          animalName: 'Milo',
          caption: 'nunggu jatah',
          date: DateTime(2026, 11, 6),
        ),
      );
      final size = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(png!);
        final image = (await codec.getNextFrame()).image;
        return Size(image.width.toDouble(), image.height.toDouble());
      });
      expect(png!.sublist(1, 4), 'PNG'.codeUnits);
      expect(size, shareImageSize);
    });
  });

  group('kirim saran', () {
    Future<FakeFeedbackRepository> openFeedback(
      WidgetTester tester, {
      FakeFeedbackRepository? feedback,
    }) async {
      final repo = feedback ?? FakeFeedbackRepository();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(userId: 'user-1'),
        profiles: FakeProfileRepository(profiles: {'user-1': bob}),
        circles: FakeCircleRepository(circles: [kos]),
        feedback: repo,
      );
      await tapFinder(tester, find.byTooltip('pengaturan'));
      await tapText(tester, 'kirim saran');
      return repo;
    }

    testWidgets('saran fitur & laporan bug terkirim', (tester) async {
      final repo = await openFeedback(tester);

      await tapFinder(tester, find.byKey(const Key('feedback-send')));
      expect(find.text('tulis dulu saran atau masalahnya.'), findsOneWidget);
      expect(repo.sent, isEmpty);

      await tapFinder(tester, find.byKey(const Key('feedback-bug')));
      await enter(tester, 'feedback-message', '  kamera hitam  ');
      await tapFinder(tester, find.byKey(const Key('feedback-send')));

      expect(repo.sent, [
        (category: FeedbackCategory.bug, message: 'kamera hitam'),
      ]);
      expect(find.text('makasih! masukan lo udah terkirim.'), findsOneWidget);
      expect(
        find.text('pengaturan'),
        findsOneWidget,
        reason: 'kembali ke pengaturan',
      );
    });

    testWidgets('gagal kirim → tetap di layar, pesan jelas', (tester) async {
      await openFeedback(
        tester,
        feedback: FakeFeedbackRepository()..error = Exception('offline'),
      );
      await enter(tester, 'feedback-message', 'mode gelap dong');
      await tapFinder(tester, find.byKey(const Key('feedback-send')));
      expect(
        find.text('gagal mengirim. cek koneksi lalu coba lagi.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('feedback-message')), findsOneWidget);
    });
  });
}
