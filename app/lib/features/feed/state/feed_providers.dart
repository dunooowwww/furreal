import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/supabase.dart';
import '../../circles/state/circle_providers.dart';
import '../data/feed_models.dart';
import '../data/feed_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => SupabaseFeedRepository(ref.watch(supabaseClientProvider)),
);

/// Circle yang sedang dilihat di feed. null = circle pertama.
class SelectedCircle extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String circleId) => state = circleId;
}

final selectedCircleProvider = NotifierProvider<SelectedCircle, String?>(
  SelectedCircle.new,
);

/// Id circle feed yang aktif (pilihan user, atau circle pertama).
final activeCircleIdProvider = Provider<String?>((ref) {
  final circles = ref.watch(myCirclesProvider).value ?? const [];
  final selected = ref.watch(selectedCircleProvider);
  if (selected != null && circles.any((c) => c.id == selected)) {
    return selected;
  }
  return circles.isEmpty ? null : circles.first.id;
});

class FeedState {
  const FeedState({required this.items, required this.memberCount});

  final List<FeedItem> items;
  final int memberCount;

  /// Berapa anggota yang sudah catch hari ini.
  int get caughtCount => items.map((i) => i.userId).toSet().length;

  FeedState replace(FeedItem item) => FeedState(
    items: [
      for (final i in items)
        if (i.catchId == item.catchId) item else i,
    ],
    memberCount: memberCount,
  );

  FeedItem? find(String catchId) =>
      items.where((i) => i.catchId == catchId).firstOrNull;
}

class FeedController extends AsyncNotifier<FeedState> {
  FeedController(this.circleId);

  final String circleId;

  FeedRepository get _repo => ref.read(feedRepositoryProvider);

  @override
  Future<FeedState> build() async {
    final repo = ref.watch(feedRepositoryProvider);
    final results = await Future.wait([
      repo.todayFeed(circleId),
      repo.memberCount(circleId),
    ]);
    return FeedState(
      items: results[0] as List<FeedItem>,
      memberCount: results[1] as int,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Toggle reaksi secara optimistis; kembalikan ke semula kalau gagal.
  /// Melempar ulang error supaya UI bisa memberi tahu user.
  Future<void> toggleReaction(String catchId, ReactionType type) async {
    final current = state.value?.find(catchId);
    if (current == null) return;
    final on = !current.reactedByMe(type);
    _update(catchId, (item) => item.withReaction(type, on));
    try {
      await _repo.setReaction(catchId, type, on: on);
    } catch (_) {
      _update(catchId, (item) => item.withReaction(type, !on));
      rethrow;
    }
  }

  void setCommentCount(String catchId, int count) =>
      _update(catchId, (item) => item.withCommentCount(count));

  void _update(String catchId, FeedItem Function(FeedItem) change) {
    final feed = state.value;
    final item = feed?.find(catchId);
    if (feed == null || item == null) return;
    state = AsyncData(feed.replace(change(item)));
  }
}

final feedControllerProvider =
    AsyncNotifierProvider.family<FeedController, FeedState, String>(
      FeedController.new,
    );

final commentsProvider = FutureProvider.autoDispose
    .family<List<FeedComment>, String>(
      (ref, catchId) => ref.watch(feedRepositoryProvider).comments(catchId),
    );
