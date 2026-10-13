import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CameraLens { back, front }

/// Izin kamera ditolak user (atau dibatasi sistem).
class CameraPermissionDenied implements Exception {
  const CameraPermissionDenied();
}

/// Kamera untuk catch: hanya memotret langsung, tanpa galeri.
/// Dibungkus interface supaya bisa diganti kamera palsu di test.
abstract interface class CatchCamera {
  /// Buka (atau ganti ke) lensa [lens]. Melempar [CameraPermissionDenied].
  Future<void> open(CameraLens lens);

  Widget buildPreview();

  Future<Uint8List> takePicture();

  Future<void> setFlashAuto(bool auto);

  Future<void> dispose();
}

class PluginCatchCamera implements CatchCamera {
  CameraController? _controller;

  static const _deniedCodes = {
    'CameraAccessDenied',
    'CameraAccessDeniedWithoutPrompt',
    'CameraAccessRestricted',
  };

  @override
  Future<void> open(CameraLens lens) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw CameraException('NoCamera', 'tidak ada kamera');
    final wanted = lens == CameraLens.back
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final description = cameras.firstWhere(
      (c) => c.lensDirection == wanted,
      orElse: () => cameras.first,
    );

    await _controller?.dispose();
    // ~1080p: cukup untuk lebar 1280 setelah kompres, dan cepat diproses.
    final controller = CameraController(
      description,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } on CameraException catch (e) {
      if (_deniedCodes.contains(e.code)) throw const CameraPermissionDenied();
      rethrow;
    }
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    // Isi penuh viewfinder (cover), preview kamera dalam orientasi potret.
    final size = controller.value.previewSize;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size?.height ?? 1080,
        height: size?.width ?? 1920,
        child: CameraPreview(controller),
      ),
    );
  }

  @override
  Future<Uint8List> takePicture() async {
    final file = await _controller!.takePicture();
    return file.readAsBytes();
  }

  @override
  Future<void> setFlashAuto(bool auto) async {
    try {
      await _controller?.setFlashMode(auto ? FlashMode.auto : FlashMode.off);
    } on CameraException {
      // Kamera depan biasanya tanpa flash.
    }
  }

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
