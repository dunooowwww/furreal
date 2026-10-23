import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/state/auth_providers.dart';
import '../data/circle_repository.dart';
import '../state/circle_providers.dart';

/// Kelola circle: kode undangan, anggota, keluar, buat/gabung yang lain.
class MyCirclesScreen extends ConsumerWidget {
  const MyCirclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(myCirclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('circle lo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            ...switch (circles) {
              AsyncData(:final value) => [
                for (final circle in value) ...[
                  _CircleCard(circle: circle, isLast: value.length == 1),
                  const SizedBox(height: 16),
                ],
              ],
              AsyncError() => [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'circle gagal dimuat. coba lagi ya.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              _ => [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            },
            OutlinedButton.icon(
              key: const Key('add-circle'),
              onPressed: () => context.push(Routes.circle),
              icon: const Icon(Icons.add),
              label: const Text('buat / gabung circle lain'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleCard extends ConsumerStatefulWidget {
  const _CircleCard({required this.circle, required this.isLast});

  final Circle circle;

  /// Satu-satunya circle user: keluar = harus buat/gabung circle lagi.
  final bool isLast;

  @override
  ConsumerState<_CircleCard> createState() => _CircleCardState();
}

class _CircleCardState extends ConsumerState<_CircleCard> {
  bool _leaving = false;

  Circle get _circle => widget.circle;

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _circle.inviteCode));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('kode undangan disalin.')));
    }
  }

  Future<void> _leave(int memberCount) async {
    final note = memberCount <= 1
        ? 'lo anggota terakhir, jadi circle ini bakal kehapus.'
        : 'catch lo nggak keliatan lagi di circle ini. '
              'bisa gabung lagi pakai kode undangan.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('keluar dari "${_circle.name}"?'),
        content: Text(
          widget.isLast
              ? '$note\n\nini circle terakhir lo. abis keluar, lo perlu '
                    'buat atau gabung circle lain dulu.'
              : note,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('batal'),
          ),
          TextButton(
            key: const Key('confirm-leave'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'keluar',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _leaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(circleRepositoryProvider).leaveCircle(_circle.id);
      // Circle terakhir: status sesi jadi needsCircle → router ke layar circle.
      ref.invalidate(myCirclesProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('udah keluar dari ${_circle.name}.')),
      );
    } catch (_) {
      if (mounted) setState(() => _leaving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('gagal keluar circle. coba lagi ya.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(circleMembersProvider(_circle.id));
    final myId = ref.watch(authUserIdProvider).value;
    final danger = Theme.of(context).colorScheme.error;
    final memberCount = members.value?.length ?? 1;

    return Card(
      key: Key('my-circle-${_circle.id}'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_circle.name, style: FurrealText.display(fontSize: 24)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              decoration: BoxDecoration(
                color: FurrealColors.accent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: FurrealColors.ink,
                  width: FurrealShape.borderWidth,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'KODE',
                    style: FurrealText.mono(fontSize: 11)
                        .copyWith(color: FurrealColors.textSecondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _circle.inviteCode,
                      style: FurrealText.mono(fontSize: 20),
                    ),
                  ),
                  IconButton(
                    key: Key('copy-code-${_circle.id}'),
                    tooltip: 'salin kode',
                    onPressed: _copyCode,
                    icon: const Icon(Icons.copy_rounded, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              members.hasValue ? 'ANGGOTA · $memberCount' : 'ANGGOTA',
              style: FurrealText.mono(fontSize: 11).copyWith(
                color: FurrealColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            switch (members) {
              AsyncData(:final value) => Column(
                children: [
                  for (final m in value)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          UserAvatar(
                            name: m.displayName,
                            avatarPath: m.avatarPath,
                            size: 32,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              m.userId == myId
                                  ? '${m.displayName} (lo)'
                                  : m.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (m.username != null)
                            Text(
                              '@${m.username}',
                              style: FurrealText.mono(fontSize: 12)
                                  .copyWith(color: FurrealColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              AsyncError() => const Text('anggota gagal dimuat.'),
              _ => const LinearProgressIndicator(color: FurrealColors.ink),
            },
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('leave-${_circle.id}'),
                onPressed: _leaving ? null : () => _leave(memberCount),
                icon: Icon(Icons.logout, size: 18, color: danger),
                label: Text(
                  _leaving ? 'keluar…' : 'keluar circle',
                  style: TextStyle(color: danger),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
