import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/error_text.dart';
import '../data/feedback_repository.dart';
import '../state/account_providers.dart';

/// Kirim saran fitur atau laporan bug (dibaca tim di dashboard Supabase).
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _message = TextEditingController();
  FeedbackCategory _category = FeedbackCategory.feature;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _message.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'tulis dulu saran atau masalahnya.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(feedbackRepositoryProvider).submit(_category, message);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('makasih! masukan lo udah terkirim.')),
      );
      context.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'gagal mengirim. cek koneksi lalu coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('kirim saran')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const Text(
              'punya ide fitur atau nemu yang aneh? ceritain aja, '
              'kami baca semuanya.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                for (final c in FeedbackCategory.values)
                  ChoiceChip(
                    key: Key('feedback-${c.dbValue}'),
                    label: Text(c.label),
                    selected: _category == c,
                    selectedColor: FurrealColors.accent,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('feedback-message'),
              controller: _message,
              maxLength: feedbackMaxLength,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: _category == FeedbackCategory.feature
                    ? 'mis. pengen bisa lihat koleksi teman'
                    : 'mis. kamera hitam pas buka dari notifikasi. '
                          'HP: …, langkahnya: …',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            BusyButton(
              key: const Key('feedback-send'),
              label: 'kirim',
              busy: _busy,
              onPressed: _send,
            ),
            ErrorText(_error),
          ],
        ),
      ),
    );
  }
}
