import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/session.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/error_text.dart';
import '../../auth/state/auth_providers.dart';
import '../state/account_providers.dart';

/// Akun: kebijakan privasi, keluar, hapus akun.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final username = profile?.username ?? '';
    final textTheme = Theme.of(context).textTheme;
    final danger = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: const Text('akun')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              profile?.displayName ?? username,
              style: FurrealText.display(fontSize: 28),
            ),
            Text(
              '@$username',
              style: FurrealText.mono(fontSize: 14)
                  .copyWith(color: FurrealColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('kebijakan privasi'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.privacy),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('keluar'),
                    onTap: () => ref.read(signOutProvider)(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('zona bahaya', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'hapus akun = profil, semua catch, hewan, foto, komentar, '
              'reaksi, dan streak lo hilang permanen.',
              style: TextStyle(color: FurrealColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('delete-account'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _DeleteAccountSheet(username: username),
              ),
              icon: Icon(Icons.delete_forever_outlined, color: danger),
              label: Text('hapus akun', style: TextStyle(color: danger)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(FurrealShape.minTouchTarget),
                side: BorderSide(
                  color: danger,
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

/// Konfirmasi hapus akun: wajib mengetik username sendiri.
class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet({required this.username});

  final String username;

  @override
  ConsumerState<_DeleteAccountSheet> createState() =>
      _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _matches =>
      widget.username.isNotEmpty &&
      _confirm.text.trim().toLowerCase() == widget.username;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      // Setelah ini sesi dibuang → router pindah ke layar login.
      await ref.read(accountRepositoryProvider).deleteAccount();
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('akun lo udah dihapus. dadah!')),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'gagal menghapus akun. cek koneksi lalu coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'hapus akun @${widget.username}?',
            style: FurrealText.display(fontSize: 24),
          ),
          const SizedBox(height: 8),
          const Text(
            'semua data & foto lo dihapus permanen dan nggak bisa '
            'dikembalikan. ketik username lo buat konfirmasi.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('delete-confirm'),
            controller: _confirm,
            autocorrect: false,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'username',
              prefixText: '@',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _matches && !_busy ? _delete : null,
            style: FilledButton.styleFrom(
              backgroundColor: danger,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('hapus akun @${widget.username}'),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('batal'),
          ),
          ErrorText(_error),
        ],
      ),
    );
  }
}
