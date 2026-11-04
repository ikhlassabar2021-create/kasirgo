/// Override konfigurasi runtime (untuk self-host / restore Duplicator-style).
///
/// Di web, installer menulis `window.KASIRGO_CONFIG = { supabaseUrl, supabaseAnonKey }`
/// sebelum bundle Flutter dimuat. Nilai ini menimpa `SupabaseConfig` bawaan,
/// sehingga app yang sama bisa dipindah ke instance Supabase/Postgres baru tanpa
/// rebuild. Pada non-web selalu null (pakai nilai bawaan).
library;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'runtime_env_stub.dart' if (dart.library.html) 'runtime_env_web.dart';

Map<String, String>? readRuntimeConfig() {
  if (kIsWeb) return readWebRuntimeConfig();
  return null;
}