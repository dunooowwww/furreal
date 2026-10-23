import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Pilih foto profil dari galeri, siap upload (JPEG kecil, tanpa EXIF).
abstract interface class AvatarPicker {
  /// null kalau user batal memilih.
  Future<Uint8List?> pickJpeg();
}

class GalleryAvatarPicker implements AvatarPicker {
  static const size = 512;
  static const quality = 80;

  final _picker = ImagePicker();

  @override
  Future<Uint8List?> pickJpeg() async {
    // Android 13+: photo picker sistem, tanpa izin penyimpanan.
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    // Sisi pendek diskalakan ke maks 512px; EXIF (termasuk GPS) dibuang.
    return FlutterImageCompress.compressWithList(
      await file.readAsBytes(),
      minWidth: size,
      minHeight: size,
      quality: quality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
  }
}
