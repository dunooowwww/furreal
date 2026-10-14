import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';

/// Menampilkan foto catch dari signed URL (feed, koleksi, beranda). [cacheKey] = path storage, supaya
/// cache tetap kena walau signed URL berganti tiap refresh.
typedef RemotePhotoBuilder = Widget Function(
  BuildContext context,
  String? url,
  String cacheKey,
);

Widget cachedRemotePhoto(BuildContext context, String? url, String cacheKey) {
  if (url == null) return const RemotePhotoPlaceholder(failed: true);
  return CachedNetworkImage(
    imageUrl: url,
    cacheKey: cacheKey,
    fit: BoxFit.cover,
    fadeInDuration: const Duration(milliseconds: 150),
    placeholder: (_, _) => const RemotePhotoPlaceholder(),
    errorWidget: (_, _, _) => const RemotePhotoPlaceholder(failed: true),
  );
}

class RemotePhotoPlaceholder extends StatelessWidget {
  const RemotePhotoPlaceholder({super.key, this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FurrealColors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed ? Icons.broken_image_outlined : Icons.pets,
              color: FurrealColors.textSecondary,
            ),
            if (failed) ...[
              const SizedBox(height: 4),
              Text(
                'foto gagal dimuat',
                style: FurrealText.mono(fontSize: 11)
                    .copyWith(color: FurrealColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cara menampilkan foto. Default: cached_network_image; diganti di test.
final remotePhotoBuilderProvider = Provider<RemotePhotoBuilder>(
  (ref) => cachedRemotePhoto,
);
