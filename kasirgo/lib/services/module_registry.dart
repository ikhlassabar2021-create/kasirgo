import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/module_provider.dart';

/// Registry modul dinamis per outlet_type (Phase 8 / ST8-1).
///
/// - Sumber utama: `ModuleConfig` (peta modul per outlet_type, termasuk alias
///   tipe usaha bebas seperti "Warung Sembako" -> kelontong).
/// - Override via tabel `feature_flags` (key `module_<nama>`, contoh:
///   `module_kitchenDisplay`): enabled=false mematikan modul walau default
///   aktif; enabled=true menyalakan modul walau default mati (mis. Pendukung).
/// - Offline-safe: hasil terakhir di-cache di memori; bila gagal ambil,
///   fallback ke default per outlet_type.
class ModuleRegistry {
  static Map<String, bool>? _flags;
  static DateTime? _fetchedAt;
  static const Duration _ttl = Duration(minutes: 5);

  /// Modul default per outlet_type (tanpa override feature flag).
  static Set<BusinessModule> defaultModules(String outletType) =>
      ModuleConfig.getModules(outletType);

  /// Helper sinkron (tanpa flag) untuk keputusan cepat UI.
  static bool isModuleEnabled(String outletType, BusinessModule module) =>
      ModuleConfig.isEnabled(outletType, module);

  /// Modul efektif = default + override feature_flags yang sudah termuat.
  static Set<BusinessModule> effectiveModules(String outletType) {
    final defaults = Set<BusinessModule>.from(defaultModules(outletType));
    final flags = _flags;
    if (flags == null || flags.isEmpty) return defaults;
    for (final m in BusinessModule.values) {
      final v = flags['module_${m.name}'];
      if (v == null) continue;
      if (v == false) {
        defaults.remove(m);
      } else {
        defaults.add(m);
      }
    }
    return defaults;
  }

  /// Termuat? (false = masih memakai default, flag belum tersedia/offline)
  static bool get flagsLoaded => _flags != null;

  /// Muat feature_flags `module_*` (cache TTL 5 menit, offline-safe).
  static Future<Map<String, bool>> loadFlags({SupabaseClient? client}) async {
    final now = DateTime.now();
    if (_fetchedAt != null && now.difference(_fetchedAt!) < _ttl) {
      return _flags ?? const {};
    }
    try {
      final c = client ?? Supabase.instance.client;
      final res = await c
          .from('feature_flags')
          .select('key, enabled')
          .like('key', 'module_%');
      final out = <String, bool>{};
      for (final row in (res as List)) {
        final k = (row as Map)['key'].toString();
        out[k] = row['enabled'] == true;
      }
      _flags = out;
      _fetchedAt = now;
    } catch (_) {
      // Offline / tabel belum ada: pertahankan cache terakhir (atau null
      // artinya pakai default per outlet_type).
      _fetchedAt = now;
    }
    return _flags ?? const {};
  }
}
