import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/app_settings.dart';
import '../data/captured_photos.dart';
import '../data/catch_camera.dart';
import '../state/camera_providers.dart';

/// Warna layar kamera gelap (prototype "Kamera").
class _Dark {
  static const background = Color(0xFF0E0E0E);
  static const control = Color(0xFF222222);
  static const viewfinder = Color(0xFF262626);
  static const muted = Color(0xFFB0B0B0);
  static const faint = Color(0xFF8A8A8A);
  static const outline = Color(0xFF3A3A3A);
}

class _Step {
  const _Step({required this.label, required this.hint, required this.lens});

  final String label;
  final String hint;
  final CameraLens lens;
}

const _steps = [
  _Step(
    label: '1/2 · foto hewan',
    hint: 'arahin ke hewan, pastiin keliatan jelas',
    lens: CameraLens.back,
  ),
  _Step(
    label: '2/2 · foto lo',
    hint: 'sekarang foto reaksi lo',
    lens: CameraLens.front,
  ),
];

/// Kamera catch 2 langkah: foto hewan, lalu foto lo. Tanpa akses galeri.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  late final CatchCamera _camera = ref.read(catchCameraFactoryProvider)();
  int _step = 0;
  CameraLens _lens = _steps.first.lens;
  Uint8List? _animalPhoto;
  bool _ready = false;
  bool _busy = false;
  bool _permissionDenied = false;
  bool _failed = false;
  bool _flashAuto = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open(_lens);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lepas kamera saat app ke background; buka lagi saat kembali
    // (termasuk setelah user mengizinkan kamera di pengaturan).
    // Dialog izin juga memicu inactive, jadi jangan ganggu kamera yang
    // sedang dibuka.
    if (state == AppLifecycleState.inactive && _ready) {
      setState(() => _ready = false);
      _camera.dispose();
    } else if (state == AppLifecycleState.resumed && !_ready && !_busy) {
      _open(_lens);
    }
  }

  Future<void> _open(CameraLens lens) async {
    setState(() {
      _ready = false;
      _busy = true;
      _lens = lens;
    });
    try {
      await _camera.open(lens);
      await _camera.setFlashAuto(_flashAuto);
      if (!mounted) return;
      setState(() {
        _ready = true;
        _permissionDenied = false;
        _failed = false;
      });
    } on CameraPermissionDenied {
      if (mounted) setState(() => _permissionDenied = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _flip() =>
      _open(_lens == CameraLens.back ? CameraLens.front : CameraLens.back);

  void _toggleFlash() {
    setState(() => _flashAuto = !_flashAuto);
    _camera.setFlashAuto(_flashAuto);
  }

  Future<void> _shoot() async {
    if (!_ready || _busy) return;
    setState(() => _busy = true);
    try {
      final photo = await _camera.takePicture();
      if (!mounted) return;
      if (_step == 0) {
        setState(() {
          _animalPhoto = photo;
          _step = 1;
        });
        await _open(_steps[1].lens);
      } else {
        context.pushReplacement(
          Routes.catchResult,
          extra: CapturedPhotos(animal: _animalPhoto!, selfie: photo),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _Dark.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: _permissionDenied
                ? _PermissionDenied(
                    onClose: () => context.pop(),
                    onOpenSettings: () => ref.read(openAppSettingsProvider)(),
                    onRetry: () => _open(_lens),
                  )
                : Column(
                    children: [
                      _TopBar(
                        label: step.label,
                        onClose: () => context.pop(),
                        onFlip: _busy ? null : _flip,
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _buildViewfinder(step)),
                      const SizedBox(height: 16),
                      _BottomBar(
                        flashAuto: _flashAuto,
                        onShoot: _ready && !_busy ? _shoot : null,
                        onFlash: _toggleFlash,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'REAL-TIME ONLY · NO FILTER',
                        style: FurrealText.mono(fontSize: 11)
                            .copyWith(color: _Dark.faint, letterSpacing: 0.5),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewfinder(_Step step) {
    final animalPhoto = _animalPhoto;
    return ClipRRect(
      borderRadius: BorderRadius.circular(FurrealShape.cardRadius),
      child: ColoredBox(
        color: _Dark.viewfinder,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready) _camera.buildPreview(),
            if (_failed)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'kamera gagal dibuka.',
                      style: TextStyle(color: _Dark.muted),
                    ),
                    TextButton(
                      onPressed: () => _open(_lens),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('coba lagi'),
                    ),
                  ],
                ),
              )
            else if (!_ready)
              const Center(
                child: CircularProgressIndicator(color: FurrealColors.accent),
              ),
            const IgnorePointer(
              child: Padding(
                padding: EdgeInsets.fromLTRB(52, 160, 52, 110),
                child: CustomPaint(painter: _CornersPainter()),
              ),
            ),
            if (_step == 1 && animalPhoto != null)
              Positioned(
                top: 16,
                left: 16,
                width: 96,
                height: 128,
                child: Container(
                  key: const Key('animal-thumbnail'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(animalPhoto, fit: BoxFit.cover),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: FurrealColors.ink,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _Dark.outline),
                  ),
                  child: Text(
                    step.hint,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(FurrealShape.minTouchTarget),
        backgroundColor: _Dark.control,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _Dark.control,
        disabledForegroundColor: _Dark.faint,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.label,
    required this.onClose,
    required this.onFlip,
  });

  final String label;
  final VoidCallback onClose;
  final VoidCallback? onFlip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundButton(
          icon: Icons.close,
          tooltip: 'tutup kamera',
          onPressed: onClose,
        ),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FurrealColors.accent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label, style: FurrealText.mono(fontSize: 14)),
        ),
        _RoundButton(
          icon: Icons.cameraswitch_outlined,
          tooltip: 'ganti kamera',
          onPressed: onFlip,
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.flashAuto,
    required this.onShoot,
    required this.onFlash,
  });

  final bool flashAuto;
  final VoidCallback? onShoot;
  final VoidCallback onFlash;

  @override
  Widget build(BuildContext context) {
    final caption = FurrealText.mono(fontSize: 11).copyWith(color: _Dark.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 64,
            child: Column(
              children: [
                const Icon(
                  Icons.hide_image_outlined,
                  color: _Dark.muted,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text('galeri off', style: caption),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'ambil foto',
            child: GestureDetector(
              key: const Key('shutter'),
              onTap: onShoot,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onShoot == null ? _Dark.faint : FurrealColors.accent,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: InkResponse(
              onTap: onFlash,
              child: Semantics(
                button: true,
                label: 'flash',
                child: Column(
                  children: [
                    Icon(
                      flashAuto ? Icons.flash_auto : Icons.flash_off,
                      color: _Dark.muted,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(flashAuto ? 'auto' : 'off', style: caption),
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

class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied({
    required this.onClose,
    required this.onOpenSettings,
    required this.onRetry,
  });

  final VoidCallback onClose;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _RoundButton(
            icon: Icons.close,
            tooltip: 'tutup kamera',
            onPressed: onClose,
          ),
        ),
        const Spacer(),
        const Icon(Icons.no_photography_outlined, color: _Dark.muted, size: 48),
        const SizedBox(height: 16),
        Text(
          'butuh izin kamera',
          textAlign: TextAlign.center,
          style: FurrealText.display(fontSize: 28)
              .copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          'catch cuma bisa dari kamera langsung, galeri dikunci. '
          'izinkan kamera di pengaturan, lalu balik ke sini.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _Dark.muted, height: 1.4),
        ),
        const Spacer(),
        FilledButton(
          onPressed: onOpenSettings,
          child: const Text('buka pengaturan'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('coba lagi'),
        ),
      ],
    );
  }
}

/// Sudut bidik warna aksen di viewfinder.
class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const len = 30.0;
    const r = 10.0;
    final paint = Paint()
      ..color = FurrealColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    void corner(Offset o, double dx, double dy) {
      final path = Path()
        ..moveTo(o.dx, o.dy + dy * len)
        ..lineTo(o.dx, o.dy + dy * r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx + dx * r, o.dy)
        ..lineTo(o.dx + dx * len, o.dy);
      canvas.drawPath(path, paint);
    }

    corner(Offset.zero, 1, 1);
    corner(Offset(size.width, 0), -1, 1);
    corner(Offset(0, size.height), 1, -1);
    corner(Offset(size.width, size.height), -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
