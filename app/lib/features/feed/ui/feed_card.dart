import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/relative_time.dart';
import '../../../shared/widgets/dual_photo.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../daily_drop/data/daily_drop.dart';
import '../data/feed_models.dart';

/// Kartu catch di feed (prototype "Feed circle").
class FeedCard extends ConsumerWidget {
  const FeedCard({
    super.key,
    required this.item,
    required this.onReact,
    required this.onComments,
    this.onShare,
    this.onEdit,
    this.now,
  });

  final FeedItem item;
  final void Function(ReactionType type) onReact;
  final VoidCallback onComments;

  /// Hanya untuk catch sendiri: simpan / bagikan gambarnya (M12).
  final VoidCallback? onShare;

  /// Hanya untuk catch sendiri: edit caption/nama atau hapus (M13).
  final VoidCallback? onEdit;

  /// Untuk test; default DateTime.now().
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                UserAvatar(name: item.displayName, avatarPath: item.avatarPath),
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
                if (onShare != null && !item.locked)
                  IconButton(
                    key: Key('share-${item.catchId}'),
                    tooltip: 'simpan / bagikan',
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share, size: 20),
                  ),
                if (onEdit != null)
                  IconButton(
                    key: Key('edit-${item.catchId}'),
                    tooltip: 'edit / hapus',
                    onPressed: onEdit,
                    icon: const Icon(Icons.more_vert, size: 20),
                  ),
              ],
            ),
          ),
          if (item.locked)
            const _LockedBody()
          else ...[
            DualPhoto(
              id: item.catchId,
              main: PhotoRef(
                url: item.animalPhotoUrl,
                path: item.animalPhotoPath!,
              ),
              inset: PhotoRef(
                url: item.selfiePhotoUrl,
                path: item.selfiePhotoPath!,
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
                  if (item.caption != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.caption!,
                      key: Key('caption-${item.catchId}'),
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final type in ReactionType.values)
                              _ReactionChip(
                                key: Key('${type.dbValue}-${item.catchId}'),
                                type: type,
                                count: item.reactionCount(type),
                                active: item.reactedByMe(type),
                                onTap: () => onReact(type),
                              ),
                          ],
                        ),
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
        ],
      ),
    );
  }
}

/// "first catch" untuk pertemuan pertama, selebihnya "ketemu ke-Nx".
String encounterLabel(int count) =>
    count <= 1 ? 'first catch' : 'ketemu ke-${count}x';

class _TimelinessChip extends StatelessWidget {
  const _TimelinessChip({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final mono = FurrealText.mono(fontSize: 11);
    final timing = item.timingLabel;
    if (timing != CatchTiming.late) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: timing == CatchTiming.onTime
              ? FurrealColors.accent
              : FurrealColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: FurrealColors.ink,
            width: FurrealShape.borderWidth,
          ),
        ),
        child: Text(timing.label, style: mono),
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

/// Satu reaksi emoji + jumlahnya (jumlah disembunyikan kalau nol).
class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    super.key,
    required this.type,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final ReactionType type;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: type.label,
      child: Semantics(
        button: true,
        selected: active,
        label: type.label,
        child: Material(
          color: active ? FurrealColors.accent : Colors.white,
          shape: StadiumBorder(
            side: BorderSide(
              color: active ? FurrealColors.ink : FurrealColors.surface,
              width: FurrealShape.borderWidth,
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: FurrealShape.minTouchTarget,
                minWidth: FurrealShape.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: active ? 1.15 : 1,
                      duration: const Duration(milliseconds: 150),
                      child: Text(
                        type.emoji,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Text('$count', style: FurrealText.mono(fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
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

/// Isi catch teman yang terkunci: catch dulu buat lihat (ala BeReal).
class _LockedBody extends StatelessWidget {
  const _LockedBody();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('feed-locked'),
      height: 220,
      color: FurrealColors.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Pola samar pengganti foto blur; foto aslinya memang tidak dikirim.
          const Opacity(
            opacity: 0.08,
            child: FittedBox(
              fit: BoxFit.cover,
              child: Icon(Icons.pets, color: FurrealColors.ink),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: FurrealColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: FurrealColors.ink,
                      width: FurrealShape.borderWidth,
                    ),
                  ),
                  child: const Icon(Icons.lock_outline),
                ),
                const SizedBox(height: 12),
                Text(
                  'catch dulu buat lihat',
                  style: FurrealText.display(fontSize: 20),
                ),
                const SizedBox(height: 4),
                const Text(
                  'hewan temen lo kebuka setelah lo posting catch hari ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: FurrealColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
