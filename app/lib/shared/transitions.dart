import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

/// Pindah tab (beranda / feed / koleksi): memudar + naik sedikit.
Page<void> tabPage(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  transitionDuration: const Duration(milliseconds: 220),
  reverseTransitionDuration: const Duration(milliseconds: 220),
  child: child,
  transitionsBuilder: (_, animation, _, child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  },
);
