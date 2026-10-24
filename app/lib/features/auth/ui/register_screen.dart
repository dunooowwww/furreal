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

/// Argumen route daftar: langsung ke langkah verifikasi untuk [email]
/// (akun sudah dibuat tapi email belum diverifikasi).
class VerifyEmail {
  const VerifyEmail(this.email);

  final String email;
}

/// Daftar: email + password, lalu kode 6 angka dari email. Username dipilih
/// setelahnya di layar "kenalan dulu".
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.verifyEmail});

  final String? verifyEmail;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  late String? _sentTo = widget.verifyEmail;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
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

  Future<void> _signUp() async {
    final email = normalizeEmail(_email.text);
    if (!emailPattern.hasMatch(email)) {
      setState(() => _error = 'emailnya belum benar.');
      return;
    }
    if (_password.text.length < passwordMinLength) {
      setState(() => _error = 'password minimal $passwordMinLength karakter.');
      return;
    }
    await _run(() async {
      final result = await _auth.signUp(email: email, password: _password.text);
      if (!mounted) return;
      switch (result) {
        case SignUpResult.codeSent:
          setState(() => _sentTo = email);
        case SignUpResult.alreadyRegistered:
          setState(
            () => _error = 'email ini udah terdaftar. masuk aja, atau pakai lupa password.',
          );
      }
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (!otpPattern.hasMatch(code)) {
      setState(() => _error = 'kodenya 6 angka.');
      return;
    }
    // Setelah berhasil, router pindah ke layar username lewat status sesi.
    await _run(() => _auth.verifySignUp(email: _sentTo!, code: code));
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    final methods = ref.watch(enabledAuthMethodsProvider);

    if (sentTo != null) {
      return AuthScaffold(
        title: 'cek email lo',
        subtitle: 'kode 6 angka udah dikirim ke $sentTo',
        children: [
          CodeField(
            key: const Key('register-code'),
            controller: _code,
            onSubmitted: _verify,
          ),
          const SizedBox(height: 16),
          BusyButton(label: 'verifikasi', busy: _busy, onPressed: _verify),
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
                    : () => _run(() => _auth.resendSignUpCode(sentTo)),
                child: const Text('kirim ulang'),
              ),
            ],
          ),
        ],
      );
    }

    return AuthScaffold(
      title: 'daftar',
      subtitle: 'bikin akun, terus kumpulin hewan bareng circle lo.',
      children: [
        if (methods.contains(AuthMethod.google))
          GoogleButton(
            label: 'daftar dengan google',
            onPressed: _busy ? null : () => _run(_auth.signInWithGoogle),
          ),
        TextField(
          key: const Key('register-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'email'),
        ),
        const SizedBox(height: 16),
        PasswordField(
          key: const Key('register-password'),
          controller: _password,
          newPassword: true,
          helperText: 'minimal $passwordMinLength karakter',
          onSubmitted: _signUp,
        ),
        const SizedBox(height: 16),
        BusyButton(
          key: const Key('register-submit'),
          label: 'daftar',
          busy: _busy,
          onPressed: _signUp,
        ),
        ErrorText(_error),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('udah punya akun?'),
            TextButton(
              onPressed: _busy ? null : () => context.go(Routes.login),
              child: const Text('masuk'),
            ),
          ],
        ),
      ],
    );
  }
}
