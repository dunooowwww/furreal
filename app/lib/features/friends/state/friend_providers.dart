import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/supabase.dart';
import '../../auth/state/auth_providers.dart';
import '../../collection/data/collection_models.dart';
import '../data/friend_repository.dart';

final friendRepositoryProvider = Provider<FriendRepository>(
  (ref) => SupabaseFriendRepository(ref.watch(supabaseClientProvider)),
);

/// Teman + permintaan masuk/keluar milik saya.
final myFriendsProvider = FutureProvider<List<FriendUser>>((ref) async {
  final userId = await ref.watch(authUserIdProvider.future);
  if (userId == null) return const [];
  return ref.watch(friendRepositoryProvider).myFriends();
});

/// Jumlah permintaan teman yang menunggu saya (titik merah di profil).
final incomingRequestCountProvider = Provider<int>((ref) {
  final list = ref.watch(myFriendsProvider).value ?? const [];
  return list.where((f) => f.relation == FriendRelation.incoming).length;
});

final userProfileProvider = FutureProvider.family<UserProfile?, String>(
  (ref, userId) => ref.watch(friendRepositoryProvider).profile(userId),
);

final userCollectionProvider =
    FutureProvider.family<List<CollectionAnimal>, String>(
      (ref, userId) => ref.watch(friendRepositoryProvider).collectionOf(userId),
    );

final userCatchesProvider = FutureProvider.family<List<HistoryCatch>, String>(
  (ref, userId) => ref.watch(friendRepositoryProvider).catchesOf(userId),
);

/// Muat ulang semua yang bergantung pada pertemanan.
void refreshFriends(WidgetRef ref, [String? userId]) {
  ref.invalidate(myFriendsProvider);
  if (userId != null) {
    ref.invalidate(userProfileProvider(userId));
    ref.invalidate(userCollectionProvider(userId));
    ref.invalidate(userCatchesProvider(userId));
  }
}
