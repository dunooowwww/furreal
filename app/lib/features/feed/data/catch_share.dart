import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// Ukuran gambar yang dibagikan (4:5, pas untuk feed medsos).
const shareImageSize = Size(1080, 1350);

const _accent = Color(0xFFD4FF3A);
const _ink = Color(0xFF111111);

const _months = [
  'jan', 'feb', 'mar', 'apr', 'mei', 'jun', //
  'jul', 'agu', 'sep', 'okt', 'nov', 'des',
];

String _date(DateTime t) {
  final l = t.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}';
}

typedef ShareImageComposer = Future<Uint8List> Function({
  required Uint8List animalPhoto,
  required Uint8List selfiePhoto,
  required String animalName,
  required DateTime date,
  String? caption,
});

/// Gambar catch untuk disimpan/dibagikan (ala hasil unduh BeReal): foto
/// hewan penuh, selfie kecil di pojok kiri atas, watermark furreal +
/// tanggal, lalu nama hewan & caption di bawah. PNG.
Future<Uint8List> composeShareImage({
  required Uint8List animalPhoto,
  required Uint8List selfiePhoto,
  required String animalName,
  required DateTime date,
  String? caption,
}) async {
  final animal = await _decode(animalPhoto);
  final selfie = await _decode(selfiePhoto);
  final w = shareImageSize.width;
  final h = shareImageSize.height;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
  canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = _ink);

  // Foto hewan memenuhi gambar (cover).
  _drawCover(canvas, animal, Rect.fromLTWH(0, 0, w, h));

  // Gradasi gelap di bawah supaya teks terbaca.
  canvas.drawRect(
    Rect.fromLTWH(0, h * 0.55, w, h * 0.45),
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, h * 0.55), Offset(0, h), [
        const Color(0x00000000),
        const Color(0xCC000000),
      ]),
  );

  // Selfie di pojok kiri atas, bingkai putih membulat.
  const selfieRect = Rect.fromLTWH(48, 48, 270, 360);
  final rrect = RRect.fromRectAndRadius(selfieRect, const Radius.circular(36));
  canvas.save();
  canvas.clipRRect(rrect);
  _drawCover(canvas, selfie, selfieRect);
  canvas.restore();
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = const Color(0xFFFFFFFF),
  );

  // Watermark furreal (kanan atas).
  final mark = _text('furreal', size: 46, weight: FontWeight.w800, color: _ink);
  final markRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(w - 48 - mark.width - 56, 48, mark.width + 56, 84),
    const Radius.circular(42),
  );
  canvas.drawRRect(markRect, Paint()..color = _accent);
  mark.paint(
    canvas,
    Offset(markRect.left + 28, markRect.top + (84 - mark.height) / 2),
  );
  final day = _text(_date(date), size: 30, color: const Color(0xFFFFFFFF));
  day.paint(canvas, Offset(w - 48 - day.width, markRect.bottom + 16));

  // Nama hewan + caption (bawah).
  final captionText = caption?.trim();
  var y = h - 64.0;
  if (captionText != null && captionText.isNotEmpty) {
    final cap = _text(
      captionText,
      size: 38,
      color: const Color(0xFFFFFFFF),
      maxWidth: w - 96,
      maxLines: 3,
    );
    y -= cap.height;
    cap.paint(canvas, Offset(48, y));
    y -= 16;
  }
  final name = _text(
    animalName,
    size: 76,
    weight: FontWeight.w800,
    color: const Color(0xFFFFFFFF),
    maxWidth: w - 96,
    maxLines: 1,
  );
  y -= name.height;
  name.paint(canvas, Offset(48, y));

  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  animal.dispose();
  selfie.dispose();
  image.dispose();
  return bytes!.buffer.asUint8List();
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

void _drawCover(Canvas canvas, ui.Image image, Rect dst) {
  final src = Size(image.width.toDouble(), image.height.toDouble());
  final fitted = applyBoxFit(BoxFit.cover, src, dst.size);
  final srcRect = Alignment.center.inscribe(fitted.source, Offset.zero & src);
  canvas.drawImageRect(
    image,
    srcRect,
    dst,
    Paint()..filterQuality = FilterQuality.high,
  );
}

TextPainter _text(
  String text, {
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w500,
  double? maxWidth,
  int? maxLines,
}) => TextPainter(
  text: TextSpan(
    text: text,
    style: TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.2,
    ),
  ),
  textDirection: TextDirection.ltr,
  maxLines: maxLines,
  ellipsis: maxLines == null ? null : '…',
)..layout(maxWidth: maxWidth ?? double.infinity);

/// Simpan ke galeri / bagikan lewat menu Android. Diganti palsu di test.
abstract interface class CatchSharer {
  /// Simpan ke album "furreal" di galeri. Melempar kalau izin ditolak.
  Future<void> saveToGallery(Uint8List png, {required String name});

  Future<void> share(Uint8List png, {required String name, String? text});

  /// Bagikan teks saja (undangan circle, M13).
  Future<void> shareText(String text);
}

class PluginCatchSharer implements CatchSharer {
  @override
  Future<void> saveToGallery(Uint8List png, {required String name}) async {
    if (!await Gal.hasAccess(toAlbum: true)) {
      await Gal.requestAccess(toAlbum: true);
    }
    await Gal.putImageBytes(png, album: 'furreal', name: name);
  }

  @override
  Future<void> share(
    Uint8List png, {
    required String name,
    String? text,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: ['$name.png'],
        text: text,
      ),
    );
  }

  @override
  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
