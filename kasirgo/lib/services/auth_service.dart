import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AppUser?> signUp(String email, String password, String businessName, String businessType) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'business_name': businessName, 'business_type': businessType},
    );
    if (response.user != null) {
      return AppUser.fromJson(response.user!.toJson());
    }
    return null;
  }

  Future<AppUser?> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(email: email, password: password);
    if (response.user != null) {
      return AppUser.fromJson(response.user!.toJson());
    }
    return null;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  AppUser? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return AppUser.fromJson(user.toJson());
  }

  Future<String?> getUserRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await _client.from('user_roles').select('role').eq('user_id', user.id).single();
      return data['role'];
    } catch (_) {
      final outlet = await _client.from('outlets').select('id').eq('owner_id', user.id).maybeSingle();
      if (outlet != null) return 'owner';
      return null;
    }
  }

  Future<String?> getUserOutletId() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final role = await _client.from('user_roles').select('outlet_id').eq('user_id', user.id).single();
      return role['outlet_id'];
    } catch (_) {
      final outlet = await _client.from('outlets').select('id').eq('owner_id', user.id).maybeSingle();
      return outlet?['id'];
    }
  }
}