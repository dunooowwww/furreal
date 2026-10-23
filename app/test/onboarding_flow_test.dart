import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/auth/data/auth_repository.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('user baru: login OTP → username → buat circle → beranda', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      profiles: FakeProfileRepository(taken: {'alice'}),
    );

    // login
    expect(find.text('kirim kode'), findsOneWidget);
    expect(find.text('masuk dengan google'), findsNothing);
    await enter(tester, 'login-email', '  Alice@Example.com ');
    await tapText(tester, 'kirim kode');
    expect(auth.otpRequests, ['alice@example.com']);
    expect(
      find.text('kode 6 angka sudah dikirim ke alice@example.com'),
      findsOneWidget,
    );

    await enter(tester, 'login-code', '000000');
    await tapText(tester, 'masuk');
    expect(find.text('kodenya salah atau sudah kedaluwarsa.'), findsOneWidget);

    await enter(tester, 'login-code', validOtp);
    await tapText(tester, 'masuk');

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
    expect(find.text('kirim kode'), findsOneWidget);
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

  testWidgets('validasi format email di sisi app', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository());
    await enter(tester, 'login-email', 'bukan-email');
    await tapText(tester, 'kirim kode');
    expect(find.text('emailnya belum benar.'), findsOneWidget);
  });

  testWidgets('tombol google muncul hanya kalau metodenya diaktifkan', (
    tester,
  ) async {
    await pumpApp(
      tester,
      auth: FakeAuthRepository(),
      authMethods: const [AuthMethod.google, AuthMethod.emailOtp],
    );
    expect(find.text('masuk dengan google'), findsOneWidget);
    await tapText(tester, 'masuk dengan google');
    expect(find.text('kenalan dulu'), findsOneWidget);
  });
}
