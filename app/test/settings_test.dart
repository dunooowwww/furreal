import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/catch_result/data/catch_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';
import 'package:furreal/features/feed/data/feed_models.dart';

import 'helpers/fakes.dart';

const kos = Circle(id: 'kos', name: 'anak kos', inviteCode: 'KSM234');
const lab = Circle(id: 'lab', name: 'lab bio', inviteCode: 'LAB234');
const bob = Profile(id: 'user-1', username: 'bob', displayName: 'Bob');

const kosMembers = [
  CircleMember(userId: 'user-1', username: 'bob', displayName: 'Bob'),
  CircleMember(
    userId: 'u-dinda',
    username: 'dinda',
    displayName: 'Dinda',
    avatarPath: 'u-dinda/a.jpg',
  ),
];

Future<void> openSettings(
  WidgetTester tester, {
  FakeProfileRepository? profiles,
  FakeCircleRepository? circles,
  FakeAvatarPicker? picker,
}) async {
  await pumpApp(
    tester,
    auth: FakeAuthRepository(userId: 'user-1'),
    profiles: profiles ?? FakeProfileRepository(profiles: {'user-1': bob}),
    circles:
        circles ??
        FakeCircleRepository(circles: [kos, lab], members: {'kos': kosMembers}),
    avatarPicker: picker,
  );
  await tapFinder(tester, find.byTooltip('pengaturan'));
}

void main() {
  group('pengaturan', () {
    testWidgets('dibuka dari foto profil di beranda', (tester) async {
      await openSettings(tester);
      expect(find.text('pengaturan'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('@bob'), findsOneWidget);
      expect(find.text('edit profil'), findsOneWidget);
      expect(
        find.text('2 circle · kelola, gabung, atau keluar'),
        findsOneWidget,
      );
      expect(find.text('keluar'), findsOneWidget);
      expect(find.byKey(const Key('delete-account')), findsOneWidget);
    });

    testWidgets('edit nama & username tersimpan', (tester) async {
      final profiles = FakeProfileRepository(profiles: {'user-1': bob});
      await openSettings(tester, profiles: profiles);
      await tapText(tester, 'edit profil');

      expect(find.text('Bob'), findsWidgets); // terisi dari profil
      await enter(tester, 'edit-display-name', 'Bobby');
      await enter(tester, 'edit-username', 'Bobby.K');
      await tapText(tester, 'simpan');

      expect(profiles.profiles['user-1']!.username, 'bobby.k');
      expect(profiles.profiles['user-1']!.displayName, 'Bobby');
      expect(find.text('profil disimpan.'), findsOneWidget);
      // kembali ke pengaturan dengan data baru
      expect(find.text('@bobby.k'), findsOneWidget);
    });

    testWidgets('username tidak valid atau dipakai → pesan jelas', (
      tester,
    ) async {
      await openSettings(
        tester,
        profiles: FakeProfileRepository(
          profiles: {'user-1': bob},
          taken: {'dinda'},
        ),
      );
      await tapText(tester, 'edit profil');

      await enter(tester, 'edit-username', 'a');
      await tapText(tester, 'simpan');
      expect(
        find.text('username 3–20 karakter: huruf kecil, angka, _ atau .'),
        findsOneWidget,
      );

      await enter(tester, 'edit-username', 'dinda');
      await tapText(tester, 'simpan');
      expect(
        find.text('username sudah dipakai. coba yang lain.'),
        findsOneWidget,
      );
      expect(find.text('edit profil'), findsOneWidget); // tetap di layar
    });

    testWidgets('pilih foto profil dari galeri, lalu hapus', (tester) async {
      final profiles = FakeProfileRepository(profiles: {'user-1': bob});
      final picker = FakeAvatarPicker(result: Uint8List.fromList([1, 2, 3]));
      await openSettings(tester, profiles: profiles, picker: picker);
      await tapText(tester, 'edit profil');

      expect(find.text('B'), findsWidgets); // inisial sebelum ada foto
      await tapFinder(tester, find.byKey(const Key('change-photo')));

      expect(picker.picks, 1);
      expect(profiles.uploads.single, [1, 2, 3]);
      expect(find.text('foto profil diganti.'), findsOneWidget);
      expect(
        find.byKey(const Key('photo-user-1/avatar-1.jpg')),
        findsOneWidget,
      );
      expect(find.text('ganti foto'), findsOneWidget);

      await tapFinder(tester, find.byKey(const Key('remove-photo')));
      expect(profiles.avatars, isEmpty);
      expect(find.byKey(const Key('photo-user-1/avatar-1.jpg')), findsNothing);
      expect(find.text('pilih foto'), findsOneWidget);
    });

    testWidgets('batal memilih foto → tidak ada upload', (tester) async {
      final profiles = FakeProfileRepository(profiles: {'user-1': bob});
      final picker = FakeAvatarPicker();
      await openSettings(tester, profiles: profiles, picker: picker);
      await tapText(tester, 'edit profil');
      await tapFinder(tester, find.byKey(const Key('change-photo')));

      expect(picker.picks, 1);
      expect(profiles.uploads, isEmpty);
      expect(find.text('foto profil diganti.'), findsNothing);
    });

    testWidgets('upload foto gagal → pesan ramah', (tester) async {
      final profiles = FakeProfileRepository(profiles: {'user-1': bob})
        ..avatarError = Exception('storage mati');
      await openSettings(
        tester,
        profiles: profiles,
        picker: FakeAvatarPicker(result: Uint8List.fromList([1])),
      );
      await tapText(tester, 'edit profil');
      await tapFinder(tester, find.byKey(const Key('change-photo')));

      expect(
        find.text('gagal ganti foto. cek koneksi lalu coba lagi.'),
        findsOneWidget,
      );
    });

    testWidgets('foto profil tampil di header beranda', (tester) async {
      final profiles = FakeProfileRepository(profiles: {'user-1': bob});
      profiles.avatars['user-1'] = 'user-1/me.jpg';
      await pumpApp(
        tester,
        auth: FakeAuthRepository(userId: 'user-1'),
        profiles: profiles,
        circles: FakeCircleRepository(circles: [kos]),
      );
      expect(find.byKey(const Key('photo-user-1/me.jpg')), findsOneWidget);
    });
  });

  group('kelola circle', () {
    Future<void> openCircles(
      WidgetTester tester,
      FakeCircleRepository circles,
    ) async {
      await openSettings(tester, circles: circles);
      await tapText(tester, 'circle lo');
    }

    testWidgets('daftar circle, kode undangan, dan anggota', (tester) async {
      final messages = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          messages.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await openCircles(
        tester,
        FakeCircleRepository(circles: [kos, lab], members: {'kos': kosMembers}),
      );

      final kosCard = find.byKey(const Key('my-circle-kos'));
      expect(
        find.descendant(of: kosCard, matching: find.text('KSM234')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: kosCard, matching: find.text('ANGGOTA · 2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: kosCard, matching: find.text('Bob (lo)')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: kosCard, matching: find.text('@dinda')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: kosCard,
          matching: find.byKey(const Key('photo-u-dinda/a.jpg')),
        ),
        findsOneWidget,
      );

      await tapFinder(tester, find.byKey(const Key('copy-code-kos')));
      expect(find.text('kode undangan disalin.'), findsOneWidget);
      final copy = messages.singleWhere((m) => m.method == 'Clipboard.setData');
      expect((copy.arguments as Map)['text'], 'KSM234');
    });

    testWidgets('keluar circle (bukan yang terakhir)', (tester) async {
      final circles = FakeCircleRepository(
        circles: [kos, lab],
        members: {'kos': kosMembers},
      );
      await openCircles(tester, circles);

      await tapFinder(tester, find.byKey(const Key('leave-kos')));
      expect(find.text('keluar dari "anak kos"?'), findsOneWidget);
      expect(
        find.textContaining('catch lo nggak keliatan lagi di circle ini'),
        findsOneWidget,
      );
      await tapFinder(tester, find.byKey(const Key('confirm-leave')));

      expect(circles.left, ['kos']);
      expect(find.text('udah keluar dari anak kos.'), findsOneWidget);
      expect(find.byKey(const Key('my-circle-kos')), findsNothing);
      expect(find.byKey(const Key('my-circle-lab')), findsOneWidget);
    });

    testWidgets('batal keluar → tetap di circle', (tester) async {
      final circles = FakeCircleRepository(circles: [kos, lab]);
      await openCircles(tester, circles);
      await tapFinder(tester, find.byKey(const Key('leave-kos')));
      await tapText(tester, 'batal');
      expect(circles.left, isEmpty);
      expect(find.byKey(const Key('my-circle-kos')), findsOneWidget);
    });

    testWidgets('keluar circle terakhir → layar buat/gabung circle', (
      tester,
    ) async {
      final circles = FakeCircleRepository(circles: [lab]);
      await openCircles(tester, circles);

      await tapFinder(tester, find.byKey(const Key('leave-lab')));
      expect(find.textContaining('ini circle terakhir lo'), findsOneWidget);
      expect(
        find.textContaining(
          'lo anggota terakhir, jadi circle ini bakal kehapus',
        ),
        findsOneWidget,
      );
      await tapFinder(tester, find.byKey(const Key('confirm-leave')));

      expect(circles.left, ['lab']);
      expect(find.text('circle-mu'), findsOneWidget);
    });

    testWidgets('keluar gagal → pesan ramah, circle tetap', (tester) async {
      final circles = FakeCircleRepository(circles: [kos, lab])
        ..leaveError = Exception('jaringan putus');
      await openCircles(tester, circles);
      await tapFinder(tester, find.byKey(const Key('leave-kos')));
      await tapFinder(tester, find.byKey(const Key('confirm-leave')));

      expect(find.text('gagal keluar circle. coba lagi ya.'), findsOneWidget);
      expect(find.byKey(const Key('my-circle-kos')), findsOneWidget);
    });

    testWidgets('buat / gabung circle lain dari pengaturan', (tester) async {
      final circles = FakeCircleRepository(circles: [lab]);
      await openCircles(tester, circles);
      await tapFinder(tester, find.byKey(const Key('add-circle')));
      await enter(tester, 'invite-code', existingInviteCode);
      await tapText(tester, 'gabung');

      expect(circles.circles.map((c) => c.id), ['lab', 'c-kos']);
      expect(find.text('halo, Bob'), findsOneWidget);
    });
  });

  group('feed terkunci sampai catch', () {
    FeedItem friend({required bool locked}) => FeedItem(
      catchId: 'd',
      userId: 'u-dinda',
      displayName: 'dinda',
      avatarPath: 'u-dinda/a.jpg',
      createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      isLate: false,
      lateMinutes: null,
      locked: locked,
      animalName: locked ? null : 'Mochi',
      animalType: locked ? null : 'kucing',
      encounterCount: 1,
      personality: locked ? null : 'bos kamar 4b.',
      animalPhotoPath: locked ? null : 'u-dinda/d/animal.jpg',
      selfiePhotoPath: locked ? null : 'u-dinda/d/selfie.jpg',
      likeCount: 0,
      laughCount: 0,
      commentCount: 0,
      likedByMe: false,
      laughedByMe: false,
    );

    Future<void> openFeed(
      WidgetTester tester, {
      required bool locked,
      TodayCatch? today,
    }) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(userId: 'user-1'),
        profiles: FakeProfileRepository(profiles: {'user-1': bob}),
        circles: FakeCircleRepository(circles: [kos]),
        catches: FakeCatchRepository(today: today),
        feed: FakeFeedRepository(
          feeds: {
            'kos': [friend(locked: locked)],
          },
          members: {'kos': 3},
        ),
      );
      await tester.tap(find.text('feed').last);
      await tester.pumpAndSettle();
    }

    Finder inCard(Finder finder) => find.descendant(
      of: find.byKey(const Key('feed-card-d')),
      matching: finder,
    );

    testWidgets('belum catch: kartu teman terkunci tanpa isi', (tester) async {
      await openFeed(tester, locked: true);

      expect(find.text('lo belum catch hari ini'), findsOneWidget);
      expect(find.text('hari ini · 1 dari 3 udah catch'), findsOneWidget);
      await reveal(tester, find.byKey(const Key('feed-card-d')));
      expect(inCard(find.text('dinda')), findsOneWidget);
      expect(inCard(find.text('tepat waktu')), findsOneWidget);
      expect(inCard(find.byKey(const Key('feed-locked'))), findsOneWidget);
      expect(inCard(find.text('catch dulu buat lihat')), findsOneWidget);
      expect(inCard(find.text('Mochi')), findsNothing);
      expect(inCard(find.byKey(const Key('like-d'))), findsNothing);
      expect(inCard(find.byKey(const Key('comments-d'))), findsNothing);
      // foto profil tetap terlihat
      expect(
        inCard(find.byKey(const Key('photo-u-dinda/a.jpg'))),
        findsOneWidget,
      );
    });

    testWidgets('sudah catch: kartu teman terbuka lengkap', (tester) async {
      await openFeed(
        tester,
        locked: false,
        today: const TodayCatch(
          id: 'mine',
          animalPhotoPath: 'a',
          selfiePhotoPath: 's',
          animalName: 'Milo',
          kind: AnimalKind.pet,
        ),
      );

      expect(inCard(find.byKey(const Key('feed-locked'))), findsNothing);
      expect(inCard(find.text('Mochi')), findsOneWidget);
      expect(inCard(find.byKey(const Key('like-d'))), findsOneWidget);
      expect(
        inCard(find.byKey(const Key('photo-u-dinda/d/animal.jpg'))),
        findsOneWidget,
      );
    });

    test('FeedItem.fromJson: baris terkunci tanpa path foto', () {
      final item = FeedItem.fromJson({
        'catch_id': 'd',
        'user_id': 'u',
        'username': 'dinda',
        'display_name': null,
        'avatar_path': 'u/a.jpg',
        'created_at': '2026-10-23T03:00:00Z',
        'is_late': false,
        'late_minutes': null,
        'locked': true,
        'animal_name': null,
        'animal_type': null,
        'encounter_count': null,
        'personality': null,
        'animal_photo_path': null,
        'selfie_photo_path': null,
        'like_count': 0,
        'laugh_count': 0,
        'comment_count': 0,
        'liked_by_me': false,
        'laughed_by_me': false,
      });
      expect(item.locked, isTrue);
      expect(item.displayName, 'dinda');
      expect(item.avatarPath, 'u/a.jpg');
      expect(item.animalPhotoPath, isNull);
      expect(item.animalPhotoUrl, isNull);
    });
  });
}
