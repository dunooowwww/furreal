import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../catch_result/state/catch_providers.dart';
import '../../circles/data/circle_repository.dart';
import '../../circles/state/circle_providers.dart';
import '../../daily_drop/data/daily_drop.dart';
import '../../daily_drop/state/daily_drop_providers.dart';
import '../data/feed_models.dart';
import '../state/feed_providers.dart';
import 'comments_sheet.dart';
import 'feed_card.dart';

/// Feed circle hari ini (prototype "Feed circle").
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(myCirclesProvider).value ?? const <Circle>[];
    final circleId = ref.watch(activeCircleIdProvider);
    if (circleId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final circle = circles.firstWhere((c) => c.id == circleId);
    final feed = ref.watch(feedControllerProvider(circleId));
    final caughtToday = ref.watch(todayCatchProvider).value != null;

    Future<void> refresh() async {
      ref.invalidate(todayCatchProvider);
      ref.invalidate(todayDropProvider);
      await ref.read(feedControllerProvider(circleId).notifier).refresh();
    }

    Future<void> react(FeedItem item, ReactionType type) async {
      try {
        await ref
            .read(feedControllerProvider(circleId).notifier)
            .toggleReaction(item.catchId, type);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('gagal nyimpen reaksi. coba lagi ya.'),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          circle: circle,
          circles: circles,
          summary: switch (feed) {
            AsyncData(:final value) =>
              'hari ini · ${value.caughtCount} dari ${value.memberCount} udah catch',
            _ => 'hari ini',
          },
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: refresh,
            color: FurrealColors.ink,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                if (!caughtToday) ...[
                  const _NotCaughtBanner(),
                  const SizedBox(height: 16),
                ],
                ...switch (feed) {
                  AsyncData(:final value) when value.items.isEmpty => [
                    _EmptyFeed(caughtToday: caughtToday),
                  ],
                  AsyncData(:final value) => [
                    for (final item in value.items) ...[
                      FeedCard(
                        item: item,
                        onReact: (type) => react(item, type),
                        onComments: () => showCommentsSheet(
                          context,
                          circleId: circleId,
                          catchId: item.catchId,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                  AsyncError() => [
                    const SizedBox(height: 48),
                    const Text(
                      'feed gagal dimuat. tarik ke bawah buat coba lagi.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  _ => [
                    const SizedBox(height: 48),
                    const Center(child: CircularProgressIndicator()),
                  ],
                },
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.circle,
    required this.circles,
    required this.summary,
  });

  final Circle circle;
  final List<Circle> circles;
  final String summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pill = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: FurrealColors.ink,
          width: FurrealShape.borderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            circle.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (circles.length > 1) ...[
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, size: 16),
          ],
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: FurrealColors.ink,
            width: FurrealShape.borderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('feed', style: FurrealText.display(fontSize: 30)),
              ),
              if (circles.length > 1)
                PopupMenuButton<String>(
                  key: const Key('circle-picker'),
                  tooltip: 'pilih circle',
                  onSelected: (id) =>
                      ref.read(selectedCircleProvider.notifier).select(id),
                  itemBuilder: (_) => [
                    for (final c in circles)
                      PopupMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  child: pill,
                )
              else
                pill,
            ],
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            key: const Key('feed-summary'),
            style: FurrealText.mono(fontSize: 12)
                .copyWith(color: FurrealColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _NotCaughtBanner extends ConsumerWidget {
  const _NotCaughtBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drop = ref.watch(todayDropProvider).value;
    final waiting = drop?.phaseAt(DateTime.now()) == DropPhase.waiting;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FurrealColors.accent,
        borderRadius: BorderRadius.circular(FurrealShape.cardRadius),
        border: Border.all(
          color: FurrealColors.ink,
          width: FurrealShape.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'lo belum catch hari ini',
            style: FurrealText.display(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            waiting
                ? 'daily drop belum turun, tapi lo boleh catch duluan. '
                      'catch dulu buat lihat hewan temen lo.'
                : 'catch dulu buat lihat hewan temen lo.',
            key: const Key('not-caught-hint'),
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push(Routes.camera),
            icon: const Icon(Icons.photo_camera_outlined, size: 20),
            label: const Text('buka kamera'),
            style: FilledButton.styleFrom(
              backgroundColor: FurrealColors.ink,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.caughtToday});

  final bool caughtToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          const Icon(Icons.pets, size: 40, color: FurrealColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            'belum ada yang catch hari ini',
            textAlign: TextAlign.center,
            style: FurrealText.display(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            caughtToday
                ? 'tunggu teman-teman lo nyusul ya.'
                : 'jadi yang pertama, sebelum keduluan!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: FurrealColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
