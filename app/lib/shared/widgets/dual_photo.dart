import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'remote_photo.dart';

/// Satu foto catch: signed URL + path storage (kunci cache).
class PhotoRef {
  const PhotoRef({required this.url, required this.path});

  final String? url;
  final String path;
}

/// Foto hewan besar + selfie kecil di pojok (ala BeReal). Tap foto kecil =
/// tukar posisi; tahan foto besar = layar penuh yang bisa di-zoom.
class DualPhoto extends ConsumerStatefulWidget {
  const DualPhoto({
    super.key,
    required this.id,
    required this.main,
    required this.inset,
    this.height = 280,
  });

  /// Untuk key widget (`photo-main-<id>`, `photo-inset-<id>`).
  final String id;
  final PhotoRef main;
  final PhotoRef inset;
  final double height;

  @override
  ConsumerState<DualPhoto> createState() => _DualPhotoState();
}

class _DualPhotoState extends ConsumerState<DualPhoto> {
  bool _swapped = false;

  PhotoRef get _big => _swapped ? widget.inset : widget.main;
  PhotoRef get _small => _swapped ? widget.main : widget.inset;

  void _swap() {
    HapticFeedback.selectionClick();
    setState(() => _swapped = !_swapped);
  }

  @override
  Widget build(BuildContext context) {
    final photo = ref.watch(remotePhotoBuilderProvider);
    Widget fade(PhotoRef p) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(
        key: ValueKey(p.path),
        child: SizedBox.expand(child: photo(context, p.url, p.path)),
      ),
    );
    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: Key('photo-main-${widget.id}'),
            onLongPress: () {
              HapticFeedback.mediumImpact();
              showPhotoViewer(context, main: _big, inset: _small);
            },
            child: fade(_big),
          ),
          Positioned(
            top: 12,
            left: 12,
            width: 56,
            height: 74,
            child: GestureDetector(
              key: Key('photo-inset-${widget.id}'),
              onTap: _swap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: fade(_small),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Layar penuh hitam: cubit untuk zoom, tap foto kecil untuk tukar.
Future<void> showPhotoViewer(
  BuildContext context, {
  required PhotoRef main,
  required PhotoRef inset,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => PhotoViewer(main: main, inset: inset),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class PhotoViewer extends ConsumerStatefulWidget {
  const PhotoViewer({super.key, required this.main, required this.inset});

  final PhotoRef main;
  final PhotoRef inset;

  @override
  ConsumerState<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<PhotoViewer> {
  final _zoom = TransformationController();
  bool _swapped = false;

  PhotoRef get _big => _swapped ? widget.inset : widget.main;
  PhotoRef get _small => _swapped ? widget.main : widget.inset;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final full = ref.watch(remoteFullPhotoBuilderProvider);
    final thumb = ref.watch(remotePhotoBuilderProvider);
    return Scaffold(
      key: const Key('photo-viewer'),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            transformationController: _zoom,
            minScale: 1,
            maxScale: 4,
            child: KeyedSubtree(
              key: Key('viewer-main-${_big.path}'),
              child: full(context, _big.url, _big.path),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton.filled(
                      key: const Key('viewer-close'),
                      tooltip: 'tutup',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      key: const Key('viewer-inset'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _swapped = !_swapped;
                          _zoom.value = Matrix4.identity();
                        });
                      },
                      child: Container(
                        width: 72,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: thumb(context, _small.url, _small.path),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
