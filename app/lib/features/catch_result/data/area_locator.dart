import 'dart:ui';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Hasil pencarian label area. Koordinat tidak pernah keluar dari HP.
sealed class AreaResult {
  const AreaResult();
}

class AreaFound extends AreaResult {
  const AreaFound(this.label);
  final String label;
}

/// Izin lokasi ditolak.
class AreaDenied extends AreaResult {
  const AreaDenied();
}

/// GPS mati, timeout, atau geocoder tidak memberi hasil.
class AreaUnavailable extends AreaResult {
  const AreaUnavailable();
}

abstract interface class AreaLocator {
  Future<AreaResult> currentArea();
}

class GeoAreaLocator implements AreaLocator {
  @override
  Future<AreaResult> currentArea() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const AreaDenied();
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const AreaUnavailable();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final placemarks = await Geocoding(locale: const Locale('id', 'ID'))
          .placemarkFromCoordinates(position.latitude, position.longitude);
      final label = placemarks.isEmpty
          ? null
          : formatAreaLabel(
              district:
                  placemarks.first.locality ?? placemarks.first.subLocality,
              regency:
                  placemarks.first.subAdministrativeArea ??
                  placemarks.first.administrativeArea,
            );
      return label == null ? const AreaUnavailable() : AreaFound(label);
    } catch (_) {
      return const AreaUnavailable();
    }
  }
}

final _prefixes = RegExp(
  r'^(kecamatan|kec\.|kabupaten|kab\.|kota|kelurahan|kel\.|desa)\s+',
  caseSensitive: false,
);

/// "Kecamatan Depok" + "Kabupaten Sleman" → "sekitar Depok, Sleman".
String? formatAreaLabel({String? district, String? regency}) {
  String? clean(String? s) {
    final v = s?.trim().replaceFirst(_prefixes, '').trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  final parts = <String>{?clean(district), ?clean(regency)};
  if (parts.isEmpty) return null;
  final label = 'sekitar ${parts.join(', ')}';
  return label.length > 80 ? label.substring(0, 80) : label;
}
