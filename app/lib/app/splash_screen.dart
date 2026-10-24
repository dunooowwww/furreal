import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/state/auth_providers.dart';
import '../features/circles/state/circle_providers.dart';
import 'session.dart';
import 'theme.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionStatusProvider);

    // Sama dengan splash native (latar aksen + tapak) supaya transisinya mulus.
    return Scaffold(
      key: const Key('splash'),
      backgroundColor: FurrealColors.accent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pets, size: 72, color: FurrealColors.ink),
                const SizedBox(height: 12),
                Text('furreal', style: FurrealText.display(fontSize: 44)),
                const SizedBox(height: 4),
                Text(
                  'koleksi hewan harian bareng circle lo',
                  style: FurrealText.mono(fontSize: 12),
                ),
                const SizedBox(height: 24),
                if (session.hasError) ...[
                  const Text(
                    'gagal memuat. cek koneksi lalu coba lagi.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: FurrealColors.ink,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      ref.invalidate(myProfileProvider);
                      ref.invalidate(myCirclesProvider);
                      ref.invalidate(sessionStatusProvider);
                    },
                    child: const Text('coba lagi'),
                  ),
                ] else
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: FurrealColors.ink,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
