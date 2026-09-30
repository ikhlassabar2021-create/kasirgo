import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Config B2B Restock dari Control Plane (platform_configs 'b2b_restock',
/// scope global). Link distributor + komisi diubah superadmin TANPA ubah
/// koding. `enabled=false` atau URL kosong -> fitur tampil nonaktif.
class B2bConfig {
  final bool enabled;
  final String distributorUrl;
  final String distributorName;
  final double commissionPercent;
  final List<String> allowedDomains;

  const B2bConfig({
    this.enabled = false,
    this.distributorUrl = '',
    this.distributorName = 'Distributor B2B',
    this.commissionPercent = 2,
    this.allowedDomains = const [],
  });

  bool get isReady => enabled && distributorUrl.trim().isNotEmpty;

  /// Domain yang boleh dibuka WebView (domain lock / anti-bypass).
  Set<String> get hosts {
    final hosts = <String>{};
    final main = Uri.tryParse(distributorUrl.trim())?.host;
    if (main != null && main.isNotEmpty) {
      hosts.add(main);
      hosts.add('www.$main');
    }
    for (final d in allowedDomains) {
      final h = d.trim().toLowerCase();
      if (h.isEmpty) continue;
      hosts.add(h);
      if (!h.startsWith('www.')) hosts.add('www.$h');
    }
    return hosts;
  }

  static const fallback = B2bConfig();

  factory B2bConfig.fromMap(Map<String, dynamic> m) {
    double d(dynamic v) =>
        v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);
    return B2bConfig(
      enabled: m['enabled'] is bool ? m['enabled'] as bool : false,
      distributorUrl: m['distributor_url']?.toString() ?? '',
      distributorName: m['distributor_name']?.toString() ?? 'Distributor B2B',
      commissionPercent: d(m['commission_percent']),
      allowedDomains: (m['allowed_domains'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// Service B2B Restock (Phase 9 / ST9-3).
class B2bService {
  B2bService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  B2bConfig _config = B2bConfig.fallback;
  B2bConfig get config => _config;

  Future<B2bConfig> loadConfig() async {
    try {
      final res = await _client
          .from('platform_configs')
          .select('value')
          .eq('key', 'b2b_restock')
          .eq('scope', 'global')
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null && res['value'] != null) {
        _config =
            B2bConfig.fromMap(Map<String, dynamic>.from(res['value'] as Map));
      }
    } catch (e) {
      debugPrint('B2bService.loadConfig error: $e');
    }
    return _config;
  }

  /// tracking_id unik per order (ikut di URL distributor untuk atribusi).
  String buildTrackingId(String outletId) {
    final prefix = outletId.length >= 8
        ? outletId.substring(0, 8).toUpperCase()
        : outletId.toUpperCase().padRight(8, '0');
    return 'RST-$prefix-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// URL katalog distributor + parameter tracking (tanpa ubah koding).
  String buildCatalogUrl(String url, String outletId, String trackingId) {
    final uri = Uri.parse(url.trim());
    final params = Map<String, String>.from(uri.queryParameters);
    params['ref'] = outletId;
    params['tracking_id'] = trackingId;
    return uri.replace(queryParameters: params).toString();
  }

  double commissionFor(double amount, {B2bConfig? cfg}) {
    final c = cfg ?? _config;
    return amount * c.commissionPercent / 100;
  }

  /// Rekap restock periode (laporan owner + WA ke bos).
  Future<Map<String, double>> getSummary(
      String outletId, DateTime start, DateTime end) async {
    try {
      final res = await _client
          .from('restock_orders')
          .select('amount, commission')
          .eq('outlet_id', outletId)
          .inFilter('status', ['pending', 'confirmed', 'shipped', 'completed'])
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());
      double total = 0, commission = 0;
      for (final row in (res as List)) {
        double d(dynamic v) => v is num
            ? v.toDouble()
            : (double.tryParse(v?.toString() ?? '') ?? 0);
        total += d(row['amount']);
        commission += d(row['commission']);
      }
      return {'total': total, 'commission': commission};
    } catch (e) {
      debugPrint('B2bService.getSummary error: $e');
      return {'total': 0, 'commission': 0};
    }
  }
}
