import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/errors.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/error_text.dart';
import '../data/profile_repository.dart';
import '../state/auth_providers.dart';

class UsernameScreen extends ConsumerStatefulWidget {
  const UsernameScreen({super.key});

  @override
  ConsumerState<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends ConsumerState<UsernameScreen> {
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _username.text.trim().toLowerCase();
    final displayName = _displayName.text.trim();
    if (!usernamePattern.hasMatch(username)) {
      setState(
        () => _error = 'username 3–20 karakter: huruf kecil, angka, _ atau .',
      );
      return;
    }
    if (displayName.isEmpty || displayName.length > 40) {
      setState(() => _error = 'nama tampilan 1–40 karakter.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final userId = ref.read(authUserIdProvider).value;
      if (userId == null) return;
      await ref
          .read(profileRepositoryProvider)
          .saveUsername(
            userId: userId,
            username: username,
            displayName: displayName,
          );
      // Status sesi berubah → router pindah ke layar circle.
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            Text('kenalan dulu', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('pilih username yang bakal dilihat teman circle-mu.'),
            const SizedBox(height: 32),
            TextField(
              key: const Key('username'),
              controller: _username,
              autocorrect: false,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: 'username',
                prefixText: '@',
                helperText: 'huruf kecil, angka, _ atau .',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('display-name'),
              controller: _displayName,
              maxLength: 40,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(labelText: 'nama tampilan'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            BusyButton(label: 'simpan', busy: _busy, onPressed: _save),
            ErrorText(_error),
          ],
        ),
      ),
    );
  }
}
