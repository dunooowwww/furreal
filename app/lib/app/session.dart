import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/state/auth_providers.dart';
import '../features/circles/state/circle_providers.dart';
import '../features/notifications/state/notification_providers.dart';

/// Tahap onboarding user. Menentukan layar mana yang boleh dibuka.
enum SessionStatus {
  signedOut,
  needsUsername,
  needsGuidelines,
  needsCircle,
  ready,
}

final sessionStatusProvider = FutureProvider<SessionStatus>((ref) async {
  final userId = await ref.watch(authUserIdProvider.future);
  if (userId == null) return SessionStatus.signedOut;

  final profile = await ref.watch(myProfileProvider.future);
  if (profile?.username == null) return SessionStatus.needsUsername;
  if (profile?.guidelinesAcceptedAt == null) {
    return SessionStatus.needsGuidelines;
  }

  final circles = await ref.watch(myCirclesProvider.future);
  return circles.isEmpty ? SessionStatus.needsCircle : SessionStatus.ready;
});

/// Keluar: lepas token FCM HP ini dari profil dulu (butuh sesi), baru sign out.
/// Gagal menghapus token tidak menghalangi keluar.
final signOutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      await ref
          .read(pushTokenRepositoryProvider)
          .save(null)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    await ref.read(authRepositoryProvider).signOut();
  };
});
