import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/errors.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/error_text.dart';
import '../state/auth_providers.dart';

/// Pedoman kesejahteraan hewan (PRD §8): onboarding, sekali per akun,
/// setelah pilih username dan sebelum circle.
class GuidelinesScreen extends ConsumerStatefulWidget {
  const GuidelinesScreen({super.key});

  static const rules = [
    (
      icon: Icons.directions_run,
      title: 'jangan dikejar',
      body: 'foto dari tempat lo berdiri. kalau hewannya kabur, biarin aja.',
    ),
    (
      icon: Icons.back_hand_outlined,
      title: 'jangan dipegang atau digendong',
      body:
          'apalagi hewan liar. bisa bikin mereka stres, lo juga bisa digigit.',
    ),
    (
      icon: Icons.flash_off,
      title: 'jangan dipancing atau diganggu',
      body:
          'nggak usah kasih makan, bikin suara, atau nyalain flash cuma demi '
          'foto. hewan yang lagi tidur, makan, atau ngurus anak: lewatin.',
    ),
    (
      icon: Icons.pets,
      title: 'hormati pemiliknya',
      body: 'peliharaan orang? minta izin dulu sebelum motret.',
    ),
  ];

  @override
  ConsumerState<GuidelinesScreen> createState() => _GuidelinesScreenState();
}

class _GuidelinesScreenState extends ConsumerState<GuidelinesScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).acceptGuidelines();
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
            Text('sebelum mulai catch', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'furreal itu soal ketemu hewan, bukan ngerepotin mereka. '
              'janji dulu ya:',
            ),
            const SizedBox(height: 24),
            for (final rule in GuidelinesScreen.rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: FurrealColors.ink,
                      width: FurrealShape.borderWidth,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(rule.icon, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rule.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rule.body,
                              style: const TextStyle(
                                color: FurrealColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            BusyButton(label: 'gue janji', busy: _busy, onPressed: _accept),
            ErrorText(_error),
          ],
        ),
      ),
    );
  }
}
