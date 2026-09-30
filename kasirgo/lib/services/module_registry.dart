import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/module_provider.dart';

/// Registry modul dinamis per outlet_type (Phase 8 / ST8-1, rollout ST11-4).
///
/// - Sumber utama: `ModuleConfig` (peta modul per outlet_type, termasuk alias
///   tipe usaha bebas seperti "Warung Sembako" -> kelontong).
/// - Override via tabel `feature_flags` (key `module_<nama>`, contoh:
///   `module_kitchenDisplay`): enabled=false mematikan modul walau default
///   aktif; enabled=true menyalakan modul walau default mati (mis. Pendukung).
/// - ST11-4 staged rollout: flag dievaluasi SERVER-SIDE per outlet via RPC
///   `feature_flags_for_outlet` (enabled + rollout_pct hash + outlet_types +
///   segments). Offline-safe: hasil terakhir di-cache memori per outlet;
///   bila RPC gagal, fallback ke select langsung (tanpa rollout) atau default.
class ModuleRegistry {
  static final Map<String, Map<String, bool>> _flagsCache = {};
  static final Map<String, DateTime> _fetchedAt = {};
  static const Duration _ttl = Duration(minutes: 5);

  /// Modul default per outlet_type (tanpa override feature flag).
  static Set<BusinessModule> defaultModules(String outletType) =>
      ModuleConfig.getModules(outletType);

  /// Helper sinkron (tanpa flag) untuk keputusan cepat UI.
  static bool isModuleEnabled(String outletType, BusinessModule module) =>
      ModuleConfig.isEnabled(outletType, module);

  /// Modul efektif = default + override flags (param / cache / kosong).
  static Set<BusinessModule> effectiveModules(
    String outletType, {
    Map<String, bool>? flags,
  }) {
    final defaults = Set<BusinessModule>.from(defaultModules(outletType));
    final f = flags ??
        (_flagsCache.length == 1 ? _flagsCache.values.first : null);
    if (f == null || f.isEmpty) return defaults;
    for (final m in BusinessModule.values) {
      final v = f['module_${m.name}'];
      if (v == null) continue;
      if (v == false) {
        defaults.remove(m);
      } else {
        defaults.add(m);
      }
    }
    return defaults;
  }

  /// Termuat utk outlet tertentu? (false = masih memakai default/offline)
  static bool flagsLoaded([String? outletId]) =>
      _flagsCache.containsKey(outletId ?? '_');

  /// Muat flags via RPC evaluasi server-side (rollout/segment/tipe) dengan
  /// fallback select langsung. Cache TTL 5 menit per outlet, offline-safe.
  static Future<Map<String, bool>> loadFlagsForOutlet(
    String outletId, {
    SupabaseClient? client,
  }) async {
    final now = DateTime.now();
    final cachedAt = _fetchedAt[outletId];
    if (cachedAt != null && now.difference(cachedAt) < _ttl) {
      return _flagsCache[outletId] ?? const {};
    }
    final c = client ?? Supabase.instance.client;
    Map<String, bool>? out;
    try {
      final res = await c
          .rpc('feature_flags_for_outlet', params: {'p_outlet_id': outletId});
      if (res is Map) {
        out = res.map((k, v) => MapEntry(k.toString(), v == true));
      }
    } catch (_) {
      // RPC belum ada / offline: fallback select langsung (tanpa rollout).
      try {
        final res = await c
            .from('feature_flags')
            .select('key, enabled, rollout_pct, outlet_types, segments');
        out = {};
        for (final row in (res as List)) {
          final m = row as Map;
          bool on = m['enabled'] == true;
          final pct = (m['rollout_pct'] as num?)?.toInt() ?? 100;
          if (on && pct < 100) {
            on = _stableBucket(outletId) < pct;
          }
          out[m['key'].toString()] = on;        }
      } catch (_) {
        _fetchedAt[outletId] = now;
        return _flagsCache[outletId] ?? const {};
      }
    }
    _flagsCache[outletId] = out ?? const {};
    _fetchedAt[outletId] = now;
    return _flagsCache[outletId] ?? const {};
  }

  /// Bucket deterministik 0..99 dari outlet_id (hash FNV-1a ringan).
  static int _stableBucket(String id) {
    var h = 0x811c9dc5;
    for (final code in id.codeUnits) {
      h ^= code;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h % 100;
  }

  /// Legacy: muat flags tanpa outlet (dipakai tempat lama); tetap jalan.
  static Future<Map<String, bool>> loadFlags({SupabaseClient? client}) async {
    final now = DateTime.now();
    final cachedAt = _fetchedAt['_'];
    if (cachedAt != null && now.difference(cachedAt) < _ttl) {
      return _flagsCache['_'] ?? const {};
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
      _flagsCache['_'] = out;
      _fetchedAt['_'] = now;
    } catch (_) {
      _fetchedAt['_'] = now;
    }
    return _flagsCache['_'] ?? const {};
  }
}
