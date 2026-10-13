import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/errors.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/error_text.dart';
import '../data/circle_repository.dart';
import '../state/circle_providers.dart';

/// Buat circle baru atau gabung lewat kode undangan.
class CircleScreen extends ConsumerStatefulWidget {
  const CircleScreen({super.key});

  @override
  ConsumerState<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends ConsumerState<CircleScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _createError;
  String? _joinError;
  Circle? _created;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _createError = 'kasih nama dulu circle-nya.');
      return;
    }
    setState(() {
      _busy = true;
      _createError = null;
      _joinError = null;
    });
    try {
      final circle = await ref
          .read(circleRepositoryProvider)
          .createCircle(name);
      ref.invalidate(myCirclesProvider);
      if (mounted) setState(() => _created = circle);
    } catch (e) {
      if (mounted) setState(() => _createError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length != inviteCodeLength) {
      setState(() => _joinError = 'kode undangan 6 karakter.');
      return;
    }
    setState(() {
      _busy = true;
      _createError = null;
      _joinError = null;
    });
    try {
      await ref.read(circleRepositoryProvider).joinCircle(code);
      ref.invalidate(myCirclesProvider);
      if (mounted) context.go(Routes.home);
    } catch (e) {
      if (mounted) setState(() => _joinError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    return Scaffold(
      appBar: context.canPop() ? AppBar() : null,
      body: SafeArea(
        child: created == null ? _buildForms(context) : _buildCreated(created),
      ),
    );
  }

  Widget _buildForms(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Text('circle-mu', style: textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'catch dibagikan ke teman satu circle. buat baru atau gabung.',
        ),
        const SizedBox(height: 24),
        _Section(
          title: 'buat circle baru',
          children: [
            TextField(
              key: const Key('circle-name'),
              controller: _name,
              maxLength: circleNameMaxLength,
              decoration: const InputDecoration(labelText: 'nama circle'),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 8),
            BusyButton(label: 'buat circle', busy: _busy, onPressed: _create),
            ErrorText(_createError),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'gabung circle',
          children: [
            TextField(
              key: const Key('invite-code'),
              controller: _code,
              maxLength: inviteCodeLength,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              ],
              style: FurrealText.mono(fontSize: 20),
              decoration: const InputDecoration(labelText: 'kode undangan'),
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 8),
            BusyButton(label: 'gabung', busy: _busy, onPressed: _join),
            ErrorText(_joinError),
          ],
        ),
      ],
    );
  }

  Widget _buildCreated(Circle circle) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Text(
          'circle "${circle.name}" siap!',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('bagikan kode ini ke temanmu supaya mereka bisa gabung.'),
        const SizedBox(height: 24),
        Card(
          color: FurrealColors.accent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: SelectableText(
                circle.inviteCode,
                key: const Key('created-invite-code'),
                style: FurrealText.mono(
                  fontSize: 40,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: circle.inviteCode)),
          child: const Text('salin kode'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => context.go(Routes.home),
          child: const Text('lanjut'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
