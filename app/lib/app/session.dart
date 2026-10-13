import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/state/auth_providers.dart';
import '../features/circles/state/circle_providers.dart';

/// Tahap onboarding user. Menentukan layar mana yang boleh dibuka.
enum SessionStatus { signedOut, needsUsername, needsCircle, ready }

final sessionStatusProvider = FutureProvider<SessionStatus>((ref) async {
  final userId = await ref.watch(authUserIdProvider.future);
  if (userId == null) return SessionStatus.signedOut;

  final profile = await ref.watch(myProfileProvider.future);
  if (profile?.username == null) return SessionStatus.needsUsername;

  final circles = await ref.watch(myCirclesProvider.future);
  return circles.isEmpty ? SessionStatus.needsCircle : SessionStatus.ready;
});
