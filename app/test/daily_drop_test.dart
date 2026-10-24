import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';
import 'package:furreal/features/daily_drop/data/daily_drop.dart';
import 'package:furreal/features/notifications/data/push_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fakes.dart';

const lab = Circle(id: 'lab', name: 'lab bio', inviteCode: 'LAB234');

Future<void> pumpHome(
  WidgetTester tester, {
  FakeDailyDropRepository? drop,
  FakeCatchRepository? catches,
  FakePushMessaging? push,
  FakeFeedRepository? feed,
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
  drop: drop,
  catches: catches,
  push: push,
  feed: feed,
);

void main() {
  group('DailyDrop', () {
    final sent = DateTime.utc(2026, 10, 14, 7, 12);

    test('fase: belum turun → tepat waktu (≤ 1 jam) → telat', () {
      expect(DailyDrop.waiting.phaseAt(sent), DropPhase.waiting);
      final drop = DailyDrop(sentAt: sent);
      expect(drop.phaseAt(sent), DropPhase.onTime);
      expect(drop.phaseAt(sent.add(onTimeWindow)), DropPhase.onTime);
      expect(
        drop.phaseAt(sent.add(onTimeWindow + const Duration(seconds: 1))),
        DropPhase.late,
      );
    });

    test('sisa waktu & format hitung mundur', () {
      final drop = DailyDrop(sentAt: sent);
      final now = sent.add(const Duration(minutes: 17, seconds: 53));
      expect(drop.remainingAt(now), const Duration(minutes: 42, seconds: 7));
      expect(formatCountdown(drop.remainingAt(now)), '42:07');
      expect(
        drop.remainingAt(sent.add(const Duration(hours: 2))),
        Duration.zero,
      );
      expect(DailyDrop.waiting.remainingAt(sent), Duration.zero);
      expect(formatCountdown(Duration.zero), '00:00');
    });
  });

  testWidgets(
    'drop belum turun: kamera tetap kebuka (M10), ditandai sebelum drop',
    (tester) async {
      await pumpHome(tester, drop: FakeDailyDropRepository(DailyDrop.waiting));

      expect(find.text('DAILY DROP · BELUM TURUN'), findsOneWidget);
      expect(find.text('catch\nduluan?'), findsOneWidget);
      expect(find.text('kamera dikunci'), findsNothing);
      expect(find.textContaining('ditandai "sebelum drop"'), findsOneWidget);

      await tapText(tester, 'feed');
      expect(
        find.text(
          'daily drop belum turun, tapi lo boleh catch duluan. '
          'catch dulu buat lihat hewan temen lo.',
        ),
        findsOneWidget,
      );
      expect(find.text('buka kamera'), findsOneWidget);

      await tapText(tester, 'buka kamera');
      final timer = tester.widget<Text>(
        find.byKey(const Key('camera-drop-timer')),
      );
      expect(timer.data, 'drop belum turun · catch ditandai sebelum drop');
    },
  );

  testWidgets('drop baru turun: hitung mundur tepat waktu + timer kamera', (
    tester,
  ) async {
    await pumpHome(tester);

    final label = tester.widget<Text>(find.byKey(const Key('drop-label')));
    expect(label.data, matches(RegExp(r'^DAILY DROP · SISA (49:5\d|50:00)$')));
    expect(find.text('waktunya\ncatch!'), findsOneWidget);

    await tapText(tester, 'buka kamera');
    final timer = tester.widget<Text>(
      find.byKey(const Key('camera-drop-timer')),
    );
    expect(timer.data, matches(RegExp(r'^sisa \d\d:\d\d buat tepat waktu$')));
  });

  testWidgets('lewat 1 jam: masih bisa catch, ditandai telat', (tester) async {
    await pumpHome(
      tester,
      drop: FakeDailyDropRepository(dropSentAgo(const Duration(hours: 2))),
    );

    expect(find.text('DAILY DROP · TELAT'), findsOneWidget);
    expect(find.text('masih bisa\ncatch!'), findsOneWidget);
    await tapText(tester, 'buka kamera');
    expect(find.text('lewat 1 jam · catch ditandai telat'), findsOneWidget);
  });

  testWidgets(
    'notifikasi drop masuk saat app terbuka → snackbar & kamera kebuka',
    (tester) async {
      final drop = FakeDailyDropRepository(DailyDrop.waiting);
      final push = FakePushMessaging(current: PushPermission.granted);
      await pumpHome(tester, drop: drop, push: push);
      expect(find.text('catch\nduluan?'), findsOneWidget);

      drop.drop = dropSentAgo(Duration.zero);
      push.drops.add(DropMessage.foreground);
      await tester.pumpAndSettle();

      expect(
        find.text('daily drop udah turun. waktunya catch!'),
        findsOneWidget,
      );
      expect(find.text('waktunya\ncatch!'), findsOneWidget);
      expect(find.text('buka kamera'), findsOneWidget);
    },
  );

  testWidgets('app dibuka dari notifikasi → drop dimuat ulang tanpa snackbar', (
    tester,
  ) async {
    final drop = FakeDailyDropRepository(DailyDrop.waiting);
    final push = FakePushMessaging(current: PushPermission.granted);
    await pumpHome(tester, drop: drop, push: push);

    drop.drop = dropSentAgo(Duration.zero);
    push.drops.add(DropMessage.opened);
    await tester.pumpAndSettle();

    expect(find.text('buka kamera'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('tarik beranda ke bawah → cek drop lagi', (tester) async {
    final drop = FakeDailyDropRepository(DailyDrop.waiting);
    await pumpHome(tester, drop: drop);
    final loads = drop.loads;

    drop.drop = dropSentAgo(Duration.zero);
    await tester.fling(find.text('furreal'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(drop.loads, greaterThan(loads));
    expect(find.text('buka kamera'), findsOneWidget);
  });

  testWidgets('server menolak catch sebelum drop (FR005) → pesan jelas', (
    tester,
  ) async {
    await pumpHome(
      tester,
      catches: FakeCatchRepository(
        failWith: const PostgrestException(
          message: 'daily drop belum turun',
          code: 'FR005',
        ),
      ),
    );
    await tapText(tester, 'buka kamera');
    await tapFinder(tester, find.byKey(const Key('shutter')));
    await tapFinder(tester, find.byKey(const Key('shutter')));
    await enter(tester, 'animal-name', 'Milo');
    await tapText(tester, 'posting ke circle');

    expect(
      find.text('daily drop belum turun. tunggu notifikasinya ya.'),
      findsOneWidget,
    );
  });

  testWidgets('beranda menampilkan status circle hari ini', (tester) async {
    await pumpHome(
      tester,
      feed: FakeFeedRepository(feeds: {'lab': []}, members: {'lab': 4}),
    );
    await reveal(tester, find.byKey(const Key('circle-status-lab')));
    expect(find.text('hari ini · 0 dari 4 udah catch'), findsOneWidget);
  });
}
