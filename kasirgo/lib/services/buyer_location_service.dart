import 'package:shared_preferences/shared_preferences.dart';

import '../utils/geo.dart';

/// ST17-5 (Phase 17 - Ekosistem Hyper-Local): simpan lokasi Pembeli di perangkat.
///
/// Lokasi bersifat lokal (UU PDP): hanya dipakai untuk memanggil `nearby_outlets`.
/// Deteksi otomatis GPS di Android/iOS (plugin geolocator) dan Geolocation API
/// di web; fallback input manual bila ditolak/tak tersedia.
class BuyerLocationService {
  static const _latKey = 'buyer_location_lat';
  static const _lngKey = 'buyer_location_lng';

  Future<GeoPosition?> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    if (lat == null || lng == null) return null;
    return GeoPosition(lat: lat, lng: lng);
  }

  Future<void> save(GeoPosition pos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, pos.lat);
    await prefs.setDouble(_lngKey, pos.lng);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_latKey);
    await prefs.remove(_lngKey);
  }

  /// Deteksi otomatis (GPS perangkat; browser Geolocation API di web).
  /// Null bila tak tersedia / ditolak -> UI memakai input manual.
  Future<GeoPosition?> detect() => detectDevicePosition();
}
