import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/ui/edit_profile_screen.dart';
import '../features/account/ui/privacy_policy_screen.dart';
import '../features/account/ui/settings_screen.dart';
import '../features/auth/ui/forgot_password_screen.dart';
import '../features/auth/ui/guidelines_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/register_screen.dart';
import '../features/auth/ui/username_screen.dart';
import '../features/camera/data/captured_photos.dart';
import '../features/camera/ui/camera_screen.dart';
import '../features/catch_result/ui/catch_result_screen.dart';
import '../features/circles/ui/circle_screen.dart';
import '../features/circles/ui/my_circles_screen.dart';
import '../features/collection/ui/collection_screen.dart';
import '../features/feed/ui/feed_screen.dart';
import '../features/home/ui/home_screen.dart';
import 'session.dart';
import 'shell.dart';
import 'splash_screen.dart';

class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const username = '/username';
  static const guidelines = '/guidelines';
  static const circle = '/circle';
  static const home = '/home';
  static const feed = '/feed';
  static const collection = '/collection';
  static const camera = '/camera';
  static const catchResult = '/catch/result';
  static const settings = '/settings';
  static const editProfile = '/settings/profile';
  static const myCircles = '/settings/circles';

  /// Boleh dibuka di tahap mana pun, termasuk sebelum login.
  static const privacy = '/privacy';
}

/// Layar yang boleh dibuka sebelum login.
const _signedOutRoutes = {Routes.login, Routes.register, Routes.forgotPassword};

/// Arahkan user ke layar yang sesuai tahap onboarding-nya.
String? redirectFor(AsyncValue<SessionStatus> session, String location) {
  if (session.hasError) return location == Routes.splash ? null : Routes.splash;
  // Sedang memuat ulang: tunggu hasil baru, jangan pindah layar dulu.
  if (session.isLoading && session.hasValue) return null;
  if (location == Routes.privacy && session.hasValue) return null;

  String? only(String target) => location == target ? null : target;

  return switch (session.value) {
    null => only(Routes.splash),
    SessionStatus.signedOut =>
      _signedOutRoutes.contains(location) ? null : Routes.login,
    SessionStatus.needsUsername => only(Routes.username),
    SessionStatus.needsGuidelines => only(Routes.guidelines),
    SessionStatus.needsCircle => only(Routes.circle),
    SessionStatus.ready =>
      {
            Routes.splash,
            ..._signedOutRoutes,
            Routes.username,
            Routes.guidelines,
          }.contains(location)
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
        path: Routes.register,
        builder: (context, state) => RegisterScreen(
          verifyEmail: switch (state.extra) {
            VerifyEmail(:final email) => email,
            _ => null,
          },
        ),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.username,
        builder: (context, state) => const UsernameScreen(),
      ),
      GoRoute(
        path: Routes.guidelines,
        builder: (context, state) => const GuidelinesScreen(),
      ),
      GoRoute(
        path: Routes.privacy,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: Routes.myCircles,
        builder: (context, state) => const MyCirclesScreen(),
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
          GoRoute(
            path: Routes.collection,
            builder: (context, state) => const CollectionScreen(),
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
