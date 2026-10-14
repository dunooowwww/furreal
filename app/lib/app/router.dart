import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/username_screen.dart';
import '../features/camera/data/captured_photos.dart';
import '../features/camera/ui/camera_screen.dart';
import '../features/catch_result/ui/catch_result_screen.dart';
import '../features/circles/ui/circle_screen.dart';
import '../features/feed/ui/feed_screen.dart';
import '../features/home/ui/home_screen.dart';
import 'session.dart';
import 'shell.dart';
import 'splash_screen.dart';

class Routes {
  static const splash = '/';
  static const login = '/login';
  static const username = '/username';
  static const circle = '/circle';
  static const home = '/home';
  static const feed = '/feed';
  static const camera = '/camera';
  static const catchResult = '/catch/result';
}

/// Arahkan user ke layar yang sesuai tahap onboarding-nya.
String? redirectFor(AsyncValue<SessionStatus> session, String location) {
  if (session.hasError) return location == Routes.splash ? null : Routes.splash;
  // Sedang memuat ulang: tunggu hasil baru, jangan pindah layar dulu.
  if (session.isLoading && session.hasValue) return null;

  String? only(String target) => location == target ? null : target;

  return switch (session.value) {
    null => only(Routes.splash),
    SessionStatus.signedOut => only(Routes.login),
    SessionStatus.needsUsername => only(Routes.username),
    SessionStatus.needsCircle => only(Routes.circle),
    SessionStatus.ready =>
      const {Routes.splash, Routes.login, Routes.username}.contains(location)
          ? Routes.home
          : null,
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<AsyncValue<SessionStatus>>(
    const AsyncLoading(),
  );
  ref.listen(
    sessionStatusProvider,
    (_, next) => session.value = next,
    fireImmediately: true,
  );

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: session,
    redirect: (context, state) =>
        redirectFor(session.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.username,
        builder: (context, state) => const UsernameScreen(),
      ),
      GoRoute(
        path: Routes.circle,
        builder: (context, state) => const CircleScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: Routes.feed,
            builder: (context, state) => const FeedScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.camera,
        builder: (context, state) => const CameraScreen(),
      ),
      GoRoute(
        path: Routes.catchResult,
        // Tanpa foto dari kamera (mis. app dipulihkan), kembali ke beranda.
        redirect: (context, state) =>
            state.extra is CapturedPhotos ? null : Routes.home,
        builder: (context, state) =>
            CatchResultScreen(photos: state.extra! as CapturedPhotos),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    session.dispose();
  });
  return router;
});
