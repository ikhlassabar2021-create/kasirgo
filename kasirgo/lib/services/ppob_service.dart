import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ppob.dart';

/// Config PPOB dari Control Plane (platform_configs 'ppob', scope global).
/// Superadmin atur provider + api_key + margin tanpa ubah koding.
class PpobConfig {
  final String provider;
  final String apiKey;
  final String endpoint;
  final double marginPercent;

  const PpobConfig({
    this.provider = 'demo',
    this.apiKey = '',
    this.endpoint = '',
    this.marginPercent = 5,
  });

  bool get isDemoMode => provider == 'demo' || apiKey.trim().isEmpty;

  static const fallback = PpobConfig();

  factory PpobConfig.fromMap(Map<String, dynamic> m) {
    double d(dynamic v) =>
        v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);
    return PpobConfig(
      provider: m['provider']?.toString() ?? 'demo',
      apiKey: m['api_key']?.toString() ?? '',
      endpoint: m['endpoint']?.toString() ?? '',
      marginPercent: d(m['margin_percent']),
    );
  }
}

/// Hasil inquiry: produk + harga jual otomatis (modal + margin%).
class PpobInquiry {
  final PpobProduct product;
  final double sellPrice;
  final double costPrice;
  final double profit;
  final String? error;

  const PpobInquiry({
    required this.product,
    required this.sellPrice,
    required this.costPrice,
    required this.profit,
    this.error,
  });

  bool get isValid => error == null;
}

/// Service PPOB (Phase 9 / ST9-1).
///
/// - Harga jual = modal (cost_price) + margin% dari config -> OTOMATIS,
///   bukan hardcode; margin diatur superadmin via Control Plane.
/// - Mode demo (tanpa api_key): transaksi langsung sukses dengan
///   provider_ref DEMO-... sehingga alur owner bisa diuji tanpa biaya.
/// - Mode provider nyata: transaksi dibuat pending + refreshStatus
///   (endpoint provider diisi superadmin; integrasi penuh menyusul ST9-2).
class PpobService {
  PpobService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _cacheKey = 'ppob_config_cache_v1';
  static const String _cacheTsKey = 'ppob_config_ts_v1';
  static const int _cacheTtlSeconds = 300;

  PpobConfig _config = PpobConfig.fallback;
  PpobConfig get config => _config;

  // ---------------------------------------------------------------------------
  // CONFIG (cache + fallback, offline-safe)
  // ---------------------------------------------------------------------------

  Future<PpobConfig> loadConfig({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_cacheTsKey) ?? 0;
    final fresh =
        DateTime.now().millisecondsSinceEpoch - ts < _cacheTtlSeconds * 1000;

    if (!forceRefresh) {
      if (fresh) {
        final cached = prefs.getString(_cacheKey);
        if (cached != null) {
          try {
            _config = PpobConfig.fromMap(
                Map<String, dynamic>.from(jsonDecode(cached) as Map));
            return _config;
          } catch (_) {}
        }
      }
    }

    try {
      final res = await _client
          .from('platform_configs')
          .select('value')
          .eq('key', 'ppob')
          .eq('scope', 'global')
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null && res['value'] != null) {
        final value =
            PpobConfig.fromMap(Map<String, dynamic>.from(res['value'] as Map));
        _config = value;
        await prefs.setString(_cacheKey, jsonEncode({
          'provider': value.provider,
          'api_key': value.apiKey,
          'endpoint': value.endpoint,
          'margin_percent': value.marginPercent,
        }));
        await prefs.setInt(_cacheTsKey, DateTime.now().millisecondsSinceEpoch);
        return _config;
      }
    } catch (e) {
      debugPrint('PpobService.loadConfig error: $e');
    }

    // Fallback: config lama di cache (walau basi) -> default.
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        _config = PpobConfig.fromMap(
            Map<String, dynamic>.from(jsonDecode(cached) as Map));
        return _config;
      } catch (_) {}
    }
    _config = PpobConfig.fallback;
    return _config;
  }

  // ---------------------------------------------------------------------------
  // HARGA JUAL OTOMATIS (modal + margin%)
  // ---------------------------------------------------------------------------

  double sellPriceFor(PpobProduct product, {PpobConfig? cfg}) {
    final c = cfg ?? _config;
    if (product.sellPrice != null && product.sellPrice! > 0) {
      return product.sellPrice!;
    }
    final cost = product.costPrice ?? 0;
    return cost + (cost * c.marginPercent / 100);
  }

  // ---------------------------------------------------------------------------
  // INQUIRY (validasi tujuan per kategori)
  // ---------------------------------------------------------------------------

  String? validateRef(String category, String ref) {
    final v = ref.trim();
    if (v.isEmpty) return 'Tujuan belum diisi';
    switch (category) {
      case 'pulsa':
      case 'data':
        final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length < 10 || digits.length > 13) {
          return 'Nomor HP tidak valid (10-13 digit)';
        }
        if (!digits.startsWith('08') && !digits.startsWith('628')) {
          return 'Nomor HP harus diawali 08 atau 628';
        }
        return null;
      case 'pln':
        final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length < 10 || digits.length > 12) {
          return 'ID Pelanggan PLN tidak valid (10-12 digit)';
        }
        return null;
      case 'game':
        if (v.length < 4) return 'ID akun game tidak valid';
        return null;
      case 'e-money':
        if (v.length < 6) return 'Nomor kartu/akun tidak valid';
        return null;
      default:
        return null;
    }
  }

  Future<PpobInquiry> inquire(PpobProduct product, String customerRef) async {
    await loadConfig();
    return inquireSync(product, customerRef);
  }

  /// Versi sinkron (dipakai UI saat user mengetik; config sudah dimuat).
  PpobInquiry inquireSync(PpobProduct product, String customerRef) {
    final error = validateRef(product.category ?? '', customerRef);
    final sell = sellPriceFor(product);
    final cost = product.costPrice ?? 0;
    return PpobInquiry(
      product: product,
      sellPrice: sell,
      costPrice: cost,
      profit: sell - cost,
      error: error,
    );
  }

  // ---------------------------------------------------------------------------
  // TRANSAKSI
  // ---------------------------------------------------------------------------

  /// Buat transaksi PPOB. Mode demo -> langsung success.
  /// Mode provider nyata -> pending + refreshStatus.
  Future<PpobTransaction?> purchase({
    required String outletId,
    required String userId,
    required PpobProduct product,
    required String customerRef,
    required String paymentMethod,
    String? note,
  }) async {
    final inquiry = await inquire(product, customerRef);
    if (!inquiry.isValid) return null;
    await loadConfig();

    final isDemo = _config.isDemoMode;
    final tx = PpobTransaction(
      id: '',
      outletId: outletId,
      userId: userId,
      ppobProductId: product.id,
      productName: product.name,
      customerRef: customerRef.trim(),
      amount: inquiry.sellPrice,
      costAmount: inquiry.costPrice,
      profit: inquiry.profit,
      status: 'pending',
      paymentMethod: paymentMethod,
      providerRef: null,
      note: note,
      createdAt: DateTime.now(),
    );

    try {
      var saved = await _client
          .from('ppob_transactions')
          .insert(tx.toJson())
          .select()
          .single();
      var result = PpobTransaction.fromJson(saved);

      if (isDemo) {
        // Demo: sukses instan (tanpa biaya), provider_ref jelas sumbernya.
        result = await updateStatus(
          result.id,
          'success',
          'DEMO-${DateTime.now().millisecondsSinceEpoch}',
        );
        return result;
      }

      // Provider nyata: kirim ke endpoint (jika diatur). Gagal kirim -> pending.
      await _submitToProvider(result);
      return await getById(result.id);
    } catch (e) {
      debugPrint('PpobService.purchase error: $e');
      return null;
    }
  }

  Future<void> _submitToProvider(PpobTransaction tx) async {
    if (_config.endpoint.trim().isEmpty) return;
    try {
      final res = await _client.functions.invoke(
        _config.endpoint.trim(),
        body: {
          'type': 'ppob_purchase',
          'transaction_id': tx.id,
          'product_id': tx.ppobProductId,
          'customer_ref': tx.customerRef,
          'amount': tx.costAmount,
        },
      );
      final data = res.data;
      if (data is Map && data['status'] != null) {
        await updateStatus(
          tx.id,
          data['status'].toString(),
          data['provider_ref']?.toString(),
        );
      }
    } catch (e) {
      debugPrint('PpobService._submitToProvider error: $e');
    }
  }

  Future<PpobTransaction?> getById(String id) async {
    try {
      final res = await _client
          .from('ppob_transactions')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (res == null) return null;
      return PpobTransaction.fromJson(res);
    } catch (e) {
      debugPrint('PpobService.getById error: $e');
      return null;
    }
  }

  Future<PpobTransaction> updateStatus(
      String id, String status, String? providerRef) async {
    final res = await _client
        .from('ppob_transactions')
        .update({
          'status': status,
          if (providerRef != null) 'provider_ref': providerRef,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return PpobTransaction.fromJson(res);
  }

  // ---------------------------------------------------------------------------
  // KATALOG & RIWAYAT
  // ---------------------------------------------------------------------------

  Future<List<PpobProduct>> getProducts({String? category}) async {
    try {
      var query = _client.from('ppob_products').select().eq('is_active', true);
      if (category != null && category != 'all') {
        query = query.eq('category', category);
      }
      final res = await query.order('category').order('cost_price');
      return (res as List)
          .map((j) => PpobProduct.fromJson(j))
          .toList();
    } catch (e) {
      debugPrint('PpobService.getProducts error: $e');
      return [];
    }
  }

  Future<List<String>> getCategories() async {
    try {
      final res = await _client
          .from('ppob_products')
          .select('category')
          .eq('is_active', true);
      final set = <String>{};
      for (final row in (res as List)) {
        final c = row['category']?.toString();
        if (c != null && c.isNotEmpty) set.add(c);
      }
      final order = ['pulsa', 'data', 'pln', 'game', 'e-money'];
      final sorted = order.where(set.contains).toList();
      for (final extra in set) {
        if (!sorted.contains(extra)) sorted.add(extra);
      }
      return sorted;
    } catch (e) {
      debugPrint('PpobService.getCategories error: $e');
      return [];
    }
  }

  Future<List<PpobTransaction>> getHistory(String outletId,
      {int limit = 50}) async {
    try {
      final res = await _client
          .from('ppob_transactions')
          .select()
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (res as List)
          .map((j) => PpobTransaction.fromJson(j))
          .toList();
    } catch (e) {
      debugPrint('PpobService.getHistory error: $e');
      return [];
    }
  }

  /// Rekap periode (untuk laporan margin PPOB). Hanya status success.
  Future<Map<String, double>> getSummary(
      String outletId, DateTime start, DateTime end) async {
    try {
      final res = await _client
          .from('ppob_transactions')
          .select('amount, cost_amount, profit')
          .eq('outlet_id', outletId)
          .eq('status', 'success')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());
      double sales = 0, cost = 0, profit = 0;
      for (final row in (res as List)) {
        double d(dynamic v) => v is num
            ? v.toDouble()
            : (double.tryParse(v?.toString() ?? '') ?? 0);
        sales += d(row['amount']);
        cost += d(row['cost_amount']);
        profit += d(row['profit']);
      }
      return {'sales': sales, 'cost': cost, 'profit': profit};
    } catch (e) {
      debugPrint('PpobService.getSummary error: $e');
      return {'sales': 0, 'cost': 0, 'profit': 0};
    }
  }
}
