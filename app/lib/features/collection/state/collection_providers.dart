import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../../app/supabase.dart';
import '../../auth/state/auth_providers.dart';
import '../../catch_result/data/catch_repository.dart' show AnimalKind;
import '../data/collection_models.dart';
import '../data/cutout.dart';
import '../data/collection_repository.dart';

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => SupabaseCollectionRepository(ref.watch(supabaseClientProvider)),
);

final collectionProvider = FutureProvider<List<CollectionAnimal>>((ref) async {
  final userId = await ref.watch(authUserIdProvider.future);
  if (userId == null) return const [];
  return ref.watch(collectionRepositoryProvider).myCollection();
});

/// Nomor kartu (#0001 = hewan pertama) per id hewan.
final collectionNumbersProvider = Provider<Map<String, int>>((ref) {
  final animals = ref.watch(collectionProvider).value ?? const [];
  return collectionNumbers(animals);
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

/// Riwayat catch sendiri (M16), dimuat per halaman.
class CatchHistory {
  const CatchHistory(this.items, {required this.hasMore});

  final List<HistoryCatch> items;
  final bool hasMore;
}

class CatchHistoryController extends AsyncNotifier<CatchHistory> {
  bool _loadingMore = false;

  @override
  Future<CatchHistory> build() async {
    final userId = await ref.watch(authUserIdProvider.future);
    if (userId == null) return const CatchHistory([], hasMore: false);
    final page = await ref.watch(collectionRepositoryProvider).myCatches();
    return CatchHistory(page, hasMore: page.length >= historyPageSize);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final page = await ref
          .read(collectionRepositoryProvider)
          .myCatches(before: current.items.last.catchDate);
      state = AsyncData(
        CatchHistory([
          ...current.items,
          ...page,
        ], hasMore: page.length >= historyPageSize),
      );
    } finally {
      _loadingMore = false;
    }
  }
}

final catchHistoryProvider =
    AsyncNotifierProvider<CatchHistoryController, CatchHistory>(
      CatchHistoryController.new,
    );

/// Tab koleksi: kartu atau riwayat.
enum CollectionTab { cards, history }

class CollectionTabNotifier extends Notifier<CollectionTab> {
  @override
  CollectionTab build() => CollectionTab.cards;

  void set(CollectionTab tab) => state = tab;
}

final collectionTabProvider =
    NotifierProvider<CollectionTabNotifier, CollectionTab>(
      CollectionTabNotifier.new,
    );

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
  catchHistoryProvider,
];

final cutoutMakerProvider = Provider<CutoutMaker>((ref) => MlKitCutoutMaker());

final cutoutRepositoryProvider = Provider<CutoutRepository>(
  (ref) => SupabaseCutoutRepository(ref.watch(supabaseClientProvider)),
);

/// Satu per sesi app, supaya catch lama yang sudah dicoba tidak diulang.
final cutoutServiceProvider = Provider<CutoutService>(
  (ref) => CutoutService(
    ref.watch(cutoutMakerProvider),
    ref.watch(cutoutRepositoryProvider),
  ),
);

/// Potong hewan dari catch lama di latar belakang setiap koleksi dimuat.
/// Kalau ada yang tersimpan, koleksi dimuat ulang (kartunya pakai potongan).
final cutoutBackfillProvider = Provider<void>((ref) {
  ref.listen(collectionProvider, (_, next) async {
    final animals = next.value;
    if (animals == null || CutoutService.pending(animals).isEmpty) return;
    final saved = await ref.read(cutoutServiceProvider).backfill(animals);
    if (saved > 0) ref.invalidate(collectionProvider);
  }, fireImmediately: true);
});
