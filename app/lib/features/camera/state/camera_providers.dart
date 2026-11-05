import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catch_camera.dart';

/// Membuat sesi kamera baru per layar kamera.
final catchCameraFactoryProvider = Provider<CatchCamera Function()>(
  (ref) => PluginCatchCamera.new,
);

/// Jeda sebelum foto kedua dijepret otomatis (kamera menyesuaikan cahaya).
/// Di test dibuat nol.
final autoCaptureDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 600),
);
