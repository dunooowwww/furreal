import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/relative_time.dart';
import '../data/feed_models.dart';
import '../state/feed_providers.dart';

/// Kartu catch di feed (prototype "Feed circle").
class FeedCard extends ConsumerWidget {
  const FeedCard({
    super.key,
    required this.item,
    required this.onReact,
    required this.onComments,
    this.now,
  });

  final FeedItem item;
  final void Function(ReactionType type) onReact;
  final VoidCallback onComments;

  /// Untuk test; default DateTime.now().
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(feedPhotoBuilderProvider);
    final mono = FurrealText.mono(fontSize: 11);
    final secondary = mono.copyWith(color: FurrealColors.textSecondary);

    return Card(
      key: Key('feed-card-${item.catchId}'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                _Avatar(name: item.displayName),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        relativeTime(item.createdAt, now: now),
                        style: secondary,
                      ),
                    ],
                  ),
                ),
                _TimelinessChip(item: item),
              ],
            ),
          ),
          SizedBox(
            height: 280,
            child: Stack(
              fit: StackFit.expand,
              children: [
                photo(context, item.animalPhotoUrl, item.animalPhotoPath),
                Positioned(
                  top: 12,
                  left: 12,
                  width: 56,
                  height: 74,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: photo(
                      context,
                      item.selfiePhotoUrl,
                      item.selfiePhotoPath,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.animalName ?? 'tanpa nama',
                        style: FurrealText.display(fontSize: 24)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: FurrealColors.ink,
                          width: FurrealShape.borderWidth,
                        ),
                      ),
                      child: Text(
                        encounterLabel(item.encounterCount),
                        style: mono,
                      ),
                    ),
                  ],
                ),
                if (item.animalType != null)
                  Text(
                    item.animalType!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: FurrealColors.textSecondary,
                    ),
                  ),
                if (item.personality != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.personality!,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ActionButton(
                      key: Key('like-${item.catchId}'),
                      icon: item.likedByMe
                          ? Icons.favorite
                          : Icons.favorite_border,
                      tooltip: 'suka',
                      count: item.likeCount,
                      active: item.likedByMe,
                      onTap: () => onReact(ReactionType.like),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      key: Key('laugh-${item.catchId}'),
                      icon: item.laughedByMe
                          ? Icons.sentiment_very_satisfied
                          : Icons.sentiment_satisfied_alt_outlined,
                      tooltip: 'lucu',
                      count: item.laughCount,
                      active: item.laughedByMe,
                      onTap: () => onReact(ReactionType.laugh),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      key: Key('comments-${item.catchId}'),
                      icon: Icons.chat_bubble_outline,
                      tooltip: 'komentar',
                      count: item.commentCount,
                      active: false,
                      onTap: onComments,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "first catch" untuk pertemuan pertama, selebihnya "ketemu ke-Nx".
String encounterLabel(int count) =>
    count <= 1 ? 'first catch' : 'ketemu ke-${count}x';

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FurrealColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: FurrealColors.ink,
          width: FurrealShape.borderWidth,
        ),
      ),
      child: Text(
        initial,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}

class _TimelinessChip extends StatelessWidget {
  const _TimelinessChip({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final mono = FurrealText.mono(fontSize: 11);
    if (!item.isLate) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: FurrealColors.accent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: FurrealColors.ink,
            width: FurrealShape.borderWidth,
          ),
        ),
        child: Text('tepat waktu', style: mono),
      );
    }
    final late = item.lateMinutes;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FurrealColors.textSecondary),
      ),
      child: Text(
        late == null ? 'telat' : 'telat ${shortDuration(late)}',
        style: mono.copyWith(color: FurrealColors.textSecondary),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: active,
        label: tooltip,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text('$count', style: FurrealText.mono(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, FurrealShape.minTouchTarget),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            backgroundColor: active ? FurrealColors.accent : Colors.white,
            foregroundColor: FurrealColors.ink,
          ),
        ),
      ),
    );
  }
}
