import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';

/// Durasi transisi pindah layar.
const pageTransitionDuration = Duration(milliseconds: 300);

/// Halaman detail yang masuk dari kanan (dan keluar ke kanan saat kembali).
/// Dibuka di navigator utama supaya menutupi tab bar.
Future<T?> pushSlide<T>(BuildContext context, Widget page) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    PageRouteBuilder<T>(
      transitionDuration: pageTransitionDuration,
      reverseTransitionDuration: pageTransitionDuration,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        ),
        child: child,
      ),
    ),
  );
}

/// Pindah tab (beranda / feed / koleksi): halaman baru (berlatar penuh)
/// memudar masuk setelah jeda singkat. Latar wajib: layar feed & koleksi
/// transparan, tanpa itu halaman lama tembus dan terlihat menumpuk.
Page<void> tabPage(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  transitionDuration: const Duration(milliseconds: 200),
  reverseTransitionDuration: const Duration(milliseconds: 200),
  child: ColoredBox(color: FurrealColors.background, child: child),
  transitionsBuilder: (_, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(
      parent: animation,
      curve: const Interval(0.3, 1, curve: Curves.easeOut),
    ),
    child: child,
  ),
);
