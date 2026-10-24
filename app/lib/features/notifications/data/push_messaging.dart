import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum PushPermission {
  granted,
  denied,

  /// Firebase belum diatur (tanpa google-services.json): notifikasi mati.
  unsupported,
}

/// Notifikasi daily drop yang diterima app.
enum DropMessage {
  /// Masuk saat app terbuka (sistem tidak menampilkan notifikasinya).
  foreground,

  /// User membuka app dengan mengetuk notifikasi.
  opened,
}

/// Notifikasi "teman udah catch" (M10).
class FriendCatchMessage {
  const FriendCatchMessage({required this.opened, this.title});

  /// true = user mengetuk notifikasinya; false = masuk saat app terbuka.
  final bool opened;

  /// Judul notifikasi, mis. "dinda udah catch!".
  final String? title;
}

abstract interface class PushMessaging {
  Future<PushPermission> permission();

  /// Tampilkan dialog izin sistem (Android 13+). Hasil akhirnya.
  Future<PushPermission> requestPermission();

  /// Token FCM HP ini, atau null kalau tidak tersedia.
  Future<String?> token();

  Stream<String> get tokenRefreshes;

  Stream<DropMessage> get dropMessages;

  Stream<FriendCatchMessage> get friendCatches;
}

/// Dipakai kalau Firebase tidak tersedia; app tetap jalan tanpa notifikasi.
class DisabledPushMessaging implements PushMessaging {
  const DisabledPushMessaging();

  @override
  Future<PushPermission> permission() async => PushPermission.unsupported;

  @override
  Future<PushPermission> requestPermission() async =>
      PushPermission.unsupported;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<DropMessage> get dropMessages => const Stream.empty();

  @override
  Stream<FriendCatchMessage> get friendCatches => const Stream.empty();
}

class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this._messaging) {
    FirebaseMessaging.onMessage.listen((m) => _route(m, opened: false));
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _route(m, opened: true));
    // App dibuka dari notifikasi saat sedang mati.
    _messaging.getInitialMessage().then((m) {
      if (m != null) _route(m, opened: true);
    });
  }

  void _route(RemoteMessage m, {required bool opened}) {
    switch (m.data['type']) {
      case 'daily_drop':
        _drops.add(opened ? DropMessage.opened : DropMessage.foreground);
      case 'friend_catch':
        _friendCatches.add(
          FriendCatchMessage(opened: opened, title: m.notification?.title),
        );
    }
  }

  final FirebaseMessaging _messaging;
  final _drops = StreamController<DropMessage>.broadcast();
  final _friendCatches = StreamController<FriendCatchMessage>.broadcast();

  static PushPermission _map(NotificationSettings s) =>
      switch (s.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermission.granted,
        _ => PushPermission.denied,
      };

  @override
  Future<PushPermission> permission() async =>
      _map(await _messaging.getNotificationSettings());

  @override
  Future<PushPermission> requestPermission() async =>
      _map(await _messaging.requestPermission());

  @override
  Future<String?> token() => _messaging.getToken();

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Stream<DropMessage> get dropMessages => _drops.stream;

  @override
  Stream<FriendCatchMessage> get friendCatches => _friendCatches.stream;
}

/// Simpan token FCM milik user yang login (null = hapus, saat keluar).
abstract interface class PushTokenRepository {
  Future<void> save(String? token);
}

class SupabasePushTokenRepository implements PushTokenRepository {
  SupabasePushTokenRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> save(String? token) =>
      _client.rpc<void>('set_fcm_token', params: {'p_token': token});
}
