import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_customer.dart';
import 'auth_service.dart';

/// ST17-4 (Phase 17 - Ekosistem Hyper-Local): identitas Pembeli.
///
/// Pembeli memakai Supabase ANONYMOUS auth (tanpa email/password) lalu
/// disimpan sebagai baris `app_customers`. Consent UU PDP (lokasi + nohp)
/// disimpan LOKAL di perangkat.
class AppCustomerService {
  AppCustomerService({SupabaseClient? client, AuthService? authService})
      : _client = client ?? Supabase.instance.client,
        _auth = authService ?? AuthService(client: client);

  final SupabaseClient _client;
  final AuthService _auth;

  static const String _consentLocationKey = 'buyer_consent_location';
  static const String _consentPhoneKey = 'buyer_consent_phone';

  SupabaseClient get client => _client;

  String? get _uid => _client.auth.currentUser?.id;

  bool get isSignedIn => _uid != null;

  /// Pembeli anonim (tanpa email) yang sedang aktif.
  bool get isAnonymous => _client.auth.currentUser?.isAnonymous ?? false;

  String _normalizePhone(String raw) {
    var s = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (s.startsWith('+')) s = s.substring(1);
    if (s.startsWith('0')) s = '62${s.substring(1)}';
    return s;
  }

  /// Pastikan ada sesi (anonymous) sebelum mengakses data pembeli.
  Future<bool> ensureSession() async {
    if (_client.auth.currentUser != null) return true;
    try {
      await _client.auth.signInAnonymously();
    } catch (e) {
      debugPrint('AppCustomerService.ensureSession error: $e');
    }
    return _client.auth.currentUser != null;
  }

  /// Baris `app_customers` milik sesi saat ini (null bila belum terdaftar).
  Future<AppCustomer?> currentCustomer() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final res = await _client
          .from('app_customers')
          .select()
          .eq('auth_uid', uid)
          .maybeSingle();
      if (res == null) return null;
      return AppCustomer.fromJson(res);
    } catch (e) {
      debugPrint('AppCustomerService.currentCustomer error: $e');
      return null;
    }
  }

  /// Daftar / perbarui profil Pembeli (onboarding zero-friction).
  Future<AppCustomer?> register({
    required String name,
    required String phone,
  }) async {
    if (!await ensureSession()) return null;
    final uid = _uid;
    if (uid == null) return null;

    final deviceUuid = await _auth.getOrCreateDeviceUuid();
    final payload = <String, dynamic>{
      'auth_uid': uid,
      'name': name.trim(),
      'phone': _normalizePhone(phone),
      'device_uuid': deviceUuid,
      'last_seen': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final res = await _client
          .from('app_customers')
          .upsert(payload, onConflict: 'auth_uid')
          .select()
          .single();
      return AppCustomer.fromJson(res);
    } catch (e) {
      debugPrint('AppCustomerService.register error: $e');
      return null;
    }
  }

  /// Perbarui nama/nomor tanpa mengubah consent.
  Future<AppCustomer?> updateProfile({
    required String name,
    required String phone,
  }) =>
      register(name: name, phone: phone);

  Future<void> touchLastSeen() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('app_customers').update({
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }).eq('auth_uid', uid);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // CONSENT (UU PDP) - disimpan lokal
  // ---------------------------------------------------------------------------

  Future<bool> getLocationConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentLocationKey) ?? false;
  }

  Future<bool> getPhoneConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentPhoneKey) ?? false;
  }

  Future<void> setConsent({required bool location, required bool phone}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentLocationKey, location);
    await prefs.setBool(_consentPhoneKey, phone);
  }

  Future<void> clearConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_consentLocationKey);
    await prefs.remove(_consentPhoneKey);
  }

  // ---------------------------------------------------------------------------
  // SESSION
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('AppCustomerService.signOut error: $e');
    }
  }
}
