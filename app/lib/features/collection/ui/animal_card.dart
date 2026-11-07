import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/remote_photo.dart';
import '../../catch_result/data/catch_repository.dart' show AnimalKind;
import '../data/collection_models.dart';
import 'animal_detail_sheet.dart' show shortDate;

/// Warna pastel kartu per jenis hewan: [light] latar, [mid] bingkai,
/// [deep] aksen (ikon, nomor).
class CardPalette {
  const CardPalette(this.light, this.mid, this.deep);

  final Color light;
  final Color mid;
  final Color deep;
}

const _palettes = <String, CardPalette>{
  'kucing': CardPalette(
    Color(0xFFFFF1D6),
    Color(0xFFF7C77A),
    Color(0xFFD9822B),
  ),
  'anjing': CardPalette(
    Color(0xFFF1EBFF),
    Color(0xFFC9B8F2),
    Color(0xFF7A5CC8),
  ),
  'burung': CardPalette(
    Color(0xFFFFEFE6),
    Color(0xFFF2C2A6),
    Color(0xFFC9714A),
  ),
  'ayam': CardPalette(Color(0xFFFFF6D9), Color(0xFFF2D27A), Color(0xFFB98A12)),
  'bebek': CardPalette(Color(0xFFFFF6D6), Color(0xFFF5D77C), Color(0xFFC79B16)),
  'ikan': CardPalette(Color(0xFFE6F7F6), Color(0xFFA8DCD8), Color(0xFF2E8F8A)),
  'cicak': CardPalette(Color(0xFFFFF0E3), Color(0xFFEFC59E), Color(0xFFB0703A)),
  'kambing': CardPalette(
    Color(0xFFF3EFE6),
    Color(0xFFD6CBB2),
    Color(0xFF8C7A55),
  ),
  'kelinci': CardPalette(
    Color(0xFFF4F8E3),
    Color(0xFFCFE0A0),
    Color(0xFF6E8F2C),
  ),
  'merpati': CardPalette(
    Color(0xFFEDF1FA),
    Color(0xFFBFCBE6),
    Color(0xFF5568A0),
  ),
};

const _fallbackPalettes = [
  CardPalette(Color(0xFFF3ECFF), Color(0xFFCDB9F5), Color(0xFF7552D9)),
  CardPalette(Color(0xFFFFEDF1), Color(0xFFF2B8C6), Color(0xFFC94F6D)),
  CardPalette(Color(0xFFEAF7EE), Color(0xFFAEDDBC), Color(0xFF2F9E5C)),
  CardPalette(Color(0xFFFFF1E2), Color(0xFFF5C99A), Color(0xFFDB7A1F)),
];

/// Jenis dikenal punya warna tetap; jenis lain dipilih stabil dari namanya.
CardPalette paletteFor(String? animalType) {
  final type = animalType?.trim().toLowerCase();
  if (type == null || type.isEmpty) return _fallbackPalettes.first;
  final known = _palettes[type];
  if (known != null) return known;
  final hash = type.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
  return _fallbackPalettes[hash % _fallbackPalettes.length];
}

/// `#0001`.
String cardNumber(int number) => '#${number.toString().padLeft(4, '0')}';

/// Isi satu kartu koleksi.
class AnimalCardData {
  const AnimalCardData({
    required this.name,
    required this.kind,
    required this.encounterCount,
    this.animalType,
    this.personality,
    this.number,
    this.areaLabel,
    this.date,
    this.cutoutPath,
    this.cutoutUrl,
    this.cutoutBytes,
    this.photoPath,
    this.photoUrl,
    this.photoBytes,
  });

  factory AnimalCardData.fromAnimal(CollectionAnimal a, {int? number}) =>
      AnimalCardData(
        name: a.name,
        kind: a.kind,
        encounterCount: a.encounterCount,
        animalType: a.animalType,
        personality: a.lastPersonality,
        number: number,
        areaLabel: a.lastAreaLabel,
        date: a.lastCatchDate ?? a.lastSeenAt,
        cutoutPath: a.lastCutoutPath,
        cutoutUrl: a.lastCutoutUrl,
        photoPath: a.lastPhotoPath,
        photoUrl: a.lastPhotoUrl,
      );

  final String name;
  final AnimalKind kind;
  final int encounterCount;
  final String? animalType;

  /// Kepribadian AI; kalimat pertama jadi tagline (lihat [splitPersonality]).
  final String? personality;

  /// Nomor koleksi (#0001 = hewan pertama).
  final int? number;

  /// Label area catch terakhir; null = lokasi disembunyikan.
  final String? areaLabel;
  final DateTime? date;

  /// Potongan hewan di storage, atau langsung dari HP setelah posting.
  final String? cutoutPath;
  final String? cutoutUrl;
  final Uint8List? cutoutBytes;

  /// Foto biasa (latar kartu, atau gambar utama kalau belum ada potongan).
  final String? photoPath;
  final String? photoUrl;
  final Uint8List? photoBytes;

  bool get hasCutout => cutoutBytes != null || cutoutPath != null;
}

/// Kartu koleksi (desain furreal sendiri, terinspirasi kartu koleksi).
/// [compact] untuk grid: logo, nomor, gambar, nama, jenis. Lengkap: plus
/// tagline, info (jenis · lokasi · tanggal), dan kotak kepribadian.
/// Kalau [interactive], kilau & kemiringan mengikuti jari.
class AnimalCard extends StatelessWidget {
  const AnimalCard({
    super.key,
    required this.data,
    this.compact = false,
    this.interactive = false,
  });

  final AnimalCardData data;
  final bool compact;
  final bool interactive;

  /// Rasio kartu koleksi standar (63 × 88 mm).
  static const aspectRatio = 63 / 88;

  @override
  Widget build(BuildContext context) {
    final card = AspectRatio(
      aspectRatio: aspectRatio,
      child: _CardFace(data: data, compact: compact),
    );
    return HoloCard(interactive: interactive, child: card);
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.data, required this.compact});

  final AnimalCardData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(data.animalType);
    final s = compact ? 0.55 : 1.0; // skala ukuran
    final split = splitPersonality(data.personality);
    final ink = FurrealColors.ink;

    Widget pill({required Widget child, EdgeInsets? padding}) => Container(
      padding:
          padding ?? EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.mid, width: 1.2),
      ),
      child: child,
    );

    final header = Row(
      children: [
        Icon(Icons.pets, size: 20 * s, color: p.deep),
        SizedBox(width: 4 * s),
        Expanded(
          child: Text(
            'Furreal',
            maxLines: 1,
            style: FurrealText.display(fontSize: 22 * s)
                .copyWith(fontWeight: FontWeight.w800, color: ink, height: 1),
          ),
        ),
        if (data.number != null)
          pill(
            padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 3 * s),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cardNumber(data.number!),
                  key: const Key('card-number'),
                  style: FurrealText.mono(fontSize: 12 * s)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 3 * s),
                Icon(Icons.auto_awesome, size: 12 * s, color: p.deep),
              ],
            ),
          ),
      ],
    );

    // Pita nama, menumpang di bawah gambar.
    final nameBanner = Container(
      padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 6 * s),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.mid, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: p.deep.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        data.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: FurrealText.display(fontSize: 24 * s)
            .copyWith(fontWeight: FontWeight.w800, height: 1.1),
      ),
    );

    final art = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          bottom: 14 * s,
          child: _Art(data: data, palette: p, compact: compact),
        ),
        Positioned(left: 10 * s, right: 10 * s, bottom: 0, child: nameBanner),
      ],
    );

    final type = data.animalType ?? 'jenis belum diisi';

    return Container(
      key: const Key('animal-card'),
      padding: EdgeInsets.all(10 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 14 : 22),
        border: Border.all(color: p.mid, width: compact ? 2 : 3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.light, Colors.white, p.light],
          stops: const [0, 0.5, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _SparklePainter(p.mid))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              SizedBox(height: 8 * s),
              // Gambar mengisi sisa tempat; teks di bawah ukurannya tetap.
              Expanded(child: art),
              if (compact) ...[
                SizedBox(height: 5 * s),
                Text(
                  '$type · ketemu ${data.encounterCount}x',
                  key: const Key('card-encounters'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: ink.withValues(alpha: 0.75),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                if (split.tagline != null)
                  Container(
                    key: const Key('card-tagline'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.mid),
                    ),
                    child: Text(
                      split.tagline!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, height: 1.3),
                    ),
                  ),
                const SizedBox(height: 8),
                // Info: jenis · lokasi · tanggal.
                DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 11.5),
                  child: Row(
                    children: [
                      _Info(icon: Icons.pets, text: type, color: p.deep),
                      _Info(
                        icon: Icons.location_on_outlined,
                        text: data.areaLabel ?? 'rahasia',
                        color: p.deep,
                      ),
                      if (data.date != null)
                        _Info(
                          icon: Icons.calendar_today_outlined,
                          text: shortDate(data.date!),
                          color: p.deep,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  key: const Key('card-personality'),
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: p.light.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.mid),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: p.deep),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Kepribadian:',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              split.traits ??
                                  'ketemu ${data.encounterCount}x · ${data.kind.label}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.mid),
                        ),
                        child: Icon(Icons.pets, size: 16, color: p.deep),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _Art extends ConsumerWidget {
  const _Art({
    required this.data,
    required this.palette,
    required this.compact,
  });

  final AnimalCardData data;
  final CardPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoBuilder = ref.watch(remotePhotoBuilderProvider);

    Widget? photo() {
      if (data.photoBytes != null) {
        return Image.memory(data.photoBytes!, fit: BoxFit.cover);
      }
      if (data.photoPath != null) {
        return photoBuilder(context, data.photoUrl, data.photoPath!);
      }
      return null;
    }

    Widget? cutout() {
      if (data.cutoutBytes != null) {
        return Image.memory(data.cutoutBytes!, fit: BoxFit.contain);
      }
      if (data.cutoutPath != null) {
        return ref.watch(remoteCutoutBuilderProvider)(
          context,
          data.cutoutUrl,
          data.cutoutPath!,
        );
      }
      return null;
    }

    final bg = photo();
    final fg = cutout();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 10 : 16),
        border: Border.all(color: Colors.white, width: compact ? 2 : 3),
        color: palette.light,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (fg != null) ...[
            // Latar: foto asli yang diburamkan + pastel, hewan "timbul" di atasnya.
            if (bg != null)
              // Diperbesar sedikit supaya tepi buramnya tidak terlihat.
              Transform.scale(
                scale: 1.2,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: bg,
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.55),
                    palette.light.withValues(alpha: 0.65),
                  ],
                  radius: 0.85,
                ),
              ),
            ),
            CustomPaint(painter: _RaysPainter(palette.mid)),
            // Bayangan elips di bawah hewan (bukan kotak).
            Align(
              alignment: const Alignment(0, 0.82),
              child: FractionallySizedBox(
                widthFactor: 0.6,
                heightFactor: 0.08,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(
                      Radius.elliptical(100, 20),
                    ),
                    color: Colors.black.withValues(alpha: 0.10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, compact ? 10 : 18),
              child: KeyedSubtree(key: const Key('card-cutout'), child: fg),
            ),
          ] else if (bg != null)
            bg
          else
            const RemotePhotoPlaceholder(),
        ],
      ),
    );
  }
}

/// Sinar lembut dari tengah.
class _RaysPainter extends CustomPainter {
  const _RaysPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.longestSide;
    final paint = Paint()..color = color.withValues(alpha: 0.18);
    const rays = 18;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays;
      final b = a + math.pi / rays;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + radius * math.cos(a),
          center.dy + radius * math.sin(a),
        )
        ..lineTo(
          center.dx + radius * math.cos(b),
          center.dy + radius * math.sin(b),
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.color != color;
}

/// Taburan kilau kecil di latar kartu (posisi tetap).
class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);

  final Color color;

  static const _spots = [
    (0.08, 0.30, 5.0),
    (0.93, 0.22, 4.0),
    (0.05, 0.62, 3.5),
    (0.95, 0.55, 5.0),
    (0.15, 0.95, 3.0),
    (0.88, 0.92, 4.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.8);
    for (final (x, y, r) in _spots) {
      final c = Offset(x * size.width, y * size.height);
      final path = Path()
        ..moveTo(c.dx, c.dy - r * 2)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r * 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r * 2)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r * 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r * 2)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}

/// Kilau holo + kemiringan 3D. Kalau [interactive], mengikuti jari dan
/// kembali pelan saat dilepas; kalau tidak, kilau diam di satu sisi.
class HoloCard extends StatefulWidget {
  const HoloCard({super.key, required this.child, this.interactive = false});

  final Widget child;
  final bool interactive;

  @override
  State<HoloCard> createState() => HoloCardState();
}

class HoloCardState extends State<HoloCard>
    with SingleTickerProviderStateMixin {
  /// Posisi jari relatif terhadap tengah kartu, -1..1.
  Offset tilt = Offset.zero;
  late final AnimationController _settle =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      )..addListener(() {
        setState(
          () => tilt = _from * (1 - Curves.easeOut.transform(_settle.value)),
        );
      });
  Offset _from = Offset.zero;

  /// Maks kemiringan (radian).
  static const maxAngle = 0.22;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _move(Offset local) {
    final size = (context.findRenderObject()! as RenderBox).size;
    if (size.isEmpty) return;
    _settle.stop();
    setState(() {
      tilt = Offset(
        (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  void _release() {
    _from = tilt;
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.interactive ? tilt : const Offset(-0.6, -0.8);
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(-t.dy * maxAngle * (widget.interactive ? 1 : 0))
      ..rotateY(t.dx * maxAngle * (widget.interactive ? 1 : 0));

    final layered = Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            // Kilau statis (grid) lebih tipis supaya kartu tidak pudar.
            child: Opacity(
              opacity: widget.interactive ? 1 : 0.45,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: DecoratedBox(
                  key: const Key('holo-sheen'),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1 + t.dx, -1 + t.dy),
                      end: Alignment(1 + t.dx, 1 + t.dy),
                      colors: [
                        const Color(0x00FFFFFF),
                        const Color(0x33FF6FD8),
                        const Color(0x3346E0FF),
                        const Color(0x55FFFFFF),
                        const Color(0x33FFE36E),
                        const Color(0x337CFF8A),
                        const Color(0x00FFFFFF),
                      ],
                      stops: const [0.0, 0.3, 0.42, 0.5, 0.58, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    final tilted = Transform(
      key: const Key('holo-surface'),
      alignment: Alignment.center,
      transform: transform,
      child: layered,
    );
    if (!widget.interactive) return tilted;

    // Listener (bukan GestureDetector): kilau mengikuti jari tanpa merebut
    // gestur, jadi halaman tetap bisa di-scroll walau jari mulai di kartu.
    return Listener(
      key: const Key('holo-gesture'),
      onPointerDown: (e) => _move(e.localPosition),
      onPointerMove: (e) => _move(e.localPosition),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: tilted,
    );
  }
}

/// Kartu baru setelah posting catch ("baru dapet!" / "ketemu lagi!").
Future<void> showNewCardDialog(
  BuildContext context,
  AnimalCardData data, {
  required bool reencounter,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (context, animation, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
      child: child,
    ),
    pageBuilder: (context, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            key: const Key('new-card'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                reencounter ? 'KETEMU LAGI!' : 'BARU DAPET!',
                style: FurrealText.mono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ).copyWith(color: FurrealColors.accent, letterSpacing: 2),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: AnimalCard(data: data, interactive: true),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('new-card-done'),
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: FurrealColors.accent,
                  foregroundColor: FurrealColors.ink,
                  minimumSize: const Size(220, 52),
                  shape: const StadiumBorder(),
                ),
                child: const Text('masuk koleksi'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
