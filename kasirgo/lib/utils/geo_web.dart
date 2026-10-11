// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
library;

import 'dart:async';
import 'dart:html' as html;

import '../models/geo_position.dart';

/// Web: minta posisi pembeli dari Geolocation API browser.
///
/// Mengembalikan null bila ditolak/tidak tersedia agar UI memakai input manual.
Future<GeoPosition?> getBrowserPosition() async {
  try {
    final pos = await html.window.navigator.geolocation
        .getCurrentPosition(
          enableHighAccuracy: false,
          timeout: const Duration(seconds: 8),
          maximumAge: const Duration(minutes: 1),
        )
        .timeout(const Duration(seconds: 9));
    final coords = pos.coords;
    final lat = coords?.latitude;
    final lng = coords?.longitude;
    if (lat == null || lng == null) return null;
    return GeoPosition(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
    );
  } catch (_) {
    return null;
  }
}
