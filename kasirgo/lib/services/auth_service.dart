import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  SupabaseClient get client => _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<User?> getCurrentUser() async {
    try {
      final authUser = _client.auth.currentUser;
      if (authUser == null) return null;

      final response = await _client
          .from('user_roles')
          .select('*, outlets(*)')
.eq('user_id', authUser.id)
        .maybeSingle();

      if (response == null) return null;

      return User(
        id: authUser.id,
        email: authUser.email ?? '',
        name: response['name'] as String?,
        role: response['role'] as String? ?? 'cashier',
        outletId: response['outlet_id'] as String?,
        createdAt: DateTime.tryParse(authUser.createdAt),
      );
    } catch (e) {
      return null;
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