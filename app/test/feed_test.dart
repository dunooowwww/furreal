import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/catch_result/data/catch_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';
import 'package:furreal/features/feed/data/feed_models.dart';
import 'package:furreal/features/feed/ui/feed_card.dart';
import 'package:furreal/shared/relative_time.dart';

import 'helpers/fakes.dart';

const kos = Circle(id: 'kos', name: 'anak kos merpati', inviteCode: 'KSM234');
const lab = Circle(id: 'lab', name: 'lab bio', inviteCode: 'LAB234');

FeedItem item({
  required String id,
  required String name,
  required Duration ago,
  String animal = 'Mochi',
  String? type = 'kucing',
  int encounters = 1,
  bool late = false,
  int? lateMinutes,
  int likes = 0,
  int laughs = 0,
  int comments = 0,
  bool liked = false,
  String? personality = 'bos kamar 4b.',
}) => FeedItem(
  catchId: id,
  userId: 'u-$id',
  displayName: name,
  createdAt: DateTime.now().subtract(ago),
  isLate: late,
  lateMinutes: lateMinutes,
  animalName: animal,
  animalType: type,
  encounterCount: encounters,
  personality: personality,
  animalPhotoPath: 'u-$id/$id/animal.jpg',
  selfiePhotoPath: 'u-$id/$id/selfie.jpg',
  likeCount: likes,
  laughCount: laughs,
  commentCount: comments,
  likedByMe: liked,
  laughedByMe: false,
);

FakeFeedRepository sampleFeed() => FakeFeedRepository(
  feeds: {
    'kos': [
      item(
        id: 'd',
        name: 'dinda',
        ago: const Duration(minutes: 2),
        encounters: 12,
        likes: 7,
        laughs: 3,
        comments: 1,
      ),
      item(
        id: 'r',
        name: 'raka',
        ago: const Duration(minutes: 18),
        animal: 'Pak Kwek',
        type: 'bebek',
        late: true,
        lateMinutes: 40,
        personality: 'patroli selokan tiap pagi.',
      ),
    ],
    'lab': [
      item(
        id: 'x',
        name: 'xena',
        ago: const Duration(hours: 1),
        animal: 'Cici',
      ),
    ],
  },
  members: {'kos': 4, 'lab': 2},
  comments: {
    'd': [
      FeedComment(
        id: 'c-raka',
        displayName: 'raka',
        body: 'mochi makin gendut aja',
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
        isMine: false,
      ),
    ],
  },
);

const caughtToday = TodayCatch(
  id: 'mine',
  animalPhotoPath: 'a',
  selfiePhotoPath: 's',
  animalName: 'Milo',
  kind: AnimalKind.pet,
);

Future<void> openFeed(
  WidgetTester tester, {
  FakeFeedRepository? feed,
  TodayCatch? today = caughtToday,
  List<Circle> circles = const [kos],
}) async {
  await pumpApp(
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
    circles: FakeCircleRepository(circles: List.of(circles)),
    catches: FakeCatchRepository(today: today),
    feed: feed ?? sampleFeed(),
  );
  await tester.tap(find.text('feed').last); // tab bawah
  await tester.pumpAndSettle();
}

Finder inCard(String catchId, Finder finder) => find.descendant(
  of: find.byKey(Key('feed-card-$catchId')),
  matching: finder,
);

void main() {
  testWidgets('header & kartu feed lengkap, terbaru di atas', (tester) async {
    await openFeed(tester);

    expect(find.text('anak kos merpati'), findsOneWidget);
    expect(find.text('hari ini · 2 dari 4 udah catch'), findsOneWidget);

    // kartu dinda
    expect(inCard('d', find.text('dinda')), findsOneWidget);
    expect(inCard('d', find.text('2 mnt lalu')), findsOneWidget);
    expect(inCard('d', find.text('tepat waktu')), findsOneWidget);
    expect(inCard('d', find.text('Mochi')), findsOneWidget);
    expect(inCard('d', find.text('kucing')), findsOneWidget);
    expect(inCard('d', find.text('ketemu ke-12x')), findsOneWidget);
    expect(inCard('d', find.text('bos kamar 4b.')), findsOneWidget);
    expect(
      inCard('d', find.byKey(const Key('photo-u-d/d/animal.jpg'))),
      findsOneWidget,
    );
    expect(
      inCard('d', find.byKey(const Key('photo-u-d/d/selfie.jpg'))),
      findsOneWidget,
    );

    // kartu raka (telat, pertemuan pertama)
    await reveal(tester, find.byKey(const Key('feed-card-r')));
    expect(inCard('r', find.text('telat 40m')), findsOneWidget);
    expect(inCard('r', find.text('first catch')), findsOneWidget);
    expect(inCard('r', find.text('18 mnt lalu')), findsOneWidget);

    final dindaY = tester.getTopLeft(find.byKey(const Key('feed-card-d'))).dy;
    final rakaY = tester.getTopLeft(find.byKey(const Key('feed-card-r'))).dy;
    expect(dindaY, lessThan(rakaY));
  });

  testWidgets('belum catch → banner aksen ke kamera', (tester) async {
    await openFeed(tester, today: null);

    expect(find.text('lo belum catch hari ini'), findsOneWidget);
    await tapText(tester, 'buka kamera');
    expect(find.text('1/2 · foto hewan'), findsOneWidget);
  });

  testWidgets('sudah catch → tanpa banner', (tester) async {
    await openFeed(tester);
    expect(find.text('lo belum catch hari ini'), findsNothing);
  });

  testWidgets('empty state kalau belum ada yang catch', (tester) async {
    await openFeed(tester, feed: FakeFeedRepository(members: {'kos': 3}));
    expect(find.text('belum ada yang catch hari ini'), findsOneWidget);
    expect(find.text('hari ini · 0 dari 3 udah catch'), findsOneWidget);
  });

  testWidgets('toggle suka & lucu', (tester) async {
    final feed = sampleFeed();
    await openFeed(tester, feed: feed);

    final like = inCard('d', find.byKey(const Key('like-d')));
    await tapFinder(tester, like);
    expect(inCard('d', find.text('8')), findsOneWidget);
    await tapFinder(tester, like);
    expect(inCard('d', find.text('7')), findsOneWidget);

    await tapFinder(tester, find.byKey(const Key('laugh-d')));
    expect(inCard('d', find.text('4')), findsOneWidget);

    expect(feed.reactionCalls.map((c) => (c.type, c.on)).toList(), [
      (ReactionType.like, true),
      (ReactionType.like, false),
      (ReactionType.laugh, true),
    ]);
  });

  testWidgets('reaksi optimistis: langsung berubah, rollback kalau gagal', (
    tester,
  ) async {
    final gate = Completer<void>();
    final feed = sampleFeed()
      ..reactionGate = gate
      ..reactionError = Exception('jaringan putus');
    await openFeed(tester, feed: feed);

    await tester.tap(find.byKey(const Key('like-d')));
    await tester.pump();
    // langsung berubah sebelum server menjawab
    expect(inCard('d', find.text('8')), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(inCard('d', find.text('7')), findsOneWidget);
    expect(find.text('gagal nyimpen reaksi. coba lagi ya.'), findsOneWidget);
  });

  testWidgets('komentar: lihat, kirim, hapus milik sendiri', (tester) async {
    final feed = sampleFeed();
    await openFeed(tester, feed: feed);

    await tapFinder(tester, find.byKey(const Key('comments-d')));
    expect(find.text('komentar'), findsOneWidget);
    expect(find.text('mochi makin gendut aja'), findsOneWidget);
    // komentar orang lain tidak bisa dihapus
    expect(find.byTooltip('hapus komentar'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('comment-input')),
      '  lucu bgt  ',
    );
    await tapFinder(tester, find.byKey(const Key('comment-send')));
    expect(feed.added.single.body, 'lucu bgt');
    expect(find.text('lucu bgt'), findsOneWidget);
    expect(find.byTooltip('hapus komentar'), findsOneWidget);

    await tapFinder(tester, find.byTooltip('hapus komentar'));
    expect(feed.deletedComments, ['c-1']);
    expect(find.text('lucu bgt'), findsNothing);

    // tutup sheet: hitungan komentar di kartu ikut sinkron
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(inCard('d', find.byKey(const Key('comments-d'))), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('comments-d')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('komentar dibatasi 300 karakter', (tester) async {
    final feed = sampleFeed();
    await openFeed(tester, feed: feed);
    await tapFinder(tester, find.byKey(const Key('comments-r')));

    expect(find.text('belum ada komentar. mulai duluan!'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('comment-input')), 'a' * 350);
    await tapFinder(tester, find.byKey(const Key('comment-send')));
    expect(feed.added.single.body.length, 300);
  });

  testWidgets('ganti circle lewat pilihan di header', (tester) async {
    await openFeed(tester, circles: const [kos, lab]);

    await tapFinder(tester, find.byKey(const Key('circle-picker')));
    await tapText(tester, 'lab bio');

    expect(find.text('hari ini · 1 dari 2 udah catch'), findsOneWidget);
    expect(find.byKey(const Key('feed-card-x')), findsOneWidget);
    expect(find.byKey(const Key('feed-card-d')), findsNothing);
  });

  testWidgets('tarik ke bawah untuk refresh', (tester) async {
    final feed = sampleFeed();
    await openFeed(tester, feed: feed);
    expect(feed.feedLoads, ['kos']);

    await tester.fling(
      find.byKey(const Key('feed-card-d')),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(feed.feedLoads, ['kos', 'kos']);
  });

  group('format', () {
    final now = DateTime(2026, 10, 14, 12);
    test('waktu relatif', () {
      expect(
        relativeTime(now.subtract(const Duration(seconds: 20)), now: now),
        'baru aja',
      );
      expect(
        relativeTime(now.subtract(const Duration(minutes: 2)), now: now),
        '2 mnt lalu',
      );
      expect(
        relativeTime(now.subtract(const Duration(hours: 3)), now: now),
        '3 jam lalu',
      );
      expect(
        relativeTime(now.subtract(const Duration(days: 1)), now: now),
        'kemarin',
      );
    });
    test('durasi telat', () {
      expect(shortDuration(40), '40m');
      expect(shortDuration(65), '1j 5m');
      expect(shortDuration(120), '2j');
    });
    test('label pertemuan', () {
      expect(encounterLabel(1), 'first catch');
      expect(encounterLabel(5), 'ketemu ke-5x');
    });
  });
}
