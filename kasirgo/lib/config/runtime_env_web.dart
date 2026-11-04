// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
library;

import 'dart:js' as js;

/// Web: baca `window.KASIRGO_CONFIG` yang ditulis installer (self-host).
///
/// Contoh global yang diharapkan:
/// `window.KASIRGO_CONFIG = { "supabaseUrl": "https://...", "supabaseAnonKey": "..." }`
Map<String, String>? readWebRuntimeConfig() {
  try {
    final raw = js.context['KASIRGO_CONFIG'];
    if (raw == null) return null;
    final cfg = raw as js.JsObject;
    final out = <String, String>{};
    final url = cfg['supabaseUrl'];
    final key = cfg['supabaseAnonKey'];
    if (url is String && url.isNotEmpty) out['supabaseUrl'] = url;
    if (key is String && key.isNotEmpty) out['supabaseAnonKey'] = key;
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  }
}