import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/errors.dart';
import '../../../shared/widgets/remote_photo.dart';
import '../../catch_result/state/catch_providers.dart';
import '../../catch_result/ui/edit_catch_sheet.dart'
    show refreshAfterCatchChange;
import '../../feed/ui/share_sheet.dart';
import '../data/collection_models.dart';
import '../state/collection_providers.dart';
import '../../../shared/transitions.dart';
import '../../../shared/widgets/detail_scaffold.dart';
import 'animal_detail_sheet.dart' show shortDate;
import '../../../shared/widgets/framed_photo.dart';

const _monthNames = [
  'januari', 'februari', 'maret', 'april', 'mei', 'juni', //
  'juli', 'agustus', 'september', 'oktober', 'november', 'desember',
];

const _dayNames = [
  'senin', 'selasa', 'rabu', 'kamis', 'jumat', 'sabtu', 'minggu', //
];

/// "november 2026".
String monthLabel(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

/// Riwayat catch sendiri per hari (M16), dikelompokkan per bulan.
class HistoryView extends ConsumerWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(catchHistoryProvider);
    return switch (history) {
      AsyncData(:final value) when value.items.isEmpty => const _Message(
        title: 'riwayat lo masih kosong',
        subtitle:
            'tiap catch harian lo kesimpen di sini, walau feed-nya '
            'udah ganti hari.',
      ),
      AsyncData(:final value) => _HistoryList(history: value),
      AsyncError() => const _Message(
        title: 'riwayat gagal dimuat',
        subtitle: 'tarik ke bawah buat coba lagi.',
      ),
      _ => const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.history});

  final CatchHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = <String, List<HistoryCatch>>{};
    for (final c in history.items) {
      months.putIfAbsent(monthLabel(c.catchDate), () => []).add(c);
    }
    final label = FurrealText.mono(fontSize: 11)
        .copyWith(color: FurrealColors.textSecondary, letterSpacing: 0.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${history.items.length}${history.hasMore ? '+' : ''} hari catch',
          key: const Key('history-count'),
          style: label,
        ),
        for (final MapEntry(key: month, value: items) in months.entries) ...[
          const SizedBox(height: 16),
          Text(month.toUpperCase(), style: label),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3 / 4,
            children: [
              for (final c in items)
                _HistoryTile(
                  item: c,
                  onTap: () => showHistoryDetail(context, c),
                ),
            ],
          ),
        ],
        if (history.hasMore) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('history-more'),
            onPressed: () => ref.read(catchHistoryProvider.notifier).loadMore(),
            child: const Text('muat lagi'),
          ),
        ],
      ],
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.item, required this.onTap});

  final HistoryCatch item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(remotePhotoBuilderProvider);
    return GestureDetector(
      key: Key('history-${item.id}'),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            photo(context, item.animalPhotoUrl, item.animalPhotoPath),
            Positioned(
              top: 6,
              left: 6,
              width: 26,
              height: 34,
              child: FramedPhoto(
                radius: 6,
                borderWidth: 1.5,
                child: photo(
                  context,
                  item.selfiePhotoUrl,
                  item.selfiePhotoPath,
                ),
              ),
            ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: FurrealColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${item.catchDate.day}',
                  style: FurrealText.mono(fontSize: 12)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showHistoryDetail(BuildContext context, HistoryCatch item) =>
    pushSlide(context, HistoryDetailSheet(item: item));

class HistoryDetailSheet extends ConsumerWidget {
  const HistoryDetailSheet({super.key, required this.item});

  final HistoryCatch item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(remotePhotoBuilderProvider);
    final d = item.catchDate;
    final day = _dayNames[d.weekday - 1];
    return DetailScaffold(
      title: 'riwayat',
      child: SingleChildScrollView(
        key: const Key('history-detail'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(FurrealShape.cardRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    photo(context, item.animalPhotoUrl, item.animalPhotoPath),
                    Positioned(
                      top: 14,
                      left: 14,
                      width: 90,
                      height: 120,
                      child: FramedPhoto(
                        radius: 16,
                        borderWidth: 3,
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
            ),
            const SizedBox(height: 14),
            Text(
              item.animalName ?? 'tanpa nama',
              style: FurrealText.display(fontSize: 30),
            ),
            Text(
              [
                '$day, ${shortDate(d)}',
                item.animalType,
                item.timing.label,
              ].nonNulls.join(' · '),
              style: const TextStyle(color: FurrealColors.textSecondary),
            ),
            if ((item.caption ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                item.caption!,
                key: const Key('history-caption'),
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('history-share'),
                    onPressed: () => showShareTargetSheet(
                      context,
                      ShareTarget(
                        animalPhotoPath: item.animalPhotoPath,
                        selfiePhotoPath: item.selfiePhotoPath,
                        animalName: item.animalName,
                        caption: item.caption,
                        date: item.createdAt,
                      ),
                    ),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('bagikan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('history-delete'),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      if (await _confirmDelete(context, ref, item)) {
                        navigator.pop();
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('hapus'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Konfirmasi lalu hapus catch dari riwayat (foto ikut terhapus, streak
/// dihitung ulang). True = terhapus.
Future<bool> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  HistoryCatch item,
) async {
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) => AlertDialog(
      title: Text('hapus catch ${shortDate(item.catchDate)}?'),
      content: const Text(
        'foto & caption-nya dihapus permanen dari riwayat dan feed. '
        'streak lo dihitung ulang, jadi bisa turun.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('batal'),
        ),
        TextButton(
          key: const Key('confirm-delete-history'),
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('hapus'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(catchRepositoryProvider)
        .deleteCatch(
          catchId: item.id,
          animalId: item.animalId,
          animalPhotoPath: item.animalPhotoPath,
          selfiePhotoPath: item.selfiePhotoPath,
        );
    refreshAfterCatchChange(ref);
    messenger.showSnackBar(const SnackBar(content: Text('catch dihapus.')));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    return false;
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: FurrealColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
