import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'payment_service.dart';

/// Model entitlement outlet (Program Pendukung + trial + fitur per-key).
class Entitlements {
  final String outletId;
  final bool isSupporter;
  final bool adFree;
  final Map<String, dynamic> features;
  final DateTime? trialEndsAt;
  final DateTime? supporterEndDate;
  final String status; // none | trial | active | expired | cancelled

  const Entitlements({
    required this.outletId,
    this.isSupporter = false,
    this.adFree = false,
    this.features = const {},
    this.trialEndsAt,
    this.supporterEndDate,
    this.status = 'none',
  });

  bool get isTrialActive =>
      trialEndsAt != null && DateTime.now().isBefore(trialEndsAt!);

  /// Akses premium terbuka bila status aktif atau sedang masa trial.
  bool get hasAccess => isSupporter || isTrialActive;

  int get trialDaysLeft {
    if (!isTrialActive) return 0;
    return trialEndsAt!.difference(DateTime.now()).inDays + 1;
  }

  Entitlements copyWith({
    bool? isSupporter,
    bool? adFree,
    Map<String, dynamic>? features,
    DateTime? trialEndsAt,
    DateTime? supporterEndDate,
    String? status,
  }) {
    return Entitlements(
      outletId: outletId,
      isSupporter: isSupporter ?? this.isSupporter,
      adFree: adFree ?? this.adFree,
      features: features ?? this.features,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      supporterEndDate: supporterEndDate ?? this.supporterEndDate,
      status: status ?? this.status,
    );
  }
}

class SupporterCheckoutResult {
  final String orderId;
  final bool success;
  final String? error;
  final Map<String, dynamic>? charge;
  final double amount;
  final int periodDays;
  final String status; // pending | pending_verification | failed
  final String? supporterId;
  final String? rcbOrderId;
  final String? qrisString;
  final String? qrisUrl;
  final String? paymentUrl;
  final double totalAmount;

  const SupporterCheckoutResult({
    required this.orderId,
    required this.success,
    this.error,
    this.charge,
    this.amount = 0,
    this.periodDays = 30,
    this.status = 'pending',
    this.supporterId,
    this.rcbOrderId,
    this.qrisString,
    this.qrisUrl,
    this.paymentUrl,
    this.totalAmount = 0,
  });

  /// Pembayaran QRIS dinamis (terverifikasi otomatis) tersedia.
  bool get hasDynamicQr =>
      (qrisString != null && qrisString!.isNotEmpty) ||
      (qrisUrl != null && qrisUrl!.isNotEmpty);
}

/// Service Program Pendukung KasirGo:
/// - baca harga/durasi dari config DB (cache + fallback)
/// - entitlement: is_supporter / ad_free / hasFeature(key)
/// - reverse trial 14 hari otomatis saat KYC verified
/// - simpan nomor WA owner (dari KYC) untuk wa.me
/// - checkout via QRIS existing
class SupporterService {
  SupporterService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<bool> _online() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.isNotEmpty && !r.contains(ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  static const int _cacheTtlSeconds = 300;

  static const Map<String, dynamic> fallbackBilling = {
    'supporter_price': 50000,
    'currency': 'IDR',
    'period': 'monthly',
    'trial_days': 14,
    'auto_renew_default': true,
  };

  static const Map<String, dynamic> fallbackAds = {
    'blocked_categories': ['judi', 'dewasa', 'pinjol'],
    'placement': ['catalog', 'qr_menu'],
    'ad_free_for_supporter': true,
    'consent_required': true,
    'creatives': <dynamic>[],
  };

  /// Fitur yang dibuka oleh Program Pendukung (sisanya gratis selamanya).
  static const Set<String> premiumFeatures = {
    'wa_marketing',
    'social_sync',
    'online_catalog',
    'qr_table',
    'ai_pro',
    'health_score_pro',
    'advanced_report',
    'export_excel',
    'export_pdf',
    'backup_cloud',
    'multi_outlet',
    'extra_staff',
    'custom_receipt',
  };

  static const Map<String, String> featureLabels = {
    'wa_marketing': 'WA Marketing (broadcast + retensi)',
    'social_sync': 'Social Commerce Sync',
    'online_catalog': 'Katalog Online',
    'qr_table': 'QR Meja Dine-in',
    'ai_pro': 'AI Co-Pilot Pro',
    'health_score_pro': 'Health Score Bisnis Pro',
    'advanced_report': 'Laporan Lanjutan',
    'export_excel': 'Export Excel',
    'export_pdf': 'Export PDF',
    'backup_cloud': 'Backup & Restore Cloud',
    'multi_outlet': 'Multi-Outlet',
    'extra_staff': 'Slot Staf Tambahan',
    'custom_receipt': 'Custom Struk / Logo',
  };

  // ---------------------------------------------------------------------------
  // CONFIG (platform_configs + fallback + cache SharedPreferences)
  // ---------------------------------------------------------------------------

  /// Ambil config grup Control Plane (ads/guide/report/kyc/quota/flags/billing).
  Future<Map<String, dynamic>> getConfig(
    String key, {
    Map<String, dynamic>? fallback,
  }) async {
    final fb = fallback ?? const <String, dynamic>{};
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'pcfg_$key';
    final tsKey = 'pcfg_ts_$key';

    final ts = prefs.getInt(tsKey) ?? 0;
    final isFresh =
        DateTime.now().millisecondsSinceEpoch - ts < _cacheTtlSeconds * 1000;
    final cached = prefs.getString(cacheKey);

    if (!isFresh && cached != null && cached.isNotEmpty) {
      try {
        final parsed = Map<String, dynamic>.from(jsonDecode(cached) as Map);
        return _merge(fb, parsed);
      } catch (_) {}
    }

    try {
      final res = await _client
          .from('platform_configs')
          .select('value, version')
          .eq('key', key)
          .eq('scope', 'global')
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null && res['value'] != null) {
        final value = Map<String, dynamic>.from(res['value'] as Map);
        await prefs.setString(cacheKey, jsonEncode(value));
        await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
        return _merge(fb, value);
      }
    } catch (_) {
      // tabel/config belum ada -> pakai cache/fallback
    }

    if (cached != null && cached.isNotEmpty) {
      try {
        return _merge(fb, Map<String, dynamic>.from(jsonDecode(cached) as Map));
      } catch (_) {}
    }
    return Map<String, dynamic>.from(fb);
  }

  Map<String, dynamic> _merge(Map<String, dynamic> base, Map<String, dynamic> over) {
    final out = Map<String, dynamic>.from(base);
    over.forEach((k, v) {
      if (v != null) out[k] = v;
    });
    return out;
  }

  /// Harga & durasi Program Pendukung (satu harga Rp50.000/bulan).
  Future<Map<String, dynamic>> getBillingConfig() async {
    // Prioritas: platform_configs('billing') -> platform_financial_configs -> default.
    final cfg = await getConfig('billing', fallback: fallbackBilling);
    if (cfg['supporter_price'] != null) return cfg;

    try {
      final res = await _client
          .from('platform_financial_configs')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null && res['supporter_price'] != null) {
        return _merge(fallbackBilling, Map<String, dynamic>.from(res));
      }
    } catch (_) {}
    return Map<String, dynamic>.from(fallbackBilling);
  }

  Future<Map<String, dynamic>> getAdsConfig() =>
      getConfig('ads', fallback: fallbackAds);

  // ---------------------------------------------------------------------------
  // ENTITLEMENTS
  // ---------------------------------------------------------------------------

  Future<Entitlements> getEntitlements(String outletId) async {
    final billing = await getBillingConfig();
    Entitlements ent = Entitlements(outletId: outletId);

    try {
      final res = await _client
          .from('entitlements')
          .select()
          .eq('outlet_id', outletId)
          .maybeSingle();
      if (res != null) {
        ent = Entitlements(
          outletId: outletId,
          isSupporter: res['is_supporter'] == true,
          adFree: res['ad_free'] == true,
          features: (res['features'] is Map)
              ? Map<String, dynamic>.from(res['features'] as Map)
              : const {},
          trialEndsAt: res['trial_ends_at'] != null
              ? DateTime.tryParse(res['trial_ends_at'].toString())
              : null,
        );
      }
    } catch (_) {}

    // Lengkapi status + end date dari tabel supporters (aktif terbaru).
    try {
      final sup = await _client
          .from('supporters')
          .select('tier, status, start_date, end_date')
          .eq('outlet_id', outletId)
          .order('start_date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (sup != null) {
        final status = (sup['status'] ?? '').toString();
        final end = sup['end_date'] != null
            ? DateTime.tryParse(sup['end_date'].toString())
            : null;
        final isActive = status == 'active' &&
            (end == null || DateTime.now().isBefore(end));
        ent = ent.copyWith(
          isSupporter: ent.isSupporter || isActive,
          status: ent.isTrialActive ? 'trial' : status,
          supporterEndDate: end,
          adFree: ent.adFree || isActive,
        );
      }
    } catch (_) {}

    if (ent.status == 'none' && ent.isTrialActive) ent = ent.copyWith(status: 'trial');
    // Trial memberi akses premium (ad_free mengikuti harga config).
    if (ent.isTrialActive && billing['ad_free_for_supporter'] != false) {
      ent = ent.copyWith(adFree: ent.adFree);
    }
    if (ent.isSupporter) {
      ent = ent.copyWith(adFree: true, status: ent.status == 'none' ? 'active' : ent.status);
    }
    return ent;
  }

  /// Gate fitur. Fitur non-premium selalu true.
  Future<bool> hasFeature(String outletId, String featureKey) async {
    if (!premiumFeatures.contains(featureKey)) return true;
    final ent = await getEntitlements(outletId);
    if (ent.hasAccess) return true;
    final override = ent.features[featureKey];
    return override == true;
  }

  Future<bool> isSupporter(String outletId) async =>
      (await getEntitlements(outletId)).hasAccess;

  /// Reverse trial: 14 hari otomatis setelah KYC verified (idempotent).
  /// Dijalankan server-side via RPC `ensure_supporter_trial` (RLS owner
  /// tidak boleh menulis supporters/entitlements langsung).
  Future<Entitlements> ensureTrial(String outletId) async {
    try {
      await _client.rpc('ensure_supporter_trial', params: {'p_outlet': outletId});
      await _invalidateCache();
    } catch (_) {}
    return getEntitlements(outletId);
  }

  Future<void> _invalidateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('ent_'));
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  Future<void> setAutoRenew(String outletId, bool value) async {
    try {
      await _client.rpc('set_supporter_auto_renew',
          params: {'p_outlet': outletId, 'p_value': value});
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // NOMOR WA OWNER (dari KYC) untuk wa.me
  // ---------------------------------------------------------------------------

  Future<void> saveOwnerWa(String outletId, String waNumber) async {
    final cleaned = _normalizePhone(waNumber);
    if (cleaned.isEmpty) return;
    try {
      await _client.from('outlets').update({'owner_wa_number': cleaned}).eq('id', outletId);
    } catch (_) {}
    try {
      await _client
          .from('outlet_kyc')
          .update({'phone': cleaned})
          .eq('outlet_id', outletId);
    } catch (_) {}
  }

  Future<String?> getOwnerWa(String outletId) async {
    try {
      final res = await _client
          .from('outlets')
          .select('owner_wa_number')
          .eq('id', outletId)
          .maybeSingle();
      final wa = res?['owner_wa_number']?.toString();
      if (wa != null && wa.isNotEmpty) return wa;
    } catch (_) {}
    try {
      final kyc = await _client
          .from('outlet_kyc')
          .select('phone')
          .eq('outlet_id', outletId)
          .maybeSingle();
      final p = kyc?['phone']?.toString();
      if (p != null && p.isNotEmpty) return _normalizePhone(p);
    } catch (_) {}
    return null;
  }

  String _normalizePhone(String raw) {
    var s = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (s.startsWith('+')) s = s.substring(1);
    if (s.startsWith('0')) s = '62${s.substring(1)}';
    return s;
  }

  // ---------------------------------------------------------------------------
  // CHECKOUT (QRIS existing)
  // ---------------------------------------------------------------------------

  Future<SupporterCheckoutResult> checkout({
    required String outletId,
    double? amount,
    String qrisType = 'static',
  }) async {
    final billing = await getBillingConfig();
    final price = amount ?? (billing['supporter_price'] as num?)?.toDouble() ?? 50000;
    final orderId = 'SUP-${DateTime.now().millisecondsSinceEpoch}';

    if (!await _online()) {
      return SupporterCheckoutResult(
          orderId: orderId, success: false, error: 'Tidak ada internet.');
    }

    try {
      final res = await _client.rpc('create_supporter_checkout', params: {
        'p_outlet': outletId,
        'p_order_id': orderId,
        'p_amount': price,
      });
      final map = (res as Map).cast<String, dynamic>();
      final supporterId = map['supporter_id']?.toString();
      final amount = (map['amount'] as num?)?.toDouble() ?? price;
      final periodDays = (map['period_days'] as num?)?.toInt() ?? 30;

      // Coba buat QRIS dinamis (RCB) agar pembayaran terverifikasi otomatis.
      try {
        final pgOrder = await PaymentService().createQris(
          outletId: outletId,
          amount: amount,
          itemName: 'Program Pendukung KasirGo',
          externalId: orderId,
          purpose: 'subscription',
          supporterId: supporterId,
        );
        return SupporterCheckoutResult(
          orderId: orderId,
          success: true,
          amount: amount,
          periodDays: periodDays,
          status: pgOrder.status.toLowerCase(),
          charge: map,
          supporterId: supporterId,
          rcbOrderId: pgOrder.rcbOrderId,
          qrisString: pgOrder.qrisString,
          qrisUrl: pgOrder.qrisUrl,
          paymentUrl: pgOrder.paymentUrl,
          totalAmount: pgOrder.totalAmount,
        );
      } catch (_) {
        // Fallback: QRIS statis/manual seperti sebelumnya.
      }

      return SupporterCheckoutResult(
        orderId: (map['order_id'] ?? orderId).toString(),
        success: true,
        amount: amount,
        periodDays: periodDays,
        status: (map['status'] ?? 'pending').toString(),
        charge: map,
        supporterId: supporterId,
      );
    } catch (e) {
      return SupporterCheckoutResult(
          orderId: orderId, success: false, error: e.toString());
    }
  }

  /// Owner menandai bahwa QRIS/transfer sudah dibayar -> tunggu verifikasi admin.
  Future<bool> confirmPaymentSent(String outletId, String orderId) async {
    try {
      await _client.rpc('confirm_supporter_payment',
          params: {'p_outlet': outletId, 'p_order_id': orderId});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Batalkan checkout yang masih menunggu pembayaran.
  Future<bool> cancelCheckout(String outletId, String orderId) async {
    try {
      await _client.rpc('cancel_supporter_checkout',
          params: {'p_outlet': outletId, 'p_order_id': orderId});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Checkout yang sedang menunggu (pembayaran / verifikasi admin), bila ada.
  Future<Map<String, dynamic>?> loadPendingCheckout(String outletId) async {
    try {
      final res = await _client
          .from('supporters')
          .select('id, amount, status, pg_reference_id, updated_at')
          .eq('outlet_id', outletId)
          .inFilter('status', ['pending', 'pending_verification'])
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return res == null ? null : Map<String, dynamic>.from(res);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static const List<String> allFeatureKeys = [
    'wa_marketing',
    'social_sync',
    'online_catalog',
    'qr_table',
    'ai_pro',
    'health_score_pro',
    'advanced_report',
    'export_excel',
    'export_pdf',
    'backup_cloud',
    'multi_outlet',
    'extra_staff',
    'custom_receipt',
  ];
}
