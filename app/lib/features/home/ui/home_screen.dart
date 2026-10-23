import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/errors.dart';
import '../../auth/state/auth_providers.dart';
import '../../catch_result/data/catch_repository.dart';
import '../../catch_result/state/catch_providers.dart';
import '../../circles/data/circle_repository.dart';
import '../../circles/state/circle_providers.dart';
import '../../collection/data/collection_models.dart';
import '../../collection/state/collection_providers.dart';
import '../../daily_drop/data/daily_drop.dart';
import '../../daily_drop/state/daily_drop_providers.dart';
import '../../feed/state/feed_providers.dart';
import '../../notifications/ui/notification_prompt.dart';
import '../../../shared/widgets/remote_photo.dart';
import '../../../shared/widgets/user_avatar.dart';

/// Beranda: streak, izin notifikasi, kartu daily drop / catch hari ini,
/// tangkapan kemarin, status circle hari ini.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final circles = ref.watch(myCirclesProvider).value ?? const [];
    final textTheme = Theme.of(context).textTheme;

    Future<void> refresh() async {
      ref.invalidate(todayDropProvider);
      ref.invalidate(todayCatchProvider);
      for (final circle in circles) {
        ref.invalidate(feedControllerProvider(circle.id));
      }
      await ref.read(todayDropProvider.future);
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refresh,
          color: FurrealColors.ink,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'furreal',
                      style: FurrealText.display(fontSize: 30),
                    ),
                  ),
                  const _StreakChip(),
                  const SizedBox(width: 8),
                  const _SettingsButton(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'halo, ${profile?.displayName ?? profile?.username ?? ''}',
                style: const TextStyle(color: FurrealColors.textSecondary),
              ),
              const SizedBox(height: 20),
              const NotificationPrompt(),
              const _TodayCard(),
              const _YesterdayCard(),
              const SizedBox(height: 24),
              Text('circle kamu', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final circle in circles) _CircleTile(circle: circle),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.push(Routes.circle),
                child: const Text('buat / gabung circle lain'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu "daily drop" (prototype beranda): buka kamera, atau catch hari ini.
class _TodayCard extends ConsumerStatefulWidget {
  const _TodayCard();

  @override
  ConsumerState<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends ConsumerState<_TodayCard> {
  bool _deleting = false;

  Future<void> _deleteToday() async {
    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(catchRepositoryProvider).deleteTodayCatch();
      ref.invalidate(todayCatchProvider);
      for (final p in catchDerivedProviders) {
        ref.invalidate(p);
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('catch hari ini dihapus (debug).')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayCatchProvider);
    final drop = ref.watch(todayDropProvider);
    final caught = today.value;
    final now = watchDropClock(ref, drop.value);
    final phase = drop.value?.phaseAt(now);
    final mono = FurrealText.mono(fontSize: 12).copyWith(letterSpacing: 0.5);
    final loading =
        (today.isLoading && !today.hasValue) ||
        (drop.isLoading && !drop.hasValue);
    final failed = today.hasError || drop.hasError;
    final waiting = caught == null && phase == DropPhase.waiting;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: caught == null && !waiting
            ? FurrealColors.accent
            : FurrealColors.surface,
        borderRadius: BorderRadius.circular(FurrealShape.cardRadius),
        border: Border.all(
          color: FurrealColors.ink,
          width: FurrealShape.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (caught != null)
            Text('CATCH HARI INI · BERES', style: mono)
          else
            _DropLabel(drop: drop.value, now: now, style: mono),
          const SizedBox(height: 14),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (failed)
            TextButton(
              onPressed: () {
                ref.invalidate(todayCatchProvider);
                ref.invalidate(todayDropProvider);
              },
              child: const Text('gagal memuat. coba lagi'),
            )
          else if (caught != null)
            ..._buildCaught(caught)
          else if (waiting)
            ..._buildWaiting()
          else
            ..._buildOpenCamera(context, late: phase == DropPhase.late),
        ],
      ),
    );
  }

  List<Widget> _buildWaiting() => [
    Text(
      'sabar\ndulu.',
      style: FurrealText.display(fontSize: 46).copyWith(height: 0.95),
    ),
    const SizedBox(height: 14),
    const Text(
      'daily drop turun sekali sehari, antara jam 10 pagi sampai 8 malam. '
      'kamera kebuka begitu notifikasinya masuk.',
      style: TextStyle(fontSize: 15, height: 1.4),
    ),
    const SizedBox(height: 14),
    FilledButton.icon(
      onPressed: null,
      icon: const Icon(Icons.lock_outline, size: 20),
      label: const Text('kamera dikunci'),
      style: FilledButton.styleFrom(
        disabledBackgroundColor: FurrealColors.background,
        disabledForegroundColor: FurrealColors.textSecondary,
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(
          side: BorderSide(
            color: FurrealColors.textSecondary,
            width: FurrealShape.borderWidth,
          ),
        ),
      ),
    ),
  ];

  List<Widget> _buildOpenCamera(BuildContext context, {required bool late}) => [
    Text(
      late ? 'masih bisa\ncatch!' : 'waktunya\ncatch!',
      style: FurrealText.display(fontSize: 46).copyWith(height: 0.95),
    ),
    const SizedBox(height: 14),
    Text(
      late
          ? 'udah lewat 1 jam dari drop, jadi catch lo ditandai telat. '
                'gapapa, yang penting catch.'
          : 'foto hewan pertama yang lo temuin hari ini. '
                'kamera real-time, galeri dikunci.',
      style: const TextStyle(fontSize: 15, height: 1.4),
    ),
    const SizedBox(height: 14),
    FilledButton.icon(
      onPressed: () => context.push(Routes.camera),
      icon: const Icon(Icons.photo_camera_outlined, size: 20),
      label: const Text('buka kamera'),
      style: FilledButton.styleFrom(
        backgroundColor: FurrealColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
      ),
    ),
  ];

  List<Widget> _buildCaught(TodayCatch caught) => [
    Text(
      caught.animalName ?? 'tanpa nama',
      key: const Key('today-animal'),
      style: FurrealText.display(fontSize: 40).copyWith(height: 0.95),
    ),
    const SizedBox(height: 8),
    Text(
      [caught.animalType, caught.kind?.label].nonNulls.join(' · '),
      style: const TextStyle(fontSize: 15),
    ),
    const SizedBox(height: 4),
    const Text(
      'besok ada daily drop lagi.',
      style: TextStyle(color: FurrealColors.textSecondary),
    ),
    // Hanya untuk tes berulang di mode debug; tidak ada di build rilis.
    if (kDebugMode) ...[
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: _deleting ? null : _deleteToday,
        child: Text(_deleting ? 'menghapus…' : 'hapus catch hari ini (debug)'),
      ),
    ],
  ];
}

/// Chip streak di header (0 kalau streak sudah putus).
class _StreakChip extends ConsumerWidget {
  const _StreakChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider).value ?? Streak.none;
    return Semantics(
      label: 'streak ${streak.current} hari',
      excludeSemantics: true,
      child: Container(
        key: const Key('streak-chip'),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: FurrealColors.ink,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department_outlined,
              size: 16,
              color: FurrealColors.accent,
            ),
            const SizedBox(width: 6),
            Text(
              '${streak.current}',
              style: FurrealText.mono(fontSize: 14)
                  .copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Tangkapan kemarin" (prototype beranda). Disembunyikan kalau tidak ada.
class _YesterdayCard extends ConsumerWidget {
  const _YesterdayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yesterday = ref.watch(yesterdayCatchProvider).value;
    if (yesterday == null) return const SizedBox.shrink();
    final photo = ref.watch(remotePhotoBuilderProvider);
    final encounter = yesterday.encounterCount <= 1
        ? 'first catch'
        : 'ketemu ke-${yesterday.encounterCount}x';

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        key: const Key('yesterday-card'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: FurrealColors.ink,
            width: FurrealShape.borderWidth,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox.square(
                dimension: 64,
                child: photo(context, yesterday.photoUrl, yesterday.photoPath),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TANGKAPAN KEMARIN',
                    style: FurrealText.mono(fontSize: 11).copyWith(
                      color: FurrealColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    yesterday.animalName,
                    style: FurrealText.display(fontSize: 20)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    [yesterday.animalType, encounter].nonNulls.join(' · '),
                    style: const TextStyle(
                      fontSize: 13,
                      color: FurrealColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'lihat koleksi',
              onPressed: () => context.go(Routes.collection),
              icon: const Icon(Icons.chevron_right),
              style: IconButton.styleFrom(
                fixedSize: const Size.square(FurrealShape.minTouchTarget),
                side: const BorderSide(
                  color: FurrealColors.ink,
                  width: FurrealShape.borderWidth,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label kartu daily drop: belum turun / sisa waktu tepat-waktu / telat.
class _DropLabel extends StatelessWidget {
  const _DropLabel({
    required this.drop,
    required this.now,
    required this.style,
  });

  final DailyDrop? drop;
  final DateTime now;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final drop = this.drop;
    final text = switch (drop?.phaseAt(now)) {
      null => 'DAILY DROP',
      DropPhase.waiting => 'DAILY DROP · BELUM TURUN',
      DropPhase.onTime =>
        'DAILY DROP · SISA ${formatCountdown(drop!.remainingAt(now))}',
      DropPhase.late => 'DAILY DROP · TELAT',
    };
    return Text(text, key: const Key('drop-label'), style: style);
  }
}

/// Circle + status hari ini ("2 dari 5 udah catch") + kode undangan.
class _CircleTile extends ConsumerWidget {
  const _CircleTile({required this.circle});

  final Circle circle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedControllerProvider(circle.id)).value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          title: Text(circle.name),
          subtitle: feed == null
              ? null
              : Text(
                  'hari ini · ${feed.caughtCount} dari ${feed.memberCount} '
                  'udah catch',
                  key: Key('circle-status-${circle.id}'),
                ),
          trailing: Text(
            circle.inviteCode,
            style: FurrealText.mono(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

/// Foto profil di header beranda → pengaturan.
class _SettingsButton extends ConsumerWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    return Tooltip(
      message: 'pengaturan',
      child: Semantics(
        button: true,
        label: 'pengaturan',
        excludeSemantics: true,
        child: InkWell(
          key: const Key('open-settings'),
          customBorder: const CircleBorder(),
          onTap: () => context.push(Routes.settings),
          child: SizedBox.square(
            dimension: FurrealShape.minTouchTarget,
            child: Center(
              child: UserAvatar(
                name: profile?.displayName ?? profile?.username ?? '',
                avatarPath: profile?.avatarPath,
                size: FurrealShape.minTouchTarget,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
