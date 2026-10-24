import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';

/// Kerangka layar masuk/daftar/lupa password.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: context.canPop() ? AppBar() : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SizedBox(height: context.canPop() ? 8 : 48),
            Text(title, style: FurrealText.display(fontSize: 44)),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 32),
            ...children,
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => context.push(Routes.privacy),
                child: const Text('kebijakan privasi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'password',
    this.helperText,
    this.newPassword = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;

  /// Password baru (daftar/reset): petunjuk autofill berbeda.
  final bool newPassword;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        suffixIcon: IconButton(
          tooltip: _visible ? 'sembunyikan password' : 'lihat password',
          onPressed: () => setState(() => _visible = !_visible),
          icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
        ),
      ),
      onSubmitted: (_) => widget.onSubmitted?.call(),
    );
  }
}

/// Kode 6 angka dari email.
class CodeField extends StatelessWidget {
  const CodeField({super.key, required this.controller, this.onSubmitted});

  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 6,
      style: FurrealText.mono(fontSize: 24),
      decoration: const InputDecoration(labelText: 'kode', counterText: ''),
      onSubmitted: (_) => onSubmitted?.call(),
    );
  }
}

class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('google-sign-in'),
          onPressed: onPressed,
          icon: Text('G', style: FurrealText.display(fontSize: 18)),
          label: Text(label),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('atau'),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
