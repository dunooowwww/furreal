import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/app/router.dart';
import 'package:furreal/app/session.dart';

void main() {
  AsyncValue<SessionStatus> data(SessionStatus s) => AsyncData(s);

  test('saat memuat pertama kali, semua layar diarahkan ke splash', () {
    expect(redirectFor(const AsyncLoading(), Routes.home), Routes.splash);
    expect(redirectFor(const AsyncLoading(), Routes.splash), isNull);
  });

  test('error diarahkan ke splash (ada tombol coba lagi)', () {
    final error = AsyncError<SessionStatus>(Exception('x'), StackTrace.empty);
    expect(redirectFor(error, Routes.home), Routes.splash);
  });

  test('belum login hanya boleh di layar login', () {
    final s = data(SessionStatus.signedOut);
    expect(redirectFor(s, Routes.home), Routes.login);
    expect(redirectFor(s, Routes.circle), Routes.login);
    expect(redirectFor(s, Routes.login), isNull);
  });

  test('belum punya username diarahkan ke layar username', () {
    final s = data(SessionStatus.needsUsername);
    expect(redirectFor(s, Routes.home), Routes.username);
    expect(redirectFor(s, Routes.username), isNull);
  });

  test('belum punya circle diarahkan ke layar circle', () {
    final s = data(SessionStatus.needsCircle);
    expect(redirectFor(s, Routes.home), Routes.circle);
    expect(redirectFor(s, Routes.circle), isNull);
  });

  test('sudah siap: layar onboarding ke beranda, circle tetap boleh', () {
    final s = data(SessionStatus.ready);
    expect(redirectFor(s, Routes.login), Routes.home);
    expect(redirectFor(s, Routes.username), Routes.home);
    expect(redirectFor(s, Routes.splash), Routes.home);
    expect(redirectFor(s, Routes.circle), isNull);
    expect(redirectFor(s, Routes.home), isNull);
  });

  test('saat memuat ulang dengan nilai lama, tidak pindah layar', () async {
    final provider = FutureProvider<SessionStatus>(
      (ref) async => SessionStatus.needsCircle,
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(provider, (_, _) {});
    await container.read(provider.future);

    container.invalidate(provider);
    final reloading = container.read(provider);

    expect(reloading.isLoading && reloading.hasValue, isTrue);
    expect(redirectFor(reloading, Routes.home), isNull);
  });
}
