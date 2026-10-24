import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/app/router.dart';
import 'package:furreal/app/session.dart';
import 'package:furreal/features/account/data/privacy_policy.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';

import 'helpers/fakes.dart';

const lab = Circle(id: 'lab', name: 'lab bio', inviteCode: 'LAB234');
const bobProfile = Profile(id: 'user-1', username: 'bob', displayName: 'bob');

void main() {
  group('router', () {
    AsyncValue<SessionStatus> data(SessionStatus s) => AsyncData(s);

    test('belum setuju pedoman diarahkan ke layar pedoman', () {
      final s = data(SessionStatus.needsGuidelines);
      expect(redirectFor(s, Routes.home), Routes.guidelines);
      expect(redirectFor(s, Routes.circle), Routes.guidelines);
      expect(redirectFor(s, Routes.guidelines), isNull);
    });

    test('sudah siap: layar pedoman kembali ke beranda', () {
      expect(
        redirectFor(data(SessionStatus.ready), Routes.guidelines),
        Routes.home,
      );
    });

    test('kebijakan privasi boleh dibuka di tahap mana pun', () {
      for (final s in SessionStatus.values) {
        expect(redirectFor(data(s), Routes.privacy), isNull, reason: '$s');
      }
      expect(redirectFor(const AsyncLoading(), Routes.privacy), Routes.splash);
    });
  });

  testWidgets('pedoman muncul sekali sebelum circle, lalu tersimpan', (
    tester,
  ) async {
    final profiles = FakeProfileRepository(
      profiles: {'user-1': bobProfile},
      accepted: {},
    );
    await pumpApp(
      tester,
      auth: FakeAuthRepository(userId: 'user-1'),
      profiles: profiles,
      circles: FakeCircleRepository(circles: [lab]),
    );

    expect(find.text('sebelum mulai catch'), findsOneWidget);
    for (final rule in [
      'jangan dikejar',
      'jangan dipegang atau digendong',
      'jangan dipancing atau diganggu',
      'hormati pemiliknya',
    ]) {
      expect(find.text(rule), findsOneWidget);
    }
    await tapText(tester, 'gue janji');

    expect(profiles.accepted, {'user-1'});
    expect(find.text('halo, bob'), findsOneWidget);
  });

  testWidgets('pedoman gagal disimpan → tetap di layar, pesan ramah', (
    tester,
  ) async {
    final profiles = FakeProfileRepository(
      profiles: {'user-1': bobProfile},
      accepted: {},
    )..acceptError = Exception('jaringan putus');
    await pumpApp(
      tester,
      auth: FakeAuthRepository(userId: 'user-1'),
      profiles: profiles,
      circles: FakeCircleRepository(circles: [lab]),
    );
    await tapText(tester, 'gue janji');
    expect(find.text('ada yang salah. coba lagi ya.'), findsOneWidget);
    expect(find.text('sebelum mulai catch'), findsOneWidget);
  });

  testWidgets('kebijakan privasi bisa dibuka dari layar login', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository());
    await tapText(tester, 'kebijakan privasi');

    expect(find.text('data yang kami kumpulkan'), findsOneWidget);
    await reveal(tester, find.textContaining(privacyContactEmail));
    expect(find.textContaining(privacyContactEmail), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('belum punya akun?'), findsOneWidget);
  });

  group('akun', () {
    Future<FakeAccountRepository> pumpAccount(
      WidgetTester tester, {
      Object? deleteError,
    }) async {
      final auth = FakeAuthRepository(userId: 'user-1');
      final account = FakeAccountRepository(auth)..error = deleteError;
      await pumpApp(
        tester,
        auth: auth,
        profiles: FakeProfileRepository(profiles: {'user-1': bobProfile}),
        circles: FakeCircleRepository(circles: [lab]),
        account: account,
      );
      await tapFinder(tester, find.byTooltip('pengaturan'));
      expect(find.text('@bob'), findsOneWidget);
      return account;
    }

    FilledButton confirmButton(WidgetTester tester) => tester.widget(
      find.ancestor(
        of: find.text('hapus akun @bob'),
        matching: find.byType(FilledButton),
      ),
    );

    testWidgets('kebijakan privasi dari layar akun', (tester) async {
      await pumpAccount(tester);
      await tapText(tester, 'kebijakan privasi');
      expect(find.text('ringkasan'), findsOneWidget);
    });

    testWidgets('hapus akun: wajib ketik username, lalu kembali ke login', (
      tester,
    ) async {
      final account = await pumpAccount(tester);
      await tapFinder(tester, find.byKey(const Key('delete-account')));
      expect(find.text('hapus akun @bob?'), findsOneWidget);
      expect(confirmButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('delete-confirm')), 'bobby');
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('delete-confirm')), ' Bob ');
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNotNull);

      await tapText(tester, 'hapus akun @bob');
      expect(account.deletes, 1);
      expect(find.text('belum punya akun?'), findsOneWidget);
      expect(find.text('akun lo udah dihapus. dadah!'), findsOneWidget);
    });

    testWidgets('batal → tidak ada yang dihapus', (tester) async {
      final account = await pumpAccount(tester);
      await tapFinder(tester, find.byKey(const Key('delete-account')));
      await tapText(tester, 'batal');
      expect(account.deletes, 0);
      expect(find.text('@bob'), findsOneWidget);
    });

    testWidgets('hapus gagal → pesan jelas, tetap login', (tester) async {
      final account = await pumpAccount(
        tester,
        deleteError: Exception('jaringan putus'),
      );
      await tapFinder(tester, find.byKey(const Key('delete-account')));
      await tester.enterText(find.byKey(const Key('delete-confirm')), 'bob');
      await tester.pump();
      await tapText(tester, 'hapus akun @bob');

      expect(account.deletes, 1);
      expect(
        find.text('gagal menghapus akun. cek koneksi lalu coba lagi.'),
        findsOneWidget,
      );
      expect(account.auth.userId, 'user-1');
    });
  });
}
