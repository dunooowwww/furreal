import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('user baru: daftar → kode email → username → circle → beranda', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      profiles: FakeProfileRepository(taken: {'alice'}),
    );

    // masuk → daftar
    expect(find.text('belum punya akun?'), findsOneWidget);
    expect(find.text('masuk dengan google'), findsNothing);
    await tapFinder(tester, find.byKey(const Key('go-register')));
    await enter(tester, 'register-email', '  Alice@Example.com ');
    await enter(tester, 'register-password', 'pendek');
    await tapFinder(tester, find.byKey(const Key('register-submit')));
    expect(find.text('password minimal 8 karakter.'), findsOneWidget);

    await enter(tester, 'register-password', 'rahasia123');
    await tapFinder(tester, find.byKey(const Key('register-submit')));
    expect(auth.signUpCodes, ['alice@example.com']);
    expect(
      find.text('kode 6 angka udah dikirim ke alice@example.com'),
      findsOneWidget,
    );

    await enter(tester, 'register-code', '000000');
    await tapText(tester, 'verifikasi');
    expect(find.text('kodenya salah atau sudah kedaluwarsa.'), findsOneWidget);

    await enter(tester, 'register-code', validOtp);
    await tapText(tester, 'verifikasi');
    expect(auth.accounts['alice@example.com']!.confirmed, isTrue);

    // username
    expect(find.text('kenalan dulu'), findsOneWidget);
    await enter(tester, 'username', 'alice');
    await enter(tester, 'display-name', 'alice');
    await tapText(tester, 'simpan');
    expect(
      find.text('username sudah dipakai. coba yang lain.'),
      findsOneWidget,
    );

    await enter(tester, 'username', 'Alice_2');
    await tapText(tester, 'simpan');

    // pedoman kesejahteraan hewan
    expect(find.text('sebelum mulai catch'), findsOneWidget);
    expect(find.text('jangan dikejar'), findsOneWidget);
    await tapText(tester, 'gue janji');

    // circle
    expect(find.text('circle-mu'), findsOneWidget);
    await enter(tester, 'circle-name', 'kos ceria');
    await tapText(tester, 'buat circle');
    expect(find.text('circle "kos ceria" siap!'), findsOneWidget);
    expect(find.text('ABC789'), findsOneWidget);

    await tapText(tester, 'lanjut');

    // beranda
    expect(find.text('halo, alice'), findsOneWidget);
    expect(find.text('kos ceria'), findsOneWidget);

    await tapFinder(tester, find.byTooltip('pengaturan'));
    await tapText(tester, 'keluar');
    expect(find.text('belum punya akun?'), findsOneWidget);
  });

  testWidgets('gabung circle lewat kode, kode salah ditolak', (tester) async {
    final circles = FakeCircleRepository();
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
      circles: circles,
    );

    expect(find.text('circle-mu'), findsOneWidget);
    await enter(tester, 'invite-code', 'zzzzzz');
    await tapText(tester, 'gabung');
    expect(find.text('kode undangan tidak ditemukan.'), findsOneWidget);

    await enter(tester, 'invite-code', existingInviteCode.toLowerCase());
    await tapText(tester, 'gabung');
    expect(find.text('halo, bob'), findsOneWidget);
    expect(find.text('kos ceria'), findsOneWidget);
  });

  testWidgets('user yang sudah siap langsung ke beranda', (tester) async {
    await pumpApp(
      tester,
      auth: FakeAuthRepository(userId: 'user-1'),
      profiles: FakeProfileRepository(
        profiles: {
          'user-1': const Profile(
            id: 'user-1',
            username: 'bob',
            displayName: 'bobby',
          ),
        },
      ),
      circles: FakeCircleRepository(
        circles: [const Circle(id: 'c', name: 'lab', inviteCode: 'LAB234')],
      ),
    );

    expect(find.text('halo, bobby'), findsOneWidget);
    expect(find.text('LAB234'), findsOneWidget);
  });
}
