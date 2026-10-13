import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catch_camera.dart';

/// Membuat sesi kamera baru per layar kamera.
final catchCameraFactoryProvider = Provider<CatchCamera Function()>(
  (ref) => PluginCatchCamera.new,
);
