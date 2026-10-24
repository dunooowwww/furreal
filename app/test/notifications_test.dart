import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';
import 'package:furreal/features/daily_drop/data/daily_drop.dart';
import 'package:furreal/features/feed/data/feed_models.dart';
import 'package:furreal/features/notifications/data/push_messaging.dart';

import 'helpers/fakes.dart';

const lab = Circle(id: 'lab', name: 'lab bio', inviteCode: 'LAB234');

final bob = FakeProfileRepository(
  profiles: {
    'user-1': const Profile(id: 'user-1', username: 'bob', displayName: 'bob'),
  },
);

Future<void> pumpHome(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakePushMessaging? push,
  FakePushTokenRepository? pushTokens,
  FakeAnalytics? analytics,
  FakeDailyDropRepository? drop,
  FakeFeedRepository? feed,
  FakeCircleRepository? circles,
  FakeCatchRepository? catches,
  VoidCallback? onOpenSettings,
}) => pumpApp(
  tester,
  auth: auth ?? FakeAuthRepository(userId: 'user-1'),
  profiles: bob,
  circles: circles ?? FakeCircleRepository(circles: [lab]),
  push: push,
  pushTokens: pushTokens,
  analytics: analytics,
  drop: drop,
  feed: feed,
  catches: catches,
  onOpenSettings: onOpenSettings,
);

Future<void> postCatch(WidgetTester tester, String name) async {
  await tapText(tester, 'buka kamera');
  await tapFinder(tester, find.byKey(const Key('shutter')));
  await tapFinder(tester, find.byKey(const Key('shutter')));
  await enter(tester, 'animal-name', name);
  await tapText(tester, 'posting ke circle');
}

void main() {
  group('izin notifikasi', () {
    testWidgets('kartu penjelasan dulu, lalu dialog sistem', (tester) async {
      final push = FakePushMessaging();
      await pumpHome(tester, push: push);

      expect(find.byKey(const Key('notification-prompt')), findsOneWidget);
      expect(push.requests, 0, reason: 'dialog sistem belum muncul sendiri');

      await tapText(tester, 'nyalain notifikasi');
      expect(push.requests, 1);
      expect(find.byKey(const Key('notification-prompt')), findsNothing);
    });

    testWidgets('ditolak → arahkan ke pengaturan', (tester) async {
      var settingsOpened = 0;
      final push = FakePushMessaging(afterRequest: PushPermission.denied);
      await pumpHome(
        tester,
        push: push,
        onOpenSettings: () => settingsOpened++,
      );

      await tapText(tester, 'nyalain notifikasi');
      expect(find.text('buka pengaturan'), findsOneWidget);
      await tapText(tester, 'buka pengaturan');
      expect(settingsOpened, 1);
      expect(push.requests, 1, reason: 'Android tidak menampilkan dialog lagi');
    });

    testWidgets('"nanti aja" menyembunyikan kartu', (tester) async {
      await pumpHome(tester, push: FakePushMessaging());
      await tapText(tester, 'nanti aja');
      expect(find.byKey(const Key('notification-prompt')), findsNothing);
    });

    testWidgets('tanpa Firebase / izin sudah ada → kartu tidak muncul', (
      tester,
    ) async {
      await pumpHome(
        tester,
        push: FakePushMessaging(current: PushPermission.unsupported),
      );
      expect(find.byKey(const Key('notification-prompt')), findsNothing);
    });
  });

  group('token FCM', () {
    testWidgets('disimpan saat login & diperbarui, dihapus saat keluar', (
      tester,
    ) async {
      final auth = FakeAuthRepository(userId: 'user-1');
      final push = FakePushMessaging(current: PushPermission.granted);
      final tokens = FakePushTokenRepository();
      await pumpHome(tester, auth: auth, push: push, pushTokens: tokens);
      expect(tokens.saved, ['tok-hp']);

      push.refreshes.add('tok-baru');
      await tester.pumpAndSettle();
      expect(tokens.saved, ['tok-hp', 'tok-baru']);

      await tapFinder(tester, find.byTooltip('pengaturan'));
      await tapText(tester, 'keluar');
      expect(tokens.saved.last, isNull, reason: 'token dilepas sebelum keluar');
      expect(auth.userId, isNull);
      expect(find.text('belum punya akun?'), findsOneWidget);

      // Token yang diperbarui setelah keluar tidak disimpan ke siapa pun.
      push.refreshes.add('tok-setelah-keluar');
      await tester.pumpAndSettle();
      expect(tokens.saved, ['tok-hp', 'tok-baru', null]);
    });
  });

  group('analytics', () {
    testWidgets('catch_created: hewan baru, tepat waktu', (tester) async {
      final analytics = FakeAnalytics();
      await pumpHome(tester, analytics: analytics);
      await postCatch(tester, 'Milo');
      expect(analytics.events, ['catch_created encounter=new timing=on_time']);
    });

    testWidgets('catch_created: label waktu dari server (telat/sebelum drop)', (
      tester,
    ) async {
      for (final (timing, label) in [
        (CatchTiming.late, 'late'),
        (CatchTiming.early, 'early'),
      ]) {
        final analytics = FakeAnalytics();
        await pumpHome(
          tester,
          analytics: analytics,
          catches: FakeCatchRepository()..timing = timing,
        );
        await postCatch(tester, 'Milo');
        expect(analytics.events, ['catch_created encounter=new timing=$label']);
      }
    });

    testWidgets('reaction_added hanya saat reaksi ditambah & tersimpan', (
      tester,
    ) async {
      final analytics = FakeAnalytics();
      final feed = FakeFeedRepository(
        feeds: {
          'lab': [
            FeedItem(
              catchId: 'd',
              userId: 'u-d',
              displayName: 'dinda',
              createdAt: DateTime.now(),
              isLate: false,
              animalName: 'Mochi',
              animalType: 'kucing',
              personality: null,
              lateMinutes: null,
              encounterCount: 1,
              animalPhotoPath: 'u-d/d/animal.jpg',
              selfiePhotoPath: 'u-d/d/selfie.jpg',
              likeCount: 0,
              laughCount: 0,
              commentCount: 0,
              likedByMe: false,
              laughedByMe: false,
            ),
          ],
        },
      );
      await pumpHome(tester, analytics: analytics, feed: feed);
      await tapText(tester, 'feed');

      await tapFinder(tester, find.byKey(const Key('like-d')));
      await tapFinder(tester, find.byKey(const Key('like-d'))); // batal suka
      await tapFinder(tester, find.byKey(const Key('laugh-d')));
      expect(analytics.events, [
        'reaction_added type=like',
        'reaction_added type=laugh',
      ]);

      feed.reactionError = Exception('jaringan putus');
      await tapFinder(tester, find.byKey(const Key('like-d')));
      expect(analytics.events, hasLength(2), reason: 'gagal tidak dicatat');
    });

    testWidgets('circle_joined lewat kode & bikin circle', (tester) async {
      final analytics = FakeAnalytics();
      await pumpHome(
        tester,
        analytics: analytics,
        circles: FakeCircleRepository(),
      );
      await enter(tester, 'invite-code', existingInviteCode);
      await tapText(tester, 'gabung');
      expect(analytics.events, ['circle_joined method=invite_code']);

      await tapText(tester, 'buat / gabung circle lain');
      await enter(tester, 'circle-name', 'kos ceria');
      await tapText(tester, 'buat circle');
      expect(analytics.events, [
        'circle_joined method=invite_code',
        'circle_joined method=create',
      ]);
    });
  });
}
