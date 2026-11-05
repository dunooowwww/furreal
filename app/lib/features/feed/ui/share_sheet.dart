import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../data/catch_share.dart';
import '../data/feed_models.dart';
import '../state/feed_providers.dart';

/// Simpan / bagikan gambar catch sendiri (foto + selfie + watermark).
Future<void> showShareSheet(BuildContext context, FeedItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ShareSheet(item: item),
  );
}

class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({super.key, required this.item});

  final FeedItem item;

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  Future<Uint8List>? _image;
  bool _busy = false;

  /// Hasil terakhir, ditampilkan di sheet (snackbar akan menutupi tombol).
  String? _status;

  @override
  void initState() {
    super.initState();
    _image = _compose();
  }

  Future<Uint8List> _compose() async {
    final item = widget.item;
    final repo = ref.read(feedRepositoryProvider);
    final photos = await Future.wait([
      repo.downloadPhoto(item.animalPhotoPath!),
      repo.downloadPhoto(item.selfiePhotoPath!),
    ]);
    return ref.read(shareImageComposerProvider)(
      animalPhoto: photos[0],
      selfiePhoto: photos[1],
      animalName: item.animalName ?? 'tanpa nama',
      caption: item.caption,
      date: item.createdAt,
    );
  }

  String get _fileName =>
      'furreal-${(widget.item.animalName ?? 'catch').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';

  Future<void> _run(
    Future<void> Function(Uint8List png) action, {
    String? success,
    required String failure,
  }) async {
    final image = await _image;
    if (image == null || !mounted) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action(image);
      if (mounted && success != null) setState(() => _status = success);
    } catch (_) {
      if (mounted) setState(() => _status = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharer = ref.watch(catchSharerProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: FutureBuilder<Uint8List>(
        future: _image,
        builder: (context, snapshot) {
          final image = snapshot.data;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'simpan / bagikan',
                style: FurrealText.display(fontSize: 22),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: AspectRatio(
                  aspectRatio: shareImageSize.aspectRatio,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: switch (snapshot) {
                      AsyncSnapshot(hasError: true) => const ColoredBox(
                        color: FurrealColors.surface,
                        child: Center(
                          child: Text('gambar gagal dibuat. coba lagi ya.'),
                        ),
                      ),
                      _ when image != null => Image.memory(
                        image,
                        key: const Key('share-preview'),
                        fit: BoxFit.cover,
                      ),
                      _ => const ColoredBox(
                        color: FurrealColors.surface,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('share-save'),
                      onPressed: image == null || _busy
                          ? null
                          : () => _run(
                              (png) =>
                                  sharer.saveToGallery(png, name: _fileName),
                              success: 'tersimpan di galeri (album furreal).',
                              failure: 'gagal menyimpan. izinin akses galeri dulu ya.',
                            ),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('simpan'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('share-send'),
                      onPressed: image == null || _busy
                          ? null
                          : () => _run(
                              (png) => sharer.share(
                                png,
                                name: _fileName,
                                text: 'catch hari ini di furreal',
                              ),
                              failure: 'gagal membagikan. coba lagi ya.',
                            ),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('bagikan'),
                    ),
                  ),
                ],
              ),
              if (_status != null) ...[
                const SizedBox(height: 10),
                Text(
                  _status!,
                  key: const Key('share-status'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: FurrealColors.textSecondary),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
