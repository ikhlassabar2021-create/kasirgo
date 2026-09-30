import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/module_registry.dart';
import '../services/ppob_service.dart';
import 'outlet_provider.dart';

enum BusinessModule {
  pos,
  inventory,
  debt, // Kasbon
  tableManagement, // QR Meja & Meja dine-in
  kitchenDisplay, // KDS
  recipeIngredients, // Resep & bahan baku
  variants, // Varian produk (level pedas, topping, ukuran)
  ppob, // Pulsa, token PLN, e-wallet
  restockB2B, // Kulakan B2B supplier
  wholesalePrice, // Harga grosir berjenjang
  splitBill, // Pisah tagihan
  dailyDigest, // AI digest
}

class ModuleConfig {
  static const Map<String, Set<BusinessModule>> _outletModules = {
    // Kelontong / Warung: semua fitur KECUALI QR Meja dine-in (tableManagement).
    'kelontong': {
      BusinessModule.pos,
      BusinessModule.inventory,
      BusinessModule.debt,
      BusinessModule.kitchenDisplay,
      BusinessModule.recipeIngredients,
      BusinessModule.variants,
      BusinessModule.ppob,
      BusinessModule.restockB2B,
      BusinessModule.wholesalePrice,
      BusinessModule.splitBill,
      BusinessModule.dailyDigest,
    },
    // Warteg / Warung makan: semua fitur KECUALI PPOB.
    'warteg': {
      BusinessModule.pos,
      BusinessModule.inventory,
      BusinessModule.debt,
      BusinessModule.tableManagement,
      BusinessModule.kitchenDisplay,
      BusinessModule.recipeIngredients,
      BusinessModule.variants,
      BusinessModule.restockB2B,
      BusinessModule.wholesalePrice,
      BusinessModule.splitBill,
      BusinessModule.dailyDigest,
    },
    // Cafe / Restoran / Kedai Kopi: semua fitur KECUALI PPOB.
    'cafe': {
      BusinessModule.pos,
      BusinessModule.inventory,
      BusinessModule.debt,
      BusinessModule.tableManagement,
      BusinessModule.kitchenDisplay,
      BusinessModule.recipeIngredients,
      BusinessModule.variants,
      BusinessModule.restockB2B,
      BusinessModule.wholesalePrice,
      BusinessModule.splitBill,
      BusinessModule.dailyDigest,
    },
    // Retail / Toko: semua fitur KECUALI tableManagement & kitchenDisplay.
    'retail': {
      BusinessModule.pos,
      BusinessModule.inventory,
      BusinessModule.debt,
      BusinessModule.recipeIngredients,
      BusinessModule.variants,
      BusinessModule.ppob,
      BusinessModule.restockB2B,
      BusinessModule.wholesalePrice,
      BusinessModule.splitBill,
      BusinessModule.dailyDigest,
    },
    // Gerobak: semua fitur KECUALI PPOB & QR Meja dine-in (tableManagement).
    'gerobak': {
      BusinessModule.pos,
      BusinessModule.inventory,
      BusinessModule.debt,
      BusinessModule.kitchenDisplay,
      BusinessModule.recipeIngredients,
      BusinessModule.variants,
      BusinessModule.restockB2B,
      BusinessModule.wholesalePrice,
      BusinessModule.splitBill,
      BusinessModule.dailyDigest,
    },
  };

  /// Memetakan label tipe usaha (yang dipilih saat daftar) ke kunci modul.
  static const Map<String, String> _typeAliases = {
    'warung sembako': 'kelontong',
    'warung madura': 'kelontong',
    'kelontong': 'kelontong',
    'minimarket': 'kelontong',
    'retail': 'retail',
    'toko baju': 'retail',
    'apotek': 'retail',
    'cafe': 'cafe',
    'kedai kopi': 'cafe',
    'restoran': 'cafe',
    'warteg': 'warteg',
    'warung makan': 'warteg',
    'gerobak': 'gerobak',
    'gerobak keliling': 'gerobak',
    'lainnya': 'kelontong',
  };

  /// Normalisasi tipe usaha bebas -> kunci modul yang dikenal.
  static String normalizeType(String outletType) {
    final key = outletType.trim().toLowerCase();
    if (_outletModules.containsKey(key)) return key;
    return _typeAliases[key] ?? 'kelontong';
  }

  static Set<BusinessModule> getModules(String outletType) {
    final normalized = normalizeType(outletType);
    return _outletModules[normalized] ?? _outletModules['kelontong']!;
  }

  static bool isEnabled(String outletType, BusinessModule module) {
    return getModules(outletType).contains(module);
  }
}

/// Flag `module_*` dari feature_flags (dimuat sekali, offline fallback default).
final moduleFlagsProvider =
    FutureProvider<Map<String, bool>>((ref) => ModuleRegistry.loadFlags());

final activeModulesProvider =
    Provider.family<Set<BusinessModule>, String>((ref, outletId) {
  final outletType = ref.watch(outletTypeProvider(outletId));
  // Memuat flag di latar belakang; provider ini reaktif saat selesai.
  ref.watch(moduleFlagsProvider);
  return ModuleRegistry.effectiveModules(outletType);
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
