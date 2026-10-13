import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/errors.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/error_text.dart';
import '../data/auth_repository.dart';
import '../state/auth_providers.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _codePattern = RegExp(r'^\d{6}$');

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    final email = normalizeEmail(_email.text);
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'emailnya belum benar.');
      return;
    }
    await _run(() async {
      await ref.read(authRepositoryProvider).sendEmailOtp(email);
      if (mounted) setState(() => _sentTo = email);
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (!_codePattern.hasMatch(code)) {
      setState(() => _error = 'kodenya 6 angka.');
      return;
    }
    // Setelah berhasil, router pindah layar sendiri lewat status sesi.
    await _run(
      () => ref
          .read(authRepositoryProvider)
          .verifyEmailOtp(email: _sentTo!, code: code),
    );
  }

  void _changeEmail() => setState(() {
    _sentTo = null;
    _code.clear();
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final methods = ref.watch(enabledAuthMethodsProvider);
    final sentTo = _sentTo;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            Text('furreal', style: FurrealText.display(fontSize: 48)),
            const SizedBox(height: 8),
            const Text('masuk dulu, terus catch hewan tiap hari.'),
            const SizedBox(height: 32),
            if (methods.contains(AuthMethod.google)) ...[
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        ref.read(authRepositoryProvider).signInWithGoogle,
                      ),
                child: const Text('masuk dengan google'),
              ),
              const SizedBox(height: 16),
              const Center(child: Text('atau')),
              const SizedBox(height: 16),
            ],
            if (methods.contains(AuthMethod.emailOtp))
              if (sentTo == null) ...[
                TextField(
                  key: const Key('login-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'email'),
                  onSubmitted: (_) => _sendCode(),
                ),
                const SizedBox(height: 16),
                BusyButton(
                  label: 'kirim kode',
                  busy: _busy,
                  onPressed: _sendCode,
                ),
              ] else ...[
                Text('kode 6 angka sudah dikirim ke $sentTo'),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('login-code'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  style: FurrealText.mono(fontSize: 24),
                  decoration: const InputDecoration(
                    labelText: 'kode',
                    counterText: '',
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 16),
                BusyButton(label: 'masuk', busy: _busy, onPressed: _verify),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : _changeEmail,
                      child: const Text('ganti email'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => ref
                                  .read(authRepositoryProvider)
                                  .sendEmailOtp(sentTo),
                            ),
                      child: const Text('kirim ulang'),
                    ),
                  ],
                ),
              ],
            ErrorText(_error),
          ],
        ),
      ),
    );
  }
}
