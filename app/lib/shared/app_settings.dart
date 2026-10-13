import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Buka halaman pengaturan app (izin kamera/lokasi). Di-override di test.
final openAppSettingsProvider = Provider<Future<bool> Function()>(
  (ref) => Geolocator.openAppSettings,
);
