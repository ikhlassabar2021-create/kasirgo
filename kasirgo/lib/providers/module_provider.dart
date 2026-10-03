import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/module_registry.dart';
import '../services/ppob_service.dart';
import '../services/fintech_service.dart';
import '../services/hyperlocal_service.dart';
import '../services/insurance_service.dart';
import 'outlet_provider.dart';

enum BusinessModule {
  pos,
  inventory,
  tableManagement, // QR Meja & Meja dine-in
  kitchenDisplay, // KDS
  recipeIngredients, // Resep & bahan baku
  ppob, // Pulsa, token PLN, e-wallet
  restockB2B, // Kulakan B2B supplier
  wholesalePrice, // Harga grosir berjenjang
  shifts, // Shift kasir & setoran
  dailyDigest, // AI digest
}

class ModuleConfig {
  static const Map<String, Set<BusinessModule>> _outletModules = {
    // Kelontong / Warung: semua fitur KECUALI QR Meja & KDS (bukan usaha makan).
    'kelontong': {
      BusinessModule.pos,
      BusinessModule.inventory,
      BusinessModule.ppob,
      BusinessModule.restockB2B,
      BusinessModule.wholesalePrice,
      BusinessModule.shifts,
      BusinessModule.dailyDigest,
    },
    // Warteg / Warung makan: semua fitur KECUALI PPOB (usaha makan -> KDS on).
    'warteg': {
      BusinessModule.pos,
      BusinessModule.inventory,
      BusinessModule.tableManagement,
      BusinessModule.kitchenDisplay,
      BusinessModule.restockB2B,
      BusinessModule.wholesalePrice,
      BusinessModule.shifts,
      BusinessModule.dailyDigest,
    },
    // Cafe / Restoran / Kedai Kopi: semua fitur KECUALI PPOB (KDS on).
    'cafe': {
      BusinessModule.pos,
      BusinessModule.inventory,
      BusinessModule.tableManagement,
      BusinessModule.kitchenDisplay,
      BusinessModule.restockB2B,
      BusinessModule.wholesalePrice,
      BusinessModule.shifts,
      BusinessModule.dailyDigest,
    },
    // Retail / Toko: semua fitur KECUALI tableManagement & kitchenDisplay.
    'retail': {
      BusinessModule.pos,
      BusinessModule.inventory,
      BusinessModule.ppob,
      BusinessModule.restockB2B,
      BusinessModule.wholesalePrice,
      BusinessModule.shifts,
      BusinessModule.dailyDigest,
    },
    // Gerobak: semua fitur KECUALI PPOB & QR Meja (bukan usaha makan -> KDS off).
    'gerobak': {
      BusinessModule.pos,
      BusinessModule.inventory,
      BusinessModule.restockB2B,
      BusinessModule.wholesalePrice,
      BusinessModule.shifts,
      BusinessModule.dailyDigest,
    },
  };

  /// Memetakan label tipe usaha (yang dipilih saat daftar) ke kunci modul.
  static const Map<String, String> _typeAliases = {
    'warung sembako': 'kelontong',
    'warung madura': 'kelontong',
    'kelontong': 'kelontong',
    'minimarket': 'kelontong',
    'sembako': 'kelontong',
    'toko kelontong': 'kelontong',
    'retail': 'retail',
    'toko baju': 'retail',
    'butik': 'retail',
    'apotek': 'retail',
    'toko': 'retail',
    'cafe': 'cafe',
    'kafe': 'cafe',
    'coffee shop': 'cafe',
    'kedai kopi': 'cafe',
    'kedai': 'cafe',
    'restoran': 'cafe',
    'resto': 'cafe',
    'restaurant': 'cafe',
    'bakery': 'cafe',
    'toko kue': 'cafe',
    'food court': 'cafe',
    'cafe & resto': 'cafe',
    'warteg': 'warteg',
    'warung makan': 'warteg',
    'rumah makan': 'warteg',
    'depot': 'warteg',
    'catering': 'warteg',
    'gerobak': 'gerobak',
    'gerobak keliling': 'gerobak',
    'food truck': 'gerobak',
    'lainnya': 'kelontong',
  };

  /// Kata kunci cadangan bila label tidak persis cocok (mis. "Kafe & Resto",
  /// "Warung Kopi", "Cafe Nusantara"). Usaha makan/minuman diprioritaskan agar
  /// modul KDS & QR Meja tetap aktif (default ada).
  static const List<(String, String)> _containsRules = [
    ('warteg', 'warteg'),
    ('rumah makan', 'warteg'),
    ('warung makan', 'warteg'),
    ('caffe', 'cafe'),
    ('cafe', 'cafe'),
    ('kafe', 'cafe'),
    ('coffee', 'cafe'),
    ('resto', 'cafe'),
    ('restaurant', 'cafe'),
    ('restoran', 'cafe'),
    ('kedai', 'cafe'),
    ('bakery', 'cafe'),
    ('kopi', 'cafe'),
    ('makanan', 'warteg'),
    ('minuman', 'cafe'),
    ('gerobak', 'gerobak'),
    ('keliling', 'gerobak'),
    ('sembako', 'kelontong'),
    ('kelontong', 'kelontong'),
    ('minimarket', 'kelontong'),
    ('madura', 'kelontong'),
    ('apotek', 'retail'),
    ('baju', 'retail'),
    ('butik', 'retail'),
    ('retail', 'retail'),
  ];

  /// Normalisasi tipe usaha bebas -> kunci modul yang dikenal.
  static String normalizeType(String outletType) {
    final key = outletType.trim().toLowerCase();
    if (_outletModules.containsKey(key)) return key;
    final direct = _typeAliases[key];
    if (direct != null) return direct;
    // Cadangan: cocokkan kata kunci (mis. "Kafe & Resto" -> cafe).
    for (final rule in _containsRules) {
      if (key.contains(rule.$1)) return rule.$2;
    }
    return 'kelontong';
  }

  static Set<BusinessModule> getModules(String outletType) {
    final normalized = normalizeType(outletType);
    return _outletModules[normalized] ?? _outletModules['kelontong']!;
  }

  static bool isEnabled(String outletType, BusinessModule module) {
    return getModules(outletType).contains(module);
  }

  /// Usaha makanan/minuman (cafe/warteg/resto) yang butuh QR Meja & KDS.
  /// Warung/kelontong/retail/gerobak adalah usaha non-makan.
  static bool isFoodBusiness(String outletType) {
    final t = normalizeType(outletType);
    return t == 'cafe' || t == 'warteg';
  }
}

/// Flag `module_*` dari feature_flags (dimuat sekali, offline fallback default).
final moduleFlagsProvider =
    FutureProvider<Map<String, bool>>((ref) => ModuleRegistry.loadFlags());

/// Flags efektif per outlet via RPC (rollout_pct + outlet_types + segments
/// dievaluasi server-side; ST11-4 staged rollout). Cache TTL 5 menit.
final outletFlagsProvider =
    FutureProvider.family<Map<String, bool>, String>(
        (ref, outletId) => ModuleRegistry.loadFlagsForOutlet(outletId));

final activeModulesProvider =
    Provider.family<Set<BusinessModule>, String>((ref, outletId) {
  final outletType = ref.watch(outletTypeProvider(outletId));
  // Flags per outlet (staged rollout) dipakai bila sudah termuat;
  // fallback: cache registry / default per outlet_type.
  final flags = ref.watch(outletFlagsProvider(outletId)).asData?.value;
  return ModuleRegistry.effectiveModules(outletType, flags: flags);
});

final isModuleEnabledProvider =
    Provider.family<bool, ({String outletId, BusinessModule module})>(
        (ref, arg) {
  final modules = ref.watch(activeModulesProvider(arg.outletId));
  return modules.contains(arg.module);
});

/// PPOB hanya aktif bila modul outlet_type mengizinkan DAN config superadmin
/// (platform_configs 'ppob'.enabled) aktif. Cache offline-safe di service.
final ppobEnabledProvider = FutureProvider<bool>((ref) async {
  final cfg = await PpobService().loadConfig();
  return cfg.enabled;
});

/// Modal Usaha (fintech lead) aktif via config superadmin.
final fintechEnabledProvider = FutureProvider<bool>((ref) async {
  final cfg = await FintechService().loadConfig();
  return cfg.enabled;
});

/// Tren Wilayah (hyperlocal) aktif via config superadmin; consent owner
/// ditanyakan terpisah di dalam screen (UU PDP).
final hyperlocalEnabledProvider = FutureProvider<bool>((ref) async {
  final svc = HyperlocalService();
  return svc.loadConfig();
});

/// Asuransi Mikro aktif via config superadmin (produk list di config).
final insuranceEnabledProvider = FutureProvider<bool>((ref) async {
  final svc = InsuranceService();
  final cfg = await svc.loadConfig();
  return cfg.enabled && cfg.products.isNotEmpty;
});
