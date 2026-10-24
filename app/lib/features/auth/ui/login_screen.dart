import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/errors.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/error_text.dart';
import '../data/auth_repository.dart';
import '../state/auth_providers.dart';
import 'auth_widgets.dart';
import 'register_screen.dart';

/// Masuk: username/email + password, atau Google.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Setelah berhasil, router pindah layar sendiri lewat status sesi.
      await action();
    } on EmailNotConfirmed catch (e) {
      if (mounted) {
        context.push(Routes.register, extra: VerifyEmail(e.email));
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    final identifier = _identifier.text.trim();
    if (identifier.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'isi username (atau email) dan password dulu.');
      return;
    }
    await _run(
      () => ref
          .read(authRepositoryProvider)
          .signInWithPassword(identifier: identifier, password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final methods = ref.watch(enabledAuthMethodsProvider);

    return AuthScaffold(
      title: 'furreal',
      subtitle: 'masuk dulu, terus catch hewan tiap hari.',
      children: [
        if (methods.contains(AuthMethod.google))
          GoogleButton(
            label: 'masuk dengan google',
            onPressed: _busy
                ? null
                : () => _run(ref.read(authRepositoryProvider).signInWithGoogle),
          ),
        TextField(
          key: const Key('login-identifier'),
          controller: _identifier,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username],
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'username atau email'),
        ),
        const SizedBox(height: 16),
        PasswordField(
          key: const Key('login-password'),
          controller: _password,
          onSubmitted: _signIn,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : () => context.push(Routes.forgotPassword),
            child: const Text('lupa password?'),
          ),
        ),
        BusyButton(label: 'masuk', busy: _busy, onPressed: _signIn),
        ErrorText(_error),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('belum punya akun?'),
            TextButton(
              key: const Key('go-register'),
              onPressed: _busy ? null : () => context.push(Routes.register),
              child: const Text('daftar'),
            ),
          ],
        ),
      ],
    );
  }
}
