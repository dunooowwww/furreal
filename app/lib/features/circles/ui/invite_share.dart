import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config.dart';
import '../../../shared/errors.dart';
import '../../feed/state/feed_providers.dart';
import '../data/circle_repository.dart';

/// Pesan undangan circle (M13). [link] = link unduh app, opsional.
String inviteMessage(Circle circle, {String link = AppConfig.inviteLink}) {
  final lines = [
    'gabung circle "${circle.name}" di furreal yuk! '
        'tiap hari kita adu foto hewan pertama yang ketemu 🐾',
    'kode undangan: ${circle.inviteCode}',
    '(buka furreal → buat / gabung circle → masukin kodenya)',
    if (link.trim().isNotEmpty) 'download app: ${link.trim()}',
  ];
  return lines.join('\n');
}

/// Tombol "ajak teman": bagikan kode undangan lewat menu share Android.
class InviteShareButton extends ConsumerWidget {
  const InviteShareButton({
    super.key,
    required this.circle,
    this.filled = false,
  });

  final Circle circle;
  final bool filled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> share() async {
      try {
        await ref.read(catchSharerProvider).shareText(inviteMessage(circle));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      }
    }

    const icon = Icon(Icons.person_add_alt_1_outlined, size: 20);
    const label = Text('ajak teman');
    final key = Key('invite-${circle.id}');
    return filled
        ? FilledButton.icon(
            key: key,
            onPressed: share,
            icon: icon,
            label: label,
          )
        : OutlinedButton.icon(
            key: key,
            onPressed: share,
            icon: icon,
            label: label,
          );
  }
}
