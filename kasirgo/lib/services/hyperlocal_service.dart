import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction.dart';

/// Insight wilayah hasil penggabungan laporan ANONIM beberapa toko.
class RegionInsights {
  final String region;
  final String period;
  final int participantStores;
  final int txCount;
  final double totalOmzet;
  final double avgBasket;
  final Map<int, int> busyHours; // jam -> jumlah transaksi
  final List<String> topProducts;
  final List<String> topCategories;

  const RegionInsights({
    required this.region,
    required this.period,
    this.participantStores = 0,
    this.txCount = 0,
    this.totalOmzet = 0,
    this.avgBasket = 0,
    this.busyHours = const {},
    this.topProducts = const [],
    this.topCategories = const [],
  });
}

/// Service Hyperlocal Data (Phase 10 / ST10-2).
///
/// PRIVASI (UU PDP): hanya AGREGAT ANONIM - tidak ada nama/nomor pelanggan.
/// Kirim opt-in (consent owner disimpan lokal), tulis via RPC definer.
class HyperlocalService {
  HyperlocalService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _consentPrefix = 'hyperlocal_consent_';

  /// Config superadmin (platform_configs 'hyperlocal'). Default aktif;
  /// consent owner tetap ditanyakan terpisah (UU PDP).
  Future<bool> loadConfig() async {
    try {
      final res = await _client
          .from('platform_configs')
          .select('value')
          .eq('key', 'hyperlocal')
          .eq('scope', 'global')
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null && res['value'] is Map) {
        final m = res['value'] as Map;
        return m['enabled'] is bool ? m['enabled'] as bool : true;
      }
    } catch (e) {
      debugPrint('HyperlocalService.loadConfig error: $e');
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // CONSENT (opt-in owner, UU PDP)
  // ---------------------------------------------------------------------------

  Future<bool> getConsent(String outletId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_consentPrefix$outletId') ?? false;
  }

  Future<void> setConsent(String outletId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_consentPrefix$outletId', value);
  }

  // ---------------------------------------------------------------------------
  // AGREGAT ANONIM (tanpa PII)
  // ---------------------------------------------------------------------------

  String currentPeriod() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Bangun payload agregat dari transaksi bulan berjalan.
  /// Hanya angka + nama produk/kategori - TANPA data pelanggan.
  Map<String, dynamic> buildAggregate(List<Transaction> transactions) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final txs = transactions
        .where((t) => t.createdAt.isAfter(monthStart))
        .toList();

    double totalOmzet = 0;
    final hours = <int, int>{};
    final productQty = <String, int>{};
    final productOmzet = <String, double>{};
    for (final t in txs) {
      totalOmzet += t.finalAmount;
      hours[t.createdAt.hour] = (hours[t.createdAt.hour] ?? 0) + 1;
      for (final item in t.items) {
        productQty[item.productName] =
            (productQty[item.productName] ?? 0) + item.quantity;
        productOmzet[item.productName] =
            (productOmzet[item.productName] ?? 0) + item.subtotal;
      }
    }

    String topOf(Map<String, num> m) {
      final sorted = m.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.take(5).map((e) => e.key).join(', ');
    }

    return {
      'tx_count': txs.length,
      'total_omzet': totalOmzet,
      'avg_basket': txs.isEmpty ? 0 : totalOmzet / txs.length,
      'busy_hours': hours,
      'top_products': topOf(productQty),
      'top_products_omzet': topOf(productOmzet),
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // KIRIM & BACA (opt-in)
  // ---------------------------------------------------------------------------

  /// Kirim laporan bulan berjalan (via RPC, paksa anonim di DB).
  Future<bool> submit({
    required String outletId,
    required String region,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _client.rpc('hyperlocal_submit', params: {
        'p_outlet': outletId,
        'p_region': region,
        'p_period': currentPeriod(),
        'p_payload': payload,
      });
      return true;
    } catch (e) {
      debugPrint('HyperlocalService.submit error: $e');
      return false;
    }
  }

  /// Insight wilayah: gabungkan laporan anonim region pada periode terbaru.
  Future<RegionInsights> getRegionInsights(String region) async {
    final r = region.trim().toLowerCase();
    final empty = RegionInsights(region: region, period: currentPeriod());
    if (r.isEmpty) return empty;
    try {
      final res = await _client
          .from('hyperlocal_reports')
          .select()
          .ilike('region', region.trim())
          .order('created_at', ascending: false)
          .limit(50);

      final rows = (res as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return empty;

      // Ambil laporan periode terbaru saja.
      final period = rows.first['period']?.toString() ?? currentPeriod();
      final same = rows
          .where((row) => row['period']?.toString() == period)
          .toList();

      int txCount = 0;
      double totalOmzet = 0;
      final outlets = <String>{};
      final busyHours = <int, int>{};
      final productQty = <String, int>{};

      for (final row in same) {
        if (row['is_anonymous'] != true) continue;
        final payload = row['payload'];
        if (payload is! Map) continue;
        outlets.add(row['outlet_id']?.toString() ?? '');
        double d(dynamic v) => v is num
            ? v.toDouble()
            : (double.tryParse(v?.toString() ?? '') ?? 0);
        txCount += (payload['tx_count'] as num?)?.toInt() ?? 0;
        totalOmzet += d(payload['total_omzet']);
        final hours = payload['busy_hours'];
        if (hours is Map) {
          hours.forEach((k, v) {
            final h = int.tryParse(k.toString());
            if (h != null) busyHours[h] = (busyHours[h] ?? 0) + ((v as num).toInt());
          });
        }
        final tops = payload['top_products']?.toString() ?? '';
        for (final p in tops.split(',')) {
          final name = p.trim();
          if (name.isNotEmpty) {
            productQty[name] = (productQty[name] ?? 0) + 1;
          }
        }
      }

      final ranked = productQty.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return RegionInsights(
        region: region.trim(),
        period: period,
        participantStores: outlets.where((e) => e.isNotEmpty).length,
        txCount: txCount,
        totalOmzet: totalOmzet,
        avgBasket: txCount == 0 ? 0 : totalOmzet / txCount,
        busyHours: busyHours,
        topProducts: ranked.take(5).map((e) => e.key).toList(),
      );
    } catch (e) {
      debugPrint('HyperlocalService.getRegionInsights error: $e');
      return empty;
    }
  }
}
