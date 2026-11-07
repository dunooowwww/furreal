import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/errors.dart';
import '../../feed/state/feed_providers.dart';
import '../data/friend_repository.dart';
import '../state/friend_providers.dart';

/// Tombol sesuai hubungan: tambah teman / batal minta / terima + tolak /
/// teman (tap → hapus pertemanan, dengan konfirmasi).
class FriendActionButton extends ConsumerStatefulWidget {
  const FriendActionButton({
    super.key,
    required this.userId,
    required this.name,
    required this.relation,
    this.onChanged,
    this.dense = false,
  });

  final String userId;
  final String name;
  final FriendRelation relation;
  final ValueChanged<FriendRelation>? onChanged;
  final bool dense;

  @override
  ConsumerState<FriendActionButton> createState() => _FriendActionButtonState();
}

class _FriendActionButtonState extends ConsumerState<FriendActionButton> {
  bool _busy = false;

  Future<void> _run(
    Future<FriendRelation> Function(FriendRepository) action,
  ) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final next = await action(ref.read(friendRepositoryProvider));
      refreshFriends(ref, widget.userId);
      ref.invalidate(feedControllerProvider);
      widget.onChanged?.call(next);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unfriend() async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: Text('hapus ${widget.name} dari teman?'),
        content: const Text(
          'kalian nggak bisa lihat catch satu sama lain lagi '
          '(kecuali satu circle).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('batal'),
          ),
          TextButton(
            key: const Key('confirm-unfriend'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run((r) async {
        await r.remove(widget.userId);
        return FriendRelation.none;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.dense
        ? const Size(0, 36)
        : const Size(0, FurrealShape.minTouchTarget);
    final key = Key('friend-action-${widget.userId}');
    final onAction = _busy ? null : () {};
    switch (widget.relation) {
      case FriendRelation.self:
        return const SizedBox.shrink();
      case FriendRelation.none:
        return FilledButton.icon(
          key: key,
          onPressed: onAction == null
              ? null
              : () => _run((r) => r.sendRequest(widget.userId)),
          style: FilledButton.styleFrom(
            minimumSize: size,
            backgroundColor: FurrealColors.accent,
            foregroundColor: FurrealColors.ink,
          ),
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text('tambah teman'),
        );
      case FriendRelation.outgoing:
        return OutlinedButton(
          key: key,
          onPressed: onAction == null
              ? null
              : () => _run((r) async {
                  await r.remove(widget.userId);
                  return FriendRelation.none;
                }),
          style: OutlinedButton.styleFrom(minimumSize: size),
          child: const Text('batal minta'),
        );
      case FriendRelation.incoming:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              key: key,
              onPressed: onAction == null
                  ? null
                  : () => _run((r) => r.respond(widget.userId, accept: true)),
              style: FilledButton.styleFrom(
                minimumSize: size,
                backgroundColor: FurrealColors.accent,
                foregroundColor: FurrealColors.ink,
              ),
              child: const Text('terima'),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              key: Key('friend-decline-${widget.userId}'),
              onPressed: onAction == null
                  ? null
                  : () => _run((r) => r.respond(widget.userId, accept: false)),
              style: OutlinedButton.styleFrom(minimumSize: size),
              child: const Text('tolak'),
            ),
          ],
        );
      case FriendRelation.friend:
        return OutlinedButton.icon(
          key: key,
          onPressed: onAction == null ? null : _unfriend,
          style: OutlinedButton.styleFrom(minimumSize: size),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('teman'),
        );
    }
  }
}
