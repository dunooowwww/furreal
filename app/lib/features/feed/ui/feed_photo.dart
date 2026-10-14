import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Menampilkan foto feed dari signed URL. [cacheKey] = path storage, supaya
/// cache tetap kena walau signed URL berganti tiap refresh.
typedef FeedPhotoBuilder = Widget Function(
  BuildContext context,
  String? url,
  String cacheKey,
);

Widget cachedFeedPhoto(BuildContext context, String? url, String cacheKey) {
  if (url == null) return const FeedPhotoPlaceholder(failed: true);
  return CachedNetworkImage(
    imageUrl: url,
    cacheKey: cacheKey,
    fit: BoxFit.cover,
    fadeInDuration: const Duration(milliseconds: 150),
    placeholder: (_, _) => const FeedPhotoPlaceholder(),
    errorWidget: (_, _, _) => const FeedPhotoPlaceholder(failed: true),
  );
}

class FeedPhotoPlaceholder extends StatelessWidget {
  const FeedPhotoPlaceholder({super.key, this.failed = false});

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
