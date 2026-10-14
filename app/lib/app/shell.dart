import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme.dart';

/// Tab bar bawah (prototype): beranda & feed. Koleksi menyusul di M5.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _tabs = [
    (path: Routes.home, label: 'beranda', icon: Icons.home_outlined),
    (path: Routes.feed, label: 'feed', icon: Icons.chat_bubble_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexWhere((t) => location.startsWith(t.path));
    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: FurrealColors.ink,
              width: FurrealShape.borderWidth,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index < 0 ? 0 : index,
          backgroundColor: FurrealColors.background,
          indicatorColor: FurrealColors.accent,
          elevation: 0,
          onDestinationSelected: (i) => context.go(_tabs[i].path),
          destinations: [
            for (final t in _tabs)
              NavigationDestination(icon: Icon(t.icon), label: t.label),
          ],
        ),
      ),
    );
  }
}
