import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/buyer_profile.dart';

/// Akun Pembeli disimpan LOKAL di perangkat (SharedPreferences).
///
/// Tidak dikirim ke server. Dipakai untuk autofill checkout dan halaman
/// Profil. Kebijakan: "buyer data tersimpan LOKAL saja".
class BuyerProfileService {
  static const String _key = 'buyer_profile_v1';

  Future<BuyerProfile?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final profile = BuyerProfile.fromJson(map);
      return profile.isEmpty ? null : profile;
    } catch (e) {
      debugPrint('BuyerProfileService.load error: $e');
      return null;
    }
  }

  Future<void> save(BuyerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
