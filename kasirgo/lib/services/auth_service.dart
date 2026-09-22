import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _deviceUuidKey = 'kasirgo_device_uuid';

  SupabaseClient get client => _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<String> getOrCreateDeviceUuid() async {
    try {
      final existingUuid = await _storage.read(key: _deviceUuidKey);
      if (existingUuid != null && existingUuid.isNotEmpty) {
        return existingUuid;
      }
    } catch (_) {}

    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // RFC4122 v4
    values[8] = (values[8] & 0x3f) | 0x80; // variant
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    final newUuid = buffer.toString();
    try {
      await _storage.write(key: _deviceUuidKey, value: newUuid);
    } catch (_) {}
    return newUuid;
  }

  Future<User?> initializeAnonymousOnboarding() async {
    try {
      final deviceUuid = await getOrCreateDeviceUuid();

      if (_client.auth.currentUser == null) {
        try {
          await _client.auth.signInAnonymously();
        } catch (_) {}
      }

      final authUser = _client.auth.currentUser;
      final userId = authUser?.id;

      try {
        final response = await _client.functions.invoke(
          'onboard_merchant',
          body: {
            'device_uuid': deviceUuid,
            'store_name': 'Warung Saya',
            'outlet_type': 'kelontong',
          },
        );

        final data = response.data;
        if (data is Map && data['outlet'] != null) {
          final outlet = data['outlet'] as Map;
          final outletId = outlet['id'] as String?;
          final outletName = outlet['name'] as String? ?? 'Warung Saya';
          return User(
            id: userId ?? deviceUuid,
            email: authUser?.email ?? '',
            name: outletName,
            role: 'owner',
            outletId: outletId,
            createdAt: authUser != null
                ? DateTime.tryParse(authUser.createdAt)
                : DateTime.now(),
          );
        }
      } catch (_) {}

      if (userId != null) {
        final existingRole = await _client
            .from('user_roles')
            .select('*, outlets(*)')
            .eq('user_id', userId)
            .maybeSingle();

        if (existingRole != null) {
          return User(
            id: userId,
            email: authUser?.email ?? '',
            name: existingRole['name'] as String?,
            role: existingRole['role'] as String? ?? 'owner',
            outletId: existingRole['outlet_id'] as String?,
            createdAt: DateTime.tryParse(authUser?.createdAt ?? ''),
          );
        }
      }

      return User(
        id: userId ?? deviceUuid,
        email: authUser?.email ?? '',
        name: 'Warung Saya',
        role: 'owner',
        outletId: null,
        createdAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final authUser = _client.auth.currentUser;
      if (authUser == null) {
        return await initializeAnonymousOnboarding();
      }

      final response = await _client
          .from('user_roles')
          .select('*, outlets(*)')
          .eq('user_id', authUser.id)
          .maybeSingle();

      if (response != null) {
        return User(
          id: authUser.id,
          email: authUser.email ?? '',
          name: response['name'] as String?,
          role: response['role'] as String? ?? 'cashier',
          outletId: response['outlet_id'] as String?,
          createdAt: DateTime.tryParse(authUser.createdAt),
        );
      }

      return await initializeAnonymousOnboarding();
    } catch (_) {
      return null;
    }
  }

  Future<User?> linkAccountWithPhone({
    required String phone,
    required String token,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      if (response.user != null) {
        return await getCurrentUser();
      }
      return null;
    } catch (_) {
      rethrow;
    }
  }

  Future<void> linkAccountWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'kasirgo://login-callback',
      );
    } catch (_) {
      rethrow;
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String businessName,
    required String businessType,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'business_name': businessName,
          'business_type': businessType,
        },
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<String?> getUserRole(String userId) async {
    try {
      final response = await _client
          .from('user_roles')
          .select('role')
          .eq('user_id', userId)
          .single();

      return response['role'] as String?;
    } catch (e) {
      return null;
    }
  }
}
