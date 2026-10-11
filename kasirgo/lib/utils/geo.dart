/// ST17-5 (Phase 17 - Ekosistem Hyper-Local): akses lokasi pembeli.
///
/// Web memakai Geolocation API bawaan browser; platform lain memakai stub
/// (plugin GPS belum terpasang, jadi pembeli dapat mengisi koordinat manual).
library;

export '../models/geo_position.dart';
export 'geo_stub.dart' if (dart.library.html) 'geo_web.dart';
