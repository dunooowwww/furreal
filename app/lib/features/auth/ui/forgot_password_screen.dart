import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/errors.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/error_text.dart';
import '../data/auth_repository.dart';
import '../state/auth_providers.dart';
import 'auth_widgets.dart';

/// Lupa password: kode 6 angka ke email, lalu password baru. Juga jalan buat
/// akun lama (dulu masuk pakai kode) yang belum punya password.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  String? _sentTo;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

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
    if (!emailPattern.hasMatch(email)) {
      setState(() => _error = 'emailnya belum benar.');
      return;
    }
    await _run(() async {
      await _auth.sendPasswordReset(email);
      if (mounted) setState(() => _sentTo = email);
    });
  }

  Future<void> _save() async {
    final code = _code.text.trim();
    if (!otpPattern.hasMatch(code)) {
      setState(() => _error = 'kodenya 6 angka.');
      return;
    }
    if (_password.text.length < passwordMinLength) {
      setState(() => _error = 'password minimal $passwordMinLength karakter.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    await _run(() async {
      // Setelah kode benar, user langsung masuk dan router pindah layar.
      await _auth.resetPassword(
        email: _sentTo!,
        code: code,
        newPassword: _password.text,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('password baru disimpan.')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    if (sentTo == null) {
      return AuthScaffold(
        title: 'lupa password',
        subtitle: 'masukin email akun lo, nanti kami kirim kode 6 angka.',
        children: [
          TextField(
            key: const Key('forgot-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'email'),
            onSubmitted: (_) => _sendCode(),
          ),
          const SizedBox(height: 16),
          BusyButton(label: 'kirim kode', busy: _busy, onPressed: _sendCode),
          ErrorText(_error),
        ],
      );
    }

    return AuthScaffold(
      title: 'password baru',
      subtitle: 'kalau $sentTo terdaftar, kode 6 angka udah dikirim ke sana.',
      children: [
        CodeField(key: const Key('forgot-code'), controller: _code),
        const SizedBox(height: 16),
        PasswordField(
          key: const Key('forgot-password'),
          controller: _password,
          label: 'password baru',
          newPassword: true,
          helperText: 'minimal $passwordMinLength karakter',
          onSubmitted: _save,
        ),
        const SizedBox(height: 16),
        BusyButton(label: 'simpan password', busy: _busy, onPressed: _save),
        ErrorText(_error),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _sentTo = null;
                      _code.clear();
                      _error = null;
                    }),
              child: const Text('ganti email'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() => _auth.sendPasswordReset(sentTo)),
              child: const Text('kirim ulang'),
            ),
          ],
        ),
      ],
    );
  }
}
