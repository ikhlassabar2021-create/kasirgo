/// ST17-5 (Phase 17 - Ekosistem Hyper-Local): akses lokasi pembeli.
///
/// Android/iOS memakai plugin `geolocator` (GPS); web memakai Geolocation API
/// browser. `detectDevicePosition()` adalah titik masuk tunggal.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

import '../models/geo_position.dart';
import 'geo_stub.dart' if (dart.library.html) 'geo_web.dart';

export '../models/geo_position.dart';

/// Deteksi posisi perangkat (GPS) secara lintas platform.
///
/// [prompt] = false untuk pemantauan rutin: tidak memicu dialog izin OS
/// (bila belum diizinkan, langsung null). Mengembalikan [GeoPosition] bila
/// berhasil, atau null bila izin ditolak / layanan GPS mati / tidak tersedia.
Future<GeoPosition?> detectDevicePosition({bool prompt = true}) async {
  if (kIsWeb) {
    return getBrowserPosition();
  }

  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && prompt) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: const Duration(seconds: 15),
    );
    return GeoPosition(lat: pos.latitude, lng: pos.longitude);
  } catch (_) {
    return null;
  }
}
