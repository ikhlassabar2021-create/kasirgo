import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../config/supabase_config.dart';
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

      if (userId == null) {
        // No authenticated (or anonymous) session available.
        // Anonymous sign-in is disabled on this project, so require login.
        return null;
      }

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
            id: userId,
            email: authUser!.email ?? '',
            name: outletName,
            role: 'owner',
            outletId: outletId,
            createdAt: DateTime.tryParse(authUser.createdAt),
          );
        }
      } catch (_) {}

      final existingRole = await _client
          .from('user_roles')
          .select('*, outlets(*)')
          .eq('user_id', userId);

      final roleList = (existingRole as List).cast<Map<String, dynamic>>();
      final roleRow = roleList.isNotEmpty ? roleList.first : null;

      if (roleRow != null) {
        return User(
          id: userId,
          email: authUser?.email ?? '',
          name: roleRow['name'] as String?,
          role: roleRow['role'] as String? ?? 'owner',
          outletId: roleRow['outlet_id'] as String?,
          createdAt: DateTime.tryParse(authUser?.createdAt ?? ''),
        );
      }

      return User(
        id: userId,
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
        final anonUser = await initializeAnonymousOnboarding();
        final sessionUser = _client.auth.currentUser;
        if (anonUser != null &&
            (anonUser.outletId == null || anonUser.outletId!.isEmpty) &&
            sessionUser != null) {
          // Ensure anonymous session also has a valid outlet row (with owner_id)
          try {
            final owned = await _client
                .from('outlets')
                .select('id')
                .eq('owner_id', sessionUser.id)
                .limit(1)
                .maybeSingle();
            if (owned != null) {
              return anonUser.copyWith(outletId: owned['id'].toString());
            }
            final newOutlet = await _client
                .from('outlets')
                .insert({
                  'owner_id': sessionUser.id,
                  'name': 'Warung Saya',
                  'type': 'kelontong',
                })
                .select()
                .single();
            return anonUser.copyWith(outletId: newOutlet['id'].toString());
          } catch (_) {
            return anonUser;
          }
        }
        return anonUser;
      }

      // 1. Try to find existing user_roles
      final rolesResponse = await _client
          .from('user_roles')
          .select('*, outlets(*)')
          .eq('user_id', authUser.id);

      final roles = (rolesResponse as List).cast<Map<String, dynamic>>();
      if (roles.isNotEmpty) {
        // Prefer a staff role (admin/cashier/kitchen); otherwise use owner row.
        Map<String, dynamic>? chosen;
        for (final r in roles) {
          final role = r['role']?.toString();
          if (role == 'admin' || role == 'cashier' || role == 'kitchen') {
            chosen = r;
            break;
          }
        }
        chosen ??= roles.firstWhere(
          (r) => r['outlet_id'] != null,
          orElse: () => roles.first,
        );

        if (chosen['outlet_id'] != null) {
          return User(
            id: authUser.id,
            email: authUser.email ?? '',
            name: chosen['name'] as String? ?? (chosen['outlets']?['name'] as String?),
            role: chosen['role'] as String? ?? 'owner',
            outletId: chosen['outlet_id'] as String?,
            createdAt: DateTime.tryParse(authUser.createdAt),
          );
        }
      }

      // 2. If no role or outlet_id is null, find outlet owned by this user
      final ownedOutlet = await _client
          .from('outlets')
          .select('*')
          .eq('owner_id', authUser.id)
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (ownedOutlet != null) {
        final outletId = ownedOutlet['id'] as String;
        final outletName = ownedOutlet['name'] as String? ?? 'Warung Saya';
        return User(
          id: authUser.id,
          email: authUser.email ?? '',
          name: outletName,
          role: 'owner',
          outletId: outletId,
          createdAt: DateTime.tryParse(authUser.createdAt),
        );
      }

      // 3. Fallback: if user is logged in but has no outlet yet, create one
      try {
        final meta = authUser.userMetadata ?? {};
        final businessName = meta['business_name'] as String? ?? 'Warung Saya';
        final businessType = meta['business_type'] as String? ?? 'kelontong';

        final newOutlet = await _client
            .from('outlets')
            .insert({
              'owner_id': authUser.id,
              'name': businessName,
              'type': businessType,
            })
            .select()
            .single();

        final newOutletId = newOutlet['id'] as String;
        return User(
          id: authUser.id,
          email: authUser.email ?? '',
          name: businessName,
          role: 'owner',
          outletId: newOutletId,
          createdAt: DateTime.tryParse(authUser.createdAt),
        );
      } catch (_) {}

      return User(
        id: authUser.id,
        email: authUser.email ?? '',
        name: authUser.userMetadata?['business_name']?.toString() ?? 'Warung Saya',
        role: 'owner',
        outletId: null,
        createdAt: DateTime.tryParse(authUser.createdAt),
      );
    } catch (_) {
      return null;
    }
  }

  static String getAuthRedirectUrl() {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      var path = Uri.base.path;
      if (!path.endsWith('/')) {
        path = '$path/';
      }
      return '$origin$path';
    }
    return 'https://ikhlassabar2021-create.github.io/kasirgo/';
  }

  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: getAuthRedirectUrl(),
      );
    } catch (_) {
      rethrow;
    }
  }

  Future<void> linkAccountWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: getAuthRedirectUrl(),
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
    Map<String, dynamic>? kycData,
  }) async {
    try {
      final data = <String, dynamic>{
        'business_name': businessName,
        'business_type': businessType,
      };
      if (kycData != null && kycData.isNotEmpty) {
        data['kyc_nik'] = kycData['nik'];
        data['kyc_full_name'] = kycData['fullName'];
        data['kyc_phone'] = kycData['phone'];
        data['kyc_status'] = 'pending';
      }

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: data,
        emailRedirectTo: getAuthRedirectUrl(),
      );

      if (kycData != null && kycData.isNotEmpty && response.user != null) {
        // Insert KYC record into database if table exists
        try {
          await _client.from('outlet_kyc').insert({
            'owner_nik': kycData['nik'],
            'owner_full_name': kycData['fullName'],
            'owner_phone': kycData['phone'],
            'kyc_status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }

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

  /// Membuat akun login staf (admin/kasir).
  ///
  /// Prioritas: Edge Function `create_staff` (via service role, akun langsung
  /// terkonfirmasi tanpa kirim email -> bebas rate limit). Jika function belum
  /// dideploy, fallback ke `signUp` biasa.
  ///
  /// Mengembalikan user id staf, atau null jika gagal.
  Future<String?> createStaffAccount({
    required String email,
    required String password,
    required String outletId,
    required String role,
    String? name,
  }) async {
    if (outletId.trim().isEmpty) {
      throw Exception(
          'Outlet belum siap. Pastikan tipe usaha sudah dipilih di dashboard, lalu coba lagi.');
    }

    final staffEmail = email.trim();

    // 1) Coba Edge Function (disarankan).
    try {
      final res = await _client.functions.invoke(
        'create_staff',
        body: {
          'email': staffEmail,
          'password': password,
          'outlet_id': outletId,
          'role': role,
          if (name != null && name.isNotEmpty) 'name': name,
        },
      );
      final data = res.data;
      if (data is Map && data['user_id'] is String) {
        return await _ensureStaffRole(
            data['user_id'] as String, outletId, role);
      }
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
    } on FunctionException catch (e) {
      // 404 = function belum dideploy -> fallback ke signUp.
      final status = e.status;
      final details = e.details?.toString() ?? e.toString();
      if (status == 404 ||
          details.contains('not found') ||
          details.contains('Failed to fetch')) {
        // lanjut ke fallback di bawah
      } else {
        throw Exception(_friendlyStaffError(details));
      }
    } catch (e) {
      final msg = e.toString();
      if (!(msg.contains('404') ||
          msg.contains('not found') ||
          msg.contains('Failed to fetch') ||
          msg.contains('FunctionException'))) {
        throw Exception(_friendlyStaffError(msg));
      }
    }

    // 2) Fallback: signUp biasa (butuh Confirm email OFF / kuota email).
    final tempClient = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.anonKey,
    );

    final response = await tempClient.auth.signUp(
      email: staffEmail,
      password: password,
      data: {
        'staff_email': staffEmail,
        'staff_role': role,
        'outlet_id': outletId,
        if (name != null && name.isNotEmpty) 'staff_name': name,
      },
      emailRedirectTo: getAuthRedirectUrl(),
    );

    final staffUserId = response.user?.id;
    if (staffUserId != null) {
      return await _ensureStaffRole(staffUserId, outletId, role);
    }
    return null;
  }

  Future<String?> _ensureStaffRole(
    String userId,
    String outletId,
    String role,
  ) async {
    try {
      await _client.from('user_roles').upsert(
        {
          'user_id': userId,
          'outlet_id': outletId,
          'role': role,
        },
        onConflict: 'user_id,outlet_id',
      );
    } catch (_) {
      try {
        await _client
            .from('user_roles')
            .delete()
            .eq('user_id', userId)
            .eq('outlet_id', outletId);
      } catch (_) {}
      await _client.from('user_roles').insert({
        'user_id': userId,
        'outlet_id': outletId,
        'role': role,
      });
    }
    return userId;
  }

  String _friendlyStaffError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('rate limit') ||
        msg.contains('429') ||
        msg.contains('over_email')) {
      return 'Kuota email Supabase habis. Tunggu ~1 jam, atau minta admin '
          'mendeploy Edge Function "create_staff" / menonaktifkan Confirm email.';
    }
    if (msg.contains('sudah terdaftar') || msg.contains('already')) {
      return 'Email sudah terdaftar. Gunakan email lain.';
    }
    return raw;
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
