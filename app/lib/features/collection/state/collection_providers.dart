import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../../app/supabase.dart';
import '../../auth/state/auth_providers.dart';
import '../../catch_result/data/catch_repository.dart' show AnimalKind;
import '../data/collection_models.dart';
import '../data/collection_repository.dart';

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => SupabaseCollectionRepository(ref.watch(supabaseClientProvider)),
);

final collectionProvider = FutureProvider<List<CollectionAnimal>>((ref) async {
  final userId = await ref.watch(authUserIdProvider.future);
  if (userId == null) return const [];
  return ref.watch(collectionRepositoryProvider).myCollection();
});

final streakProvider = FutureProvider<Streak>((ref) async {
  final userId = await ref.watch(authUserIdProvider.future);
  if (userId == null) return Streak.none;
  return ref.watch(collectionRepositoryProvider).myStreak();
});

final yesterdayCatchProvider = FutureProvider<YesterdayCatch?>((ref) async {
  final userId = await ref.watch(authUserIdProvider.future);
  if (userId == null) return null;
  return ref.watch(collectionRepositoryProvider).yesterdayCatch();
});

/// null = semua.
class CollectionFilter extends Notifier<AnimalKind?> {
  @override
  AnimalKind? build() => null;

  void set(AnimalKind? kind) => state = kind;
}

final collectionFilterProvider =
    NotifierProvider<CollectionFilter, AnimalKind?>(CollectionFilter.new);

/// Provider yang berubah setelah catch dibuat/dihapus (streak, koleksi, kemarin).
/// Pakai: `for (final p in catchDerivedProviders) ref.invalidate(p);`
final catchDerivedProviders = <ProviderOrFamily>[
  collectionProvider,
  streakProvider,
  yesterdayCatchProvider,
];
