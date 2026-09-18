import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    'kelontong': {
      BusinessModule.pos,
      BusinessModule.inventory,
      BusinessModule.debt,
      BusinessModule.ppob,
      BusinessModule.restockB2B,
      BusinessModule.wholesalePrice,
      BusinessModule.dailyDigest,
    },
    'warteg': {
      BusinessModule.pos,
      BusinessModule.inventory,
      BusinessModule.recipeIngredients,
      BusinessModule.tableManagement,
      BusinessModule.debt,
      BusinessModule.dailyDigest,
    },
    'cafe': {
      BusinessModule.pos,
      BusinessModule.inventory,
      BusinessModule.variants,
      BusinessModule.recipeIngredients,
      BusinessModule.tableManagement,
      BusinessModule.kitchenDisplay,
      BusinessModule.splitBill,
      BusinessModule.dailyDigest,
    },
    'retail': {
      BusinessModule.pos,
      BusinessModule.inventory,
      BusinessModule.variants,
      BusinessModule.wholesalePrice,
      BusinessModule.ppob,
      BusinessModule.restockB2B,
      BusinessModule.dailyDigest,
    },
  };

  static Set<BusinessModule> getModules(String outletType) {
    return _outletModules[outletType.toLowerCase()] ??
        _outletModules['kelontong']!;
  }

  static bool isEnabled(String outletType, BusinessModule module) {
    return getModules(outletType).contains(module);
  }
}

final activeModulesProvider =
    Provider.family<Set<BusinessModule>, String>((ref, outletId) {
  final outletType = ref.watch(outletTypeProvider(outletId));
  return ModuleConfig.getModules(outletType);
});

final isModuleEnabledProvider =
    Provider.family<bool, ({String outletId, BusinessModule module})>(
        (ref, arg) {
  final modules = ref.watch(activeModulesProvider(arg.outletId));
  return modules.contains(arg.module);
});
