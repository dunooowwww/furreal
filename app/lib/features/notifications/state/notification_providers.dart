import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/supabase.dart';
import '../../auth/state/auth_providers.dart';
import '../data/push_messaging.dart';

/// Di-override di `main.dart` kalau Firebase tersedia, dan di test.
final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => const DisabledPushMessaging(),
);

final pushTokenRepositoryProvider = Provider<PushTokenRepository>(
  (ref) => SupabasePushTokenRepository(ref.watch(supabaseClientProvider)),
);

final pushPermissionProvider = FutureProvider<PushPermission>(
  (ref) => ref.watch(pushMessagingProvider).permission(),
);

/// "nanti aja" di kartu izin notifikasi: disembunyikan sampai app dibuka lagi.
class NotificationPromptDismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

final notificationPromptDismissedProvider =
    NotifierProvider<NotificationPromptDismissed, bool>(
      NotificationPromptDismissed.new,
    );

/// Simpan token FCM HP ini ke profil selama user login, termasuk saat token
/// diperbarui. Ditonton sekali di root app.
final pushTokenSyncProvider = Provider<void>((ref) {
  final push = ref.watch(pushMessagingProvider);
  final repo = ref.watch(pushTokenRepositoryProvider);

  Future<void> save(String? token) async {
    if (token == null) return;
    try {
      await repo.save(token);
    } catch (e) {
      // Dicoba lagi saat login berikutnya / token diperbarui.
      debugPrint('simpan token FCM gagal: $e');
    }
  }

  bool signedIn() => ref.read(authUserIdProvider).value != null;

  ref.listen(authUserIdProvider, (previous, next) {
    final userId = next.value;
    if (userId != null && userId != previous?.value) {
      push.token().then(
        save,
        onError: (Object e) {
          debugPrint('ambil token FCM gagal: $e');
        },
      );
    }
  }, fireImmediately: true);

  final sub = push.tokenRefreshes.listen((token) {
    if (signedIn()) save(token);
  });
  ref.onDispose(sub.cancel);
});
