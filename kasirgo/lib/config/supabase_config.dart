import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureLocalStorage extends LocalStorage {
  final _storage = const FlutterSecureStorage();

  const SecureLocalStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    final token = await _storage.read(key: supabasePersistSessionKey);
    return token != null;
  }

  @override
  Future<String?> accessToken() async {
    return await _storage.read(key: supabasePersistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(
      key: supabasePersistSessionKey,
      value: persistSessionString,
    );
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: supabasePersistSessionKey);
  }
}

class SupabaseConfig {
  static const String url = 'https://lmvjecdvfzsmrowwwpck.supabase.co';
  static const String anonKey =
      'sb_publishable_8RJnG66i_37cih8GTG1sBA_0B91KOW_';

  /// URL dasar aplikasi (dipakai untuk deep-link QR meja & redirect auth).
  static String get appUrl {
    try {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.contains('localhost')) {
        var path = Uri.base.path;
        if (!path.endsWith('/')) path = '$path/';
        return '$origin$path';
      }
    } catch (_) {}
    return 'https://ikhlassabar2021-create.github.io/kasirgo/';
  }

  /// Deep-link pesan mandiri per meja (QR Meja).
  static String tableUrl(String outletId, String table) =>
      '$appUrl#/customer?outlet=$outletId&table=${Uri.encodeComponent(table)}';

  /// Deep-link katalog online publik (mode tanpa meja).
  static String catalogUrl(String outletId) =>
      '$appUrl#/catalog?outlet=$outletId';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureLocalStorage(),
      ),
    );
  }
}