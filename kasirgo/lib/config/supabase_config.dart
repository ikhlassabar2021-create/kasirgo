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
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxtdmplY2R2ZnpzbXJvd3d3cGNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxMjk3MjgsImV4cCI6MjEwNDcwNTcyOH0.6waUmz-Kj32gGuxBs4DutgBDQtsSljazTuJQw_qZstI';

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