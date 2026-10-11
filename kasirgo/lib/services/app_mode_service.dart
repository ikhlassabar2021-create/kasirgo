import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_mode.dart';

/// ST17-4 (Phase 17 - Ekosistem Hyper-Local): simpan mode aplikasi (Penjual/Pembeli)
/// secara LOKAL di perangkat. Mode dibaca sebelum router menentukan layar awal.
class AppModeService {
  AppModeService({SharedPreferences? prefs}) {
    _prefs = prefs;
  }

  static const String _modeKey = 'kasirgo_app_mode';
  static const String _modeChosenKey = 'kasirgo_app_mode_chosen';

  /// Mode terakhir yang dimuat (cache statis lintas-instance) agar router dapat
  /// membacanya secara SINKRON saat bootstrap, sebelum Future selesai.
  static AppMode? lastLoaded;

  SharedPreferences? _prefs;
  AppMode? _cached;

  /// Mode terakhir yang dimuat (untuk akses sinkron saat bootstrap router).
  AppMode? get cachedMode => _cached;

  Future<SharedPreferences> get _preferences async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Mode tersimpan, null bila pengguna belum pernah memilih.
  Future<AppMode?> loadMode() async {
    final prefs = await _preferences;
    _cached = AppMode.fromStorage(prefs.getString(_modeKey));
    lastLoaded = _cached;
    return _cached;
  }

  /// Simpan mode terpilih + tandai bahwa pengguna sudah pernah memilih.
  Future<void> saveMode(AppMode mode) async {
    final prefs = await _preferences;
    await prefs.setString(_modeKey, mode.storageValue);
    await prefs.setBool(_modeChosenKey, true);
    _cached = mode;
    lastLoaded = mode;
  }

  /// Apakah pengguna sudah pernah memilih mode (untuk onboarding pertama kali).
  Future<bool> hasChosenMode() async {
    final prefs = await _preferences;
    return prefs.getBool(_modeChosenKey) ?? false;
  }

  /// Hapus pilihan mode (mis. saat logout total).
  Future<void> clear() async {
    final prefs = await _preferences;
    await prefs.remove(_modeKey);
    await prefs.remove(_modeChosenKey);
    _cached = null;
    lastLoaded = null;
  }
}
