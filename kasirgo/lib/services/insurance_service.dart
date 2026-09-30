import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Produk asuransi mikro dari config superadmin.
class InsuranceProduct {
  final String code;
  final String name;
  final String type; // toko, kebakaran, barang, lainnya
  final double premi;
  final double coverage;
  final String? note;

  const InsuranceProduct({
    required this.code,
    required this.name,
    required this.type,
    required this.premi,
    required this.coverage,
    this.note,
  });

  factory InsuranceProduct.fromMap(Map<String, dynamic> m) {
    double d(dynamic v) =>
        v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);
    return InsuranceProduct(
      code: m['code']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      type: m['type']?.toString() ?? 'toko',
      premi: d(m['premi']),
      coverage: d(m['coverage']),
      note: m['note']?.toString(),
    );
  }
}

class InsuranceConfig {
  final bool enabled;
  final String partnerName;
  final String applyUrl;
  final String waNumber;
  final double commissionPercent;
  final List<InsuranceProduct> products;

  const InsuranceConfig({
    this.enabled = true,
    this.partnerName = 'Mitra Asuransi Mikro KasirGo',
    this.applyUrl = '',
    this.waNumber = '',
    this.commissionPercent = 10,
    this.products = const [],
  });

  String? get applyChannel {
    if (applyUrl.trim().isNotEmpty) return applyUrl.trim();
    final wa = waNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (wa.isNotEmpty) return 'https://wa.me/$wa';
    return null;
  }

  static const fallback = InsuranceConfig();

  factory InsuranceConfig.fromMap(Map<String, dynamic> m) {
    double d(dynamic v) =>
        v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);
    return InsuranceConfig(
      enabled: m['enabled'] is bool ? m['enabled'] as bool : true,
      partnerName: m['partner_name']?.toString() ??
          'Mitra Asuransi Mikro KasirGo',
      applyUrl: m['apply_url']?.toString() ?? '',
      waNumber: m['wa_number']?.toString() ?? '',
      commissionPercent: d(m['commission_percent']),
      products: (m['products'] as List? ?? const [])
          .whereType<Map>()
          .map((p) => InsuranceProduct.fromMap(
              Map<String, dynamic>.from(p)))
          .toList(),
    );
  }
}

/// Service Micro-Insurance (Phase 10 / ST10-3).
/// Produk + premi dari platform_integrations/config partner; komisi
/// platform dihitung otomatis untuk rekap superadmin.
class InsuranceService {
  InsuranceService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  InsuranceConfig _config = InsuranceConfig.fallback;
  InsuranceConfig get config => _config;

  Future<InsuranceConfig> loadConfig() async {
    try {
      final res = await _client
          .from('platform_configs')
          .select('value')
          .eq('key', 'insurance')
          .eq('scope', 'global')
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null && res['value'] != null) {
        _config = InsuranceConfig.fromMap(
            Map<String, dynamic>.from(res['value'] as Map));
      }
    } catch (e) {
      debugPrint('InsuranceService.loadConfig error: $e');
    }
    return _config;
  }

  String buildRef() {
    final ts = DateTime.now();
    final ymd =
        '${ts.year.toString().substring(2)}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}';
    return 'ASR-$ymd-${(ts.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
  }

  String buildWaLink(
      String waNumber, String partnerName, String productName) {
    final wa = waNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final text = Uri.encodeComponent(
        'Halo $partnerName, saya ingin mengajukan asuransi mikro '
        '"$productName" untuk toko saya (diajukan via KasirGo).');
    return 'https://wa.me/$wa?text=$text';
  }

  double commissionFor(double premi, {InsuranceConfig? cfg}) {
    final c = cfg ?? _config;
    return premi * c.commissionPercent / 100;
  }

  Future<bool> submitLead({
    required String outletId,
    required String userId,
    required InsuranceProduct product,
    String? note,
  }) async {
    try {
      await _client.from('insurance_leads').insert({
        'outlet_id': outletId,
        'user_id': userId,
        'product_code': product.code,
        'product_name': product.name,
        'product_type': product.type,
        'premi': product.premi,
        'coverage_amount': product.coverage,
        'commission': commissionFor(product.premi),
        'status': 'apply',
        'ref': buildRef(),
        'note': ?note,
      });
      return true;
    } catch (e) {
      debugPrint('InsuranceService.submitLead error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getLeads(String outletId,
      {int limit = 30}) async {
    try {
      final res = await _client
          .from('insurance_leads')
          .select()
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('InsuranceService.getLeads error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPolicies(String outletId) async {
    try {
      final res = await _client
          .from('insurance_policies')
          .select()
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('InsuranceService.getPolicies error: $e');
      return [];
    }
  }

  /// Rekap platform untuk superadmin (fintech + asuransi, semua outlet).
  /// Wajib user terdaftar di admin_users (role superadmin, aktif).
  Future<Map<String, dynamic>?> getPlatformRevenueSummary() async {
    try {
      final res = await _client.rpc('platform_revenue_summary');
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (e) {
      debugPrint('InsuranceService.getPlatformRevenueSummary error: $e');
      return null;
    }
  }
}
