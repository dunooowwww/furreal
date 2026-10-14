import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/privacy_policy.dart';

/// Kebijakan privasi, bisa dibuka sebelum login (dari layar login) maupun
/// dari layar akun.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('kebijakan privasi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              'BERLAKU SEJAK ${privacyPolicyUpdated.toUpperCase()}',
              style: FurrealText.mono(fontSize: 12).copyWith(
                color: FurrealColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            for (final section in privacyPolicy) ...[
              const SizedBox(height: 24),
              Text(section.title, style: textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final paragraph in section.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(paragraph, style: const TextStyle(height: 1.5)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
