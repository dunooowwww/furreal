import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/catch_result/data/catch_repository.dart';
import 'package:furreal/features/daily_drop/data/daily_drop.dart';
import 'package:furreal/features/feed/data/feed_models.dart';
import 'package:furreal/features/notifications/data/push_messaging.dart';

import 'notifications_test.dart' show lab, pumpHome, postCatch;
import 'helpers/fakes.dart';

FeedItem dinda({CatchTiming? timing, bool isLate = false}) => FeedItem(
  catchId: 'd',
  userId: 'u-d',
  displayName: 'dinda',
  createdAt: DateTime.now(),
  isLate: isLate,
  lateMinutes: null,
  timing: timing,
  animalName: 'Mochi',
  animalType: 'kucing',
  encounterCount: 1,
  personality: null,
  animalPhotoPath: 'u-d/d/animal.jpg',
  selfiePhotoPath: 'u-d/d/selfie.jpg',
  likeCount: 0,
  laughCount: 0,
  commentCount: 0,
  likedByMe: false,
  laughedByMe: false,
);

const bobProfile = Profile(id: 'user-1', username: 'bob', displayName: 'bob');

const caught = TodayCatch(
  id: 'mine',
  animalPhotoPath: 'a',
  selfiePhotoPath: 's',
  animalName: 'Milo',
  kind: AnimalKind.pet,
);

void main() {
  group('kabari circle setelah posting', () {
    testWidgets('notify-catch dipanggil dengan id catch', (tester) async {
      final catches = FakeCatchRepository();
      await pumpHome(tester, catches: catches);
      await postCatch(tester, 'Milo');

      expect(catches.notified, ['catch-1']);
      expect(find.text('catch terposting ke circle!'), findsOneWidget);
    });

    testWidgets('kabar gagal terkirim → catch tetap terposting', (
      tester,
    ) async {
      final catches = FakeCatchRepository()..notifyError = Exception('offline');
      await pumpHome(tester, catches: catches);
      await postCatch(tester, 'Milo');

      expect(catches.submitted, hasLength(1));
      expect(find.text('catch terposting ke circle!'), findsOneWidget);
      expect(find.text('CATCH HARI INI · BERES'), findsOneWidget);
    });

    testWidgets('posting gagal → tidak ada kabar', (tester) async {
      final catches = FakeCatchRepository()..failWith = Exception('db mati');
      await pumpHome(tester, catches: catches);
      await postCatch(tester, 'Milo');
      expect(catches.notified, isEmpty);
    });
  });

  group('notifikasi "teman udah catch"', () {
    testWidgets('masuk saat app terbuka → snackbar, "lihat" buka feed', (
      tester,
    ) async {
      final push = FakePushMessaging(current: PushPermission.granted);
      final feed = FakeFeedRepository(
        feeds: {
          'lab': [dinda()],
        },
      );
      await pumpHome(tester, push: push, feed: feed);
      final loads = feed.feedLoads.length;

      push.catches.add(
        const FriendCatchMessage(opened: false, title: 'dinda udah catch!'),
      );
      await tester.pumpAndSettle();
      expect(find.text('dinda udah catch!'), findsOneWidget);
      expect(
        feed.feedLoads.length,
        greaterThan(loads),
        reason: 'feed disegarkan',
      );

      await tapText(tester, 'lihat');
      expect(find.byKey(const Key('feed-summary')), findsOneWidget);
    });

    testWidgets('notifikasi diketuk → langsung ke feed', (tester) async {
      final push = FakePushMessaging(current: PushPermission.granted);
      await pumpHome(tester, push: push);

      push.catches.add(const FriendCatchMessage(opened: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feed-summary')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('label waktu di feed', () {
    Future<void> openFeed(WidgetTester tester, FeedItem item) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(userId: 'user-1'),
        profiles: FakeProfileRepository(profiles: {'user-1': bobProfile}),
        circles: FakeCircleRepository(circles: [lab]),
        catches: FakeCatchRepository(today: caught),
        feed: FakeFeedRepository(
          feeds: {
            'lab': [item],
          },
        ),
      );
      await tester.tap(find.text('feed').last);
      await tester.pumpAndSettle();
    }

    Finder inCard(String text) => find.descendant(
      of: find.byKey(const Key('feed-card-d')),
      matching: find.text(text),
    );

    testWidgets('catch sebelum drop → chip "sebelum drop"', (tester) async {
      await openFeed(tester, dinda(timing: CatchTiming.early));
      expect(inCard('sebelum drop'), findsOneWidget);
      expect(inCard('tepat waktu'), findsNothing);
    });

    testWidgets('data lama tanpa timing ikut is_late', (tester) async {
      await openFeed(tester, dinda(isLate: true));
      expect(inCard('telat'), findsOneWidget);
    });

    test('CatchTiming.fromDb', () {
      expect(CatchTiming.fromDb('early'), CatchTiming.early);
      expect(CatchTiming.fromDb('late'), CatchTiming.late);
      expect(CatchTiming.fromDb(null, isLate: true), CatchTiming.late);
      expect(CatchTiming.fromDb('aneh'), CatchTiming.onTime);
    });
  });
}
