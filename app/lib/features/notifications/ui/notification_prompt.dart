import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/app_settings.dart';
import '../data/push_messaging.dart';
import '../state/notification_providers.dart';

/// Kartu izin notifikasi di beranda (setelah onboarding): penjelasan dulu,
/// baru dialog sistem. Hilang kalau izin sudah ada atau Firebase tidak aktif.
class NotificationPrompt extends ConsumerStatefulWidget {
  const NotificationPrompt({super.key});

  @override
  ConsumerState<NotificationPrompt> createState() => _NotificationPromptState();
}

class _NotificationPromptState extends ConsumerState<NotificationPrompt> {
  bool _asking = false;

  /// Sudah minta tapi tetap ditolak: Android tidak menampilkan dialog lagi,
  /// jadi arahkan ke pengaturan.
  bool _askedAndDenied = false;

  Future<void> _enable() async {
    if (_askedAndDenied) {
      await ref.read(openAppSettingsProvider)();
      return;
    }
    setState(() => _asking = true);
    try {
      final result = await ref.read(pushMessagingProvider).requestPermission();
      if (!mounted) return;
      if (result == PushPermission.denied) {
        setState(() => _askedAndDenied = true);
      }
      ref.invalidate(pushPermissionProvider);
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(pushPermissionProvider).value;
    final dismissed = ref.watch(notificationPromptDismissedProvider);
    if (permission != PushPermission.denied || dismissed) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        key: const Key('notification-prompt'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: FurrealColors.ink,
            width: FurrealShape.borderWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_none, size: 20),
                const SizedBox(width: 8),
                Text(
                  'NOTIFIKASI',
                  style: FurrealText.mono(fontSize: 12)
                      .copyWith(letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _askedAndDenied
                  ? 'notifikasinya masih mati. nyalain lewat pengaturan biar '
                        'nggak ketinggalan daily drop.'
                  : 'nyalain notifikasi biar lo tau kapan daily drop turun. '
                        'cuma sekali sehari, janji.',
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _asking ? null : _enable,
                    style: FilledButton.styleFrom(
                      backgroundColor: FurrealColors.ink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(
                        FurrealShape.minTouchTarget,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      _askedAndDenied
                          ? 'buka pengaturan'
                          : 'nyalain notifikasi',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => ref
                      .read(notificationPromptDismissedProvider.notifier)
                      .dismiss(),
                  child: const Text('nanti aja'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
