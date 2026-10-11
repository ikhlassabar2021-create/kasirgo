import 'package:shared_preferences/shared_preferences.dart';

import '../utils/geo.dart';

/// ST17-5 (Phase 17 - Ekosistem Hyper-Local): simpan lokasi Pembeli di perangkat.
///
/// Lokasi bersifat lokal (UU PDP): hanya dipakai untuk memanggil `nearby_outlets`.
/// Web dapat mendeteksi otomatis via Geolocation API; platform lain memakai
/// input manual karena plugin GPS belum terpasang.
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

  /// Deteksi otomatis (web browser). Null bila tak tersedia/ditolak.
  Future<GeoPosition?> detect() => getBrowserPosition();
}
