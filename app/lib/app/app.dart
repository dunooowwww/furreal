import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/daily_drop/state/daily_drop_providers.dart';
import '../features/notifications/data/push_messaging.dart';
import '../features/notifications/state/notification_providers.dart';
import 'router.dart';
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

  @override
  void initState() {
    super.initState();
    // Drop bisa turun saat app di background: cek lagi begitu dibuka.
    _lifecycle = AppLifecycleListener(onResume: _refreshDrop);
    _drops = ref.read(pushMessagingProvider).dropMessages.listen(_onDrop);
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

  @override
  void dispose() {
    _drops?.cancel();
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
    );
  }
}
