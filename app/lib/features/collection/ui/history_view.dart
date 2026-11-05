import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/remote_photo.dart';
import '../data/collection_models.dart';
import '../state/collection_providers.dart';
import 'animal_detail_sheet.dart' show shortDate;

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
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
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

Future<void> showHistoryDetail(BuildContext context, HistoryCatch item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => HistoryDetailSheet(item: item),
  );
}

class HistoryDetailSheet extends ConsumerWidget {
  const HistoryDetailSheet({super.key, required this.item});

  final HistoryCatch item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(remotePhotoBuilderProvider);
    final d = item.catchDate;
    final day = _dayNames[d.weekday - 1];
    return SingleChildScrollView(
      key: const Key('history-detail'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
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
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 3),
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
        ],
      ),
    );
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
