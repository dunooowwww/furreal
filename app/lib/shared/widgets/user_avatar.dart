import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../features/auth/state/auth_providers.dart';
import 'remote_photo.dart';

/// Foto profil bulat; tanpa foto (atau gagal dimuat) tampil inisial nama.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.avatarPath,
    this.size = 36,
  });

  final String name;
  final String? avatarPath;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = avatarPath;
    final url = path == null ? null : ref.watch(avatarUrlProvider(path)).value;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: FurrealColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: FurrealColors.ink,
          width: FurrealShape.borderWidth,
        ),
      ),
      child: path != null && url != null
          ? SizedBox.expand(
              child: ref.watch(remotePhotoBuilderProvider)(context, url, path),
            )
          : Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: size * 0.4,
              ),
            ),
    );
  }
}
