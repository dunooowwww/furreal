import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Kompres foto sebelum upload (PRD §8): lebar maks 1280px, JPEG ~80.
abstract interface class PhotoCompressor {
  Future<Uint8List> compress(Uint8List photo);
}

class NativePhotoCompressor implements PhotoCompressor {
  static const maxWidth = 1280;
  static const quality = 80;

  @override
  Future<Uint8List> compress(Uint8List photo) {
    // Plugin menskalakan sisi pendek ke maks [maxWidth] (tanpa memperbesar),
    // lalu memutar sesuai EXIF. Kamera dikunci potret, jadi sisi pendek = lebar.
    // EXIF (termasuk kemungkinan GPS) dibuang.
    return FlutterImageCompress.compressWithList(
      photo,
      minWidth: maxWidth,
      minHeight: maxWidth,
      quality: quality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
  }
}
