import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/app/router.dart';
import 'package:furreal/app/session.dart';
import 'package:furreal/features/auth/data/auth_repository.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';
import 'package:furreal/shared/errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fakes.dart';

const lab = Circle(id: 'lab', name: 'lab bio', inviteCode: 'LAB234');

/// alice: akun lengkap (username, circle) dengan password.
Future<FakeAuthRepository> pumpSignedOut(
  WidgetTester tester, {
  bool confirmed = true,
  List<AuthMethod>? methods,
}) async {
  final auth = FakeAuthRepository(
    accounts: {
      'alice@example.com': FakeAccount(
        id: 'user-1',
        password: 'rahasia123',
        username: 'alice',
        confirmed: confirmed,
      ),
    },
  );
  await pumpApp(
    tester,
    auth: auth,
    profiles: FakeProfileRepository(
      profiles: {
        'user-1': const Profile(
          id: 'user-1',
          username: 'alice',
          displayName: 'Alice',
        ),
      },
    ),
    circles: FakeCircleRepository(circles: [lab]),
    authMethods: methods,
  );
  return auth;
}

void main() {
  group('masuk', () {
    testWidgets('pakai username + password', (tester) async {
      final auth = await pumpSignedOut(tester);
      await enter(tester, 'login-identifier', ' Alice ');
      await enter(tester, 'login-password', 'rahasia123');
      await tapText(tester, 'masuk');

      expect(auth.userId, 'user-1');
      expect(find.text('halo, Alice'), findsOneWidget);
    });

    testWidgets('pakai email + password', (tester) async {
      await pumpSignedOut(tester);
      await enter(tester, 'login-identifier', 'ALICE@example.com');
      await enter(tester, 'login-password', 'rahasia123');
      await tapText(tester, 'masuk');
      expect(find.text('halo, Alice'), findsOneWidget);
    });

    testWidgets('password salah → pesan yang tidak membedakan', (tester) async {
      final auth = await pumpSignedOut(tester);
      await enter(tester, 'login-identifier', 'alice');
      await enter(tester, 'login-password', 'salah');
      await tapText(tester, 'masuk');

      expect(auth.userId, isNull);
      expect(find.text('username/email atau password salah.'), findsOneWidget);

      await enter(tester, 'login-identifier', 'siapa');
      await tapText(tester, 'masuk');
      expect(find.text('username/email atau password salah.'), findsOneWidget);
    });

    testWidgets('isian kosong ditolak di app', (tester) async {
      await pumpSignedOut(tester);
      await tapText(tester, 'masuk');
      expect(
        find.text('isi username (atau email) dan password dulu.'),
        findsOneWidget,
      );
    });

    testWidgets('lihat/sembunyikan password', (tester) async {
      await pumpSignedOut(tester);
      TextField field() => tester.widget(
        find.descendant(
          of: find.byKey(const Key('login-password')),
          matching: find.byType(TextField),
        ),
      );
      expect(field().obscureText, isTrue);
      await tapFinder(tester, find.byTooltip('lihat password'));
      expect(field().obscureText, isFalse);
    });

    testWidgets('email belum diverifikasi → langsung ke langkah kode', (
      tester,
    ) async {
      final auth = await pumpSignedOut(tester, confirmed: false);
      await enter(tester, 'login-identifier', 'alice');
      await enter(tester, 'login-password', 'rahasia123');
      await tapText(tester, 'masuk');

      expect(auth.signUpCodes, [
        'alice@example.com',
      ], reason: 'kode dikirim ulang');
      expect(find.text('cek email lo'), findsOneWidget);
      await enter(tester, 'register-code', validOtp);
      await tapText(tester, 'verifikasi');
      expect(find.text('halo, Alice'), findsOneWidget);
    });
  });

  group('daftar', () {
    testWidgets('email sudah terdaftar → arahkan ke masuk', (tester) async {
      final auth = await pumpSignedOut(tester);
      await tapFinder(tester, find.byKey(const Key('go-register')));
      await enter(tester, 'register-email', 'alice@example.com');
      await enter(tester, 'register-password', 'rahasia123');
      await tapFinder(tester, find.byKey(const Key('register-submit')));

      expect(
        find.text(
          'email ini udah terdaftar. masuk aja, atau pakai lupa password.',
        ),
        findsOneWidget,
      );
      expect(auth.signUpCodes, isEmpty);

      await tapText(tester, 'masuk');
      expect(find.text('belum punya akun?'), findsOneWidget);
    });

    testWidgets('validasi email & kirim ulang / ganti email', (tester) async {
      final auth = await pumpSignedOut(tester);
      await tapFinder(tester, find.byKey(const Key('go-register')));
      await enter(tester, 'register-email', 'bukan-email');
      await enter(tester, 'register-password', 'rahasia123');
      await tapFinder(tester, find.byKey(const Key('register-submit')));
      expect(find.text('emailnya belum benar.'), findsOneWidget);

      await enter(tester, 'register-email', 'bob@example.com');
      await tapFinder(tester, find.byKey(const Key('register-submit')));
      await tapText(tester, 'kirim ulang');
      expect(auth.signUpCodes, ['bob@example.com', 'bob@example.com']);

      await tapText(tester, 'ganti email');
      expect(find.byKey(const Key('register-email')), findsOneWidget);
    });
  });

  group('lupa password', () {
    testWidgets('kode email → password baru → langsung masuk', (tester) async {
      final auth = await pumpSignedOut(tester);
      await tapText(tester, 'lupa password?');
      await enter(tester, 'forgot-email', ' Alice@Example.com');
      await tapText(tester, 'kirim kode');
      expect(auth.resetCodes, ['alice@example.com']);
      expect(
        find.text(
          'kalau alice@example.com terdaftar, kode 6 angka udah dikirim ke sana.',
        ),
        findsOneWidget,
      );

      await enter(tester, 'forgot-code', validOtp);
      await enter(tester, 'forgot-password', 'pendek');
      await tapText(tester, 'simpan password');
      expect(find.text('password minimal 8 karakter.'), findsOneWidget);

      await enter(tester, 'forgot-code', '111111');
      await enter(tester, 'forgot-password', 'barubaru123');
      await tapText(tester, 'simpan password');
      expect(
        find.text('kodenya salah atau sudah kedaluwarsa.'),
        findsOneWidget,
      );

      await enter(tester, 'forgot-code', validOtp);
      await tapText(tester, 'simpan password');
      expect(auth.accounts['alice@example.com']!.password, 'barubaru123');
      expect(find.text('password baru disimpan.'), findsOneWidget);
      expect(find.text('halo, Alice'), findsOneWidget);
    });
  });

  group('google', () {
    testWidgets('tombol hanya muncul kalau diaktifkan', (tester) async {
      await pumpSignedOut(tester);
      expect(find.text('masuk dengan google'), findsNothing);
    });

    testWidgets('akun google baru → pilih username', (tester) async {
      await pumpSignedOut(
        tester,
        methods: const [AuthMethod.password, AuthMethod.google],
      );
      await tapText(tester, 'masuk dengan google');
      expect(find.text('kenalan dulu'), findsOneWidget);
    });

    testWidgets('batal pilih akun → tetap di layar masuk tanpa error', (
      tester,
    ) async {
      final auth =
          await pumpSignedOut(
              tester,
              methods: const [AuthMethod.password, AuthMethod.google],
            )
            ..googleCanceled = true;
      await tapText(tester, 'masuk dengan google');
      expect(auth.userId, isNull);
      expect(find.text('belum punya akun?'), findsOneWidget);
      expect(find.textContaining('gagal'), findsNothing);
    });

    testWidgets('daftar dengan google dari layar daftar', (tester) async {
      await pumpSignedOut(
        tester,
        methods: const [AuthMethod.password, AuthMethod.google],
      );
      await tapFinder(tester, find.byKey(const Key('go-register')));
      await tapText(tester, 'daftar dengan google');
      expect(find.text('kenalan dulu'), findsOneWidget);
    });
  });

  group('router', () {
    AsyncValue<SessionStatus> data(SessionStatus s) => AsyncData(s);

    test('sebelum login hanya layar masuk/daftar/lupa password', () {
      final s = data(SessionStatus.signedOut);
      expect(redirectFor(s, Routes.login), isNull);
      expect(redirectFor(s, Routes.register), isNull);
      expect(redirectFor(s, Routes.forgotPassword), isNull);
      expect(redirectFor(s, Routes.home), Routes.login);
    });

    test('sudah login: layar auth kembali ke tahap berikutnya', () {
      expect(
        redirectFor(data(SessionStatus.ready), Routes.register),
        Routes.home,
      );
      expect(
        redirectFor(data(SessionStatus.needsUsername), Routes.forgotPassword),
        Routes.username,
      );
    });
  });

  test('pesan error auth ramah', () {
    expect(
      friendlyError(const InvalidLogin()),
      'username/email atau password salah.',
    );
    expect(
      friendlyError(const PostgrestException(message: 'x', code: 'FR006')),
      'terlalu banyak percobaan masuk pakai username ini. tunggu 15 menit, '
      'atau masuk pakai email.',
    );
    expect(
      friendlyError(const AuthException('x', code: 'same_password')),
      'password baru harus beda dari yang lama.',
    );
  });
}
