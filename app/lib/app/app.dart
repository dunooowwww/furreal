import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/catch_result/state/catch_providers.dart';
import '../features/daily_drop/state/daily_drop_providers.dart';
import '../features/feed/state/feed_providers.dart';
import '../features/notifications/data/push_messaging.dart';
import '../features/notifications/state/notification_providers.dart';
import 'router.dart';
import 'splash_overlay.dart';
import 'theme.dart';

class FurrealApp extends ConsumerStatefulWidget {
  const FurrealApp({super.key});

  @override
  ConsumerState<FurrealApp> createState() => _FurrealAppState();
}

class _FurrealAppState extends ConsumerState<FurrealApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<DropMessage>? _drops;
  StreamSubscription<FriendCatchMessage>? _friendCatches;
  StreamSubscription<StreakReminderMessage>? _streaks;

  @override
  void initState() {
    super.initState();
    // Drop bisa turun saat app di background: cek lagi begitu dibuka.
    _lifecycle = AppLifecycleListener(onResume: _refreshDrop);
    final push = ref.read(pushMessagingProvider);
    _drops = push.dropMessages.listen(_onDrop);
    _friendCatches = push.friendCatches.listen(_onFriendCatch);
    _streaks = push.streakReminders.listen(_onStreakReminder);
  }

  void _refreshDrop() {
    ref.invalidate(todayDropProvider);
    ref.invalidate(pushPermissionProvider);
  }

  void _onDrop(DropMessage message) {
    ref.invalidate(todayDropProvider);
    // Saat app terbuka, sistem tidak menampilkan notifikasi; kabari di sini.
    if (message == DropMessage.foreground) {
      _messenger.currentState?.showSnackBar(
        const SnackBar(content: Text('daily drop udah turun. waktunya catch!')),
      );
    }
  }

  /// Streak hampir putus: ketuk notifikasi → beranda (tombol kamera).
  void _onStreakReminder(StreakReminderMessage message) {
    ref.invalidate(todayCatchProvider);
    if (message.opened) {
      ref.read(routerProvider).go(Routes.home);
    } else {
      _messenger.currentState?.showSnackBar(
        SnackBar(
          content: Text(message.title ?? 'streak lo hampir putus!'),
          action: SnackBarAction(
            label: 'catch',
            onPressed: () => ref.read(routerProvider).push(Routes.camera),
          ),
        ),
      );
    }
  }

  /// Teman posting catch / reaksi & komentar di catch sendiri: segarkan feed;
  /// ketuk notifikasi → buka feed.
  void _onFriendCatch(FriendCatchMessage message) {
    ref.invalidate(feedControllerProvider);
    if (message.opened) {
      ref.read(routerProvider).go(Routes.feed);
    } else {
      _messenger.currentState?.showSnackBar(
        SnackBar(
          content: Text(message.title ?? 'teman lo udah catch!'),
          action: SnackBarAction(
            label: 'lihat',
            onPressed: () => ref.read(routerProvider).go(Routes.feed),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _drops?.cancel();
    _friendCatches?.cancel();
    _streaks?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(pushTokenSyncProvider);
    return MaterialApp.router(
      title: 'furreal',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scaffoldMessengerKey: _messenger,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => SplashOverlay(child: child!),
    );
  }
}
