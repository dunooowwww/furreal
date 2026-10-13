import 'dart:typed_data';

/// Hasil 2 langkah kamera, dikirim ke layar hasil tangkapan.
class CapturedPhotos {
  const CapturedPhotos({required this.animal, required this.selfie});

  final Uint8List animal;
  final Uint8List selfie;
}
