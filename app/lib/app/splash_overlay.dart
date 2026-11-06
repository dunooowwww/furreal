import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme.dart';

/// Lama animasi splash saat app dibuka (nol di test).
final splashDurationProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 1500),
);

/// Splash animasi di atas app saat dibuka (sekali per cold start): tapak kaki
/// memantul masuk, jejak kecil berjalan, lalu logo & tagline. Router tetap
/// jalan di bawahnya (notifikasi yang diketuk langsung ke tujuan), lalu
/// lapisan ini memudar. Latarnya sama dengan splash native supaya mulus.
class SplashOverlay extends ConsumerStatefulWidget {
  const SplashOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends ConsumerState<SplashOverlay>
    with TickerProviderStateMixin {
  late final Duration _duration = ref.read(splashDurationProvider);
  late final _intro = AnimationController(vsync: this, duration: _duration);
  late final _fade = AnimationController(
    vsync: this,
    duration: _duration == Duration.zero
        ? Duration.zero
        : const Duration(milliseconds: 300),
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _intro.forward().whenComplete(() {
      if (!mounted) return;
      _fade.forward().whenComplete(() {
        if (mounted) setState(() => _done = true);
      });
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _fade.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end, [Curve? curve]) =>
      CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: curve ?? Curves.easeOutCubic),
      );

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    final paw = _interval(0, 0.45, Curves.elasticOut);
    final title = _interval(0.35, 0.7);
    final tagline = _interval(0.55, 0.85);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        FadeTransition(
          opacity: ReverseAnimation(_fade),
          child: Material(
            key: const Key('splash-overlay'),
            color: FurrealColors.accent,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: paw,
                    child: const Icon(
                      Icons.pets,
                      size: 72,
                      color: FurrealColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Footprints(progress: _interval(0.15, 0.6, Curves.linear)),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: title,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(title),
                      child: Text(
                        'furreal',
                        style: FurrealText.display(fontSize: 44),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FadeTransition(
                    opacity: tagline,
                    child: Text(
                      'koleksi hewan harian bareng circle lo',
                      style: FurrealText.mono(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Empat jejak kecil yang muncul bergantian (kiri-kanan) seperti berjalan.
class _Footprints extends StatelessWidget {
  const _Footprints({required this.progress});

  final Animation<double> progress;

  static const _count = 4;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _count; i++)
            Padding(
              padding: EdgeInsets.only(
                left: 6,
                right: 6,
                top: i.isEven ? 0 : 10,
                bottom: i.isEven ? 10 : 0,
              ),
              child: Opacity(
                opacity: ((progress.value * _count) - i).clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: 1.57,
                  child: const Icon(
                    Icons.pets,
                    size: 14,
                    color: FurrealColors.ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
