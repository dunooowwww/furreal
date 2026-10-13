import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../auth/state/auth_providers.dart';
import '../../circles/state/circle_providers.dart';

/// Beranda sementara untuk M1: sapaan, daftar circle, keluar.
/// Isi beranda lengkap (daily drop, streak) di milestone berikutnya.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final circles = ref.watch(myCirclesProvider).value ?? const [];
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('furreal', style: FurrealText.display(fontSize: 32)),
            const SizedBox(height: 24),
            Text(
              'halo, ${profile?.displayName ?? profile?.username ?? ''}',
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'daily drop segera hadir.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text('circle kamu', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final circle in circles)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    title: Text(circle.name),
                    trailing: Text(
                      circle.inviteCode,
                      style: FurrealText.mono(fontSize: 16),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.push(Routes.circle),
              child: const Text('buat / gabung circle lain'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('keluar'),
            ),
          ],
        ),
      ),
    );
  }
}
