import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/supabase.dart';
import '../data/auth_repository.dart';
import '../data/profile_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider).auth),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
);

/// Metode login yang tampil di layar login. Google ditunda (PRD §4).
final enabledAuthMethodsProvider = Provider<List<AuthMethod>>(
  (ref) => const [AuthMethod.emailOtp],
);

final authUserIdProvider = StreamProvider<String?>(
  (ref) => ref.watch(authRepositoryProvider).userIdChanges(),
);

final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final userId = await ref.watch(authUserIdProvider.future);
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchProfile(userId);
});

/// Signed URL foto profil per path. Path berganti tiap foto diganti, jadi
/// hasil boleh di-cache selama app hidup (signed URL berlaku 1 jam).
final avatarUrlProvider = FutureProvider.autoDispose.family<String?, String>((
  ref,
  path,
) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 50), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(profileRepositoryProvider).avatarUrl(path);
});
