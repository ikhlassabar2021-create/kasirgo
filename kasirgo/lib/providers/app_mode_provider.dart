import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_customer.dart';
import '../models/app_mode.dart';
import '../services/app_customer_service.dart';
import '../services/app_mode_service.dart';

/// ST17-4 (Phase 17 - Ekosistem Hyper-Local): provider mode ganda + pembeli.

final appModeServiceProvider =
    Provider<AppModeService>((ref) => AppModeService());

class AppModeNotifier extends StateNotifier<AppMode?> {
  AppModeNotifier(this._service)
      : super(_service.cachedMode ?? AppModeService.lastLoaded);

  final AppModeService _service;

  Future<void> load() async {
    state = await _service.loadMode();
  }

  Future<void> select(AppMode mode) async {
    await _service.saveMode(mode);
    state = mode;
  }

  Future<void> clear() async {
    await _service.clear();
    state = null;
  }
}

final appModeProvider =
    StateNotifierProvider<AppModeNotifier, AppMode?>((ref) {
  return AppModeNotifier(ref.watch(appModeServiceProvider));
});

final appCustomerServiceProvider =
    Provider<AppCustomerService>((ref) => AppCustomerService());

/// Profil Pembeli aktif (null = belum onboarding).
final appCustomerProvider = FutureProvider<AppCustomer?>((ref) async {
  final service = ref.watch(appCustomerServiceProvider);
  await service.ensureSession();
  return service.currentCustomer();
});
