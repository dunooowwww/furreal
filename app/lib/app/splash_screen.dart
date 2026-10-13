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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('furreal', style: FurrealText.display(fontSize: 40)),
                const SizedBox(height: 16),
                if (session.hasError) ...[
                  const Text(
                    'gagal memuat. cek koneksi lalu coba lagi.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(myProfileProvider);
                      ref.invalidate(myCirclesProvider);
                      ref.invalidate(sessionStatusProvider);
                    },
                    child: const Text('coba lagi'),
                  ),
                ] else
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
