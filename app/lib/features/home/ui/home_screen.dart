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
import '../../circles/state/circle_providers.dart';

/// Beranda sementara: kartu catch hari ini, daftar circle, keluar.
/// Streak, sisa waktu daily drop, dan status circle menyusul (M4–M6).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final circles = ref.watch(myCirclesProvider).value ?? const [];
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('furreal', style: FurrealText.display(fontSize: 30)),
            const SizedBox(height: 4),
            Text(
              'halo, ${profile?.displayName ?? profile?.username ?? ''}',
              style: const TextStyle(color: FurrealColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const _TodayCard(),
            const SizedBox(height: 24),
            Text('circle kamu', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final circle in circles)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    title: Text(circle.name),
                    trailing: Text(
                      circle.inviteCode,
                      style: FurrealText.mono(fontSize: 16),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.push(Routes.circle),
              child: const Text('buat / gabung circle lain'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('keluar'),
            ),
          ],
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
    final caught = today.value;
    final mono = FurrealText.mono(fontSize: 12).copyWith(letterSpacing: 0.5);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: caught == null ? FurrealColors.accent : FurrealColors.surface,
        borderRadius: BorderRadius.circular(FurrealShape.cardRadius),
        border: Border.all(
          color: FurrealColors.ink,
          width: FurrealShape.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('DAILY DROP', style: mono),
          const SizedBox(height: 14),
          if (today.isLoading && !today.hasValue)
            const Center(child: CircularProgressIndicator())
          else if (today.hasError)
            TextButton(
              onPressed: () => ref.invalidate(todayCatchProvider),
              child: const Text('gagal memuat. coba lagi'),
            )
          else if (caught == null)
            ..._buildOpenCamera(context)
          else
            ..._buildCaught(caught),
        ],
      ),
    );
  }

  List<Widget> _buildOpenCamera(BuildContext context) => [
    Text(
      'waktunya\ncatch!',
      style: FurrealText.display(fontSize: 46).copyWith(height: 0.95),
    ),
    const SizedBox(height: 14),
    const Text(
      'foto hewan pertama yang lo temuin hari ini. '
      'kamera real-time, galeri dikunci.',
      style: TextStyle(fontSize: 15, height: 1.4),
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
      'udah catch\nhari ini!',
      style: FurrealText.display(fontSize: 40).copyWith(height: 0.95),
    ),
    const SizedBox(height: 14),
    Text(
      [
        caught.animalName,
        caught.animalType,
        caught.kind?.label,
      ].nonNulls.join(' · '),
      style: FurrealText.display(fontSize: 20)
          .copyWith(fontWeight: FontWeight.w700),
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
