import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Order pembayaran QRIS (disimpan di tabel `payment_orders`).
class PgPaymentOrder {
  final String? dbId;
  final String rcbOrderId;
  final String? externalId;
  final double amount;
  final double totalAmount;
  final int? kodeUnik;
  final String status;
  final String? paymentUrl;
  final String? qrisUrl;
  final String? qrisString;
  final String? paymentType;
  final DateTime? expiredAt;

  const PgPaymentOrder({
    required this.rcbOrderId,
    this.dbId,
    this.externalId,
    required this.amount,
    required this.totalAmount,
    this.kodeUnik,
    required this.status,
    this.paymentUrl,
    this.qrisUrl,
    this.qrisString,
    this.paymentType,
    this.expiredAt,
  });

  bool get isPaid => status.toUpperCase() == 'PAID';

  factory PgPaymentOrder.fromApi(Map<String, dynamic> json, {String? dbId}) {
    final data = (json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final orderId = (data['order_id'] ?? data['rcb_order_id'] ?? json['order_id'] ?? '').toString();
    final expired = data['expired_time'] ?? data['expired_at'];
    return PgPaymentOrder(
      dbId: dbId,
      rcbOrderId: orderId,
      externalId: (data['external_id'] ?? '').toString(),
      amount: _toDouble(data['amount']),
      totalAmount: _toDouble(data['total_amount'] ?? data['amount']),
      kodeUnik: (data['kode_unik'] as num?)?.toInt(),
      status: (data['status'] ?? json['status'] ?? 'PENDING').toString(),
      paymentUrl: data['payment_url']?.toString(),
      qrisUrl: (data['qris_url'] ?? data['qris_image_url'] ?? data['qr_url'])?.toString(),
      qrisString: (data['qris_string'] ?? data['qr_code'])?.toString(),
      paymentType: data['payment_type']?.toString(),
      expiredAt: _toDate(expired),
    );
  }

  static double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is num) return DateTime.fromMillisecondsSinceEpoch((v * 1000).toInt());
    return DateTime.tryParse(v.toString());
  }
}

/// Payment Gateway (RCB Pay).
///
/// Mode `sandbox_direct`: aplikasi memanggil RCB langsung memakai API key
/// sandbox (dari `get_pg_client_config`). HANYA untuk testing.
/// Mode lain (produksi): panggilan dialihkan ke Edge Function `rcb_create_charge`.
class PaymentService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _cacheKey = 'pg_client_config_v1';
  Map<String, dynamic>? _cfg;

  Future<Map<String, dynamic>> loadConfig({bool force = false}) async {
    if (_cfg != null && !force) return _cfg!;
    try {
      final res = await _client.rpc('get_pg_client_config');
      if (res is Map) {
        final map = res.cast<String, dynamic>();
        _cfg = map;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(map));
        return map;
      }
    } catch (_) {
      // offline / gagal: pakai cache
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        _cfg = (jsonDecode(raw) as Map).cast<String, dynamic>();
        return _cfg!;
      }
    } catch (_) {}
    return _cfg = const {};
  }

  bool get isDirectSandbox =>
      (_cfg?['mode']?.toString() == 'sandbox_direct') &&
      ((_cfg?['api_key']?.toString() ?? '').isNotEmpty);

  /// Buat tagihan QRIS. Mengembalikan order + data QR untuk ditampilkan.
  Future<PgPaymentOrder> createQris({
    required String outletId,
    required double amount,
    String itemName = 'Pembayaran KasirGo',
    String? externalId,
    String purpose = 'pos',
    String? supporterId,
    String? transactionId,
    String? callbackUrl,
  }) async {
    final cfg = await loadConfig(force: true);
    if (cfg['enabled'] != true) {
      throw Exception('Payment gateway belum aktif di Control Plane.');
    }

    final mode = cfg['mode']?.toString() ?? '';
    final external = externalId ?? 'KGO-${DateTime.now().millisecondsSinceEpoch}';

    if (mode == 'sandbox_direct' && (cfg['api_key']?.toString() ?? '').isNotEmpty) {
      return _createDirect(
        cfg: cfg,
        outletId: outletId,
        amount: amount,
        itemName: itemName,
        externalId: external,
        purpose: purpose,
        supporterId: supporterId,
        transactionId: transactionId,
        callbackUrl: callbackUrl,
      );
    }
    return _createViaEdge(
      outletId: outletId,
      amount: amount,
      itemName: itemName,
      externalId: external,
      purpose: purpose,
      supporterId: supporterId,
      transactionId: transactionId,
      callbackUrl: callbackUrl,
    );
  }

  Future<PgPaymentOrder> _createDirect({
    required Map<String, dynamic> cfg,
    required String outletId,
    required double amount,
    required String itemName,
    required String externalId,
    required String purpose,
    String? supporterId,
    String? transactionId,
    String? callbackUrl,
  }) async {
    final baseUrl = cfg['base_url']?.toString() ?? '';
    final apiKey = cfg['api_key']?.toString() ?? '';
    final uri = Uri.parse('$baseUrl/gateway/create');

    final body = <String, dynamic>{
      'amount': amount.round(),
      'item_name': itemName.length > 50 ? itemName.substring(0, 50) : itemName,
      'external_id': externalId,
    };
    if (callbackUrl != null && callbackUrl.isNotEmpty) {
      body['callback_url'] = callbackUrl;
    }

    final resp = await http
        .post(uri,
            headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 35));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Gagal membuat QRIS (${resp.statusCode}): ${resp.body}');
    }
    final json = (jsonDecode(resp.body) as Map).cast<String, dynamic>();
    if (json['success'] != true) {
      throw Exception(json['message']?.toString() ?? 'Gagal membuat QRIS.');
    }

    final order = PgPaymentOrder.fromApi(json);
    final dbId = await _persistOrder(
      outletId: outletId,
      order: order,
      purpose: purpose,
      supporterId: supporterId,
      transactionId: transactionId,
      raw: json,
    );
    return PgPaymentOrder(
      dbId: dbId,
      rcbOrderId: order.rcbOrderId,
      externalId: order.externalId,
      amount: order.amount,
      totalAmount: order.totalAmount,
      kodeUnik: order.kodeUnik,
      status: order.status,
      paymentUrl: order.paymentUrl,
      qrisUrl: order.qrisUrl,
      qrisString: order.qrisString,
      paymentType: order.paymentType,
      expiredAt: order.expiredAt,
    );
  }

  Future<PgPaymentOrder> _createViaEdge({
    required String outletId,
    required double amount,
    required String itemName,
    required String externalId,
    required String purpose,
    String? supporterId,
    String? transactionId,
    String? callbackUrl,
  }) async {
    final res = await _client.functions.invoke('rcb_create_charge', body: {
      'outlet_id': outletId,
      'amount': amount.round(),
      'item_name': itemName,
      'external_id': externalId,
      'purpose': purpose,
      'supporter_id': ?supporterId,
      'transaction_id': ?transactionId,
      'callback_url': ?callbackUrl,
    });
    final data = (res.data is Map) ? (res.data as Map).cast<String, dynamic>() : <String, dynamic>{};
    if (data['success'] != true) {
      throw Exception(data['message']?.toString() ?? 'Gagal membuat QRIS.');
    }
    return PgPaymentOrder.fromApi(data);
  }

  Future<String?> _persistOrder({
    required String outletId,
    required PgPaymentOrder order,
    required String purpose,
    String? supporterId,
    String? transactionId,
    required Map<String, dynamic> raw,
  }) async {
    try {
      final row = await _client
          .from('payment_orders')
          .insert({
            'outlet_id': outletId,
            'created_by': _client.auth.currentUser?.id,
            'purpose': purpose,
            'provider': 'rcb',
            'rcb_order_id': order.rcbOrderId,
            'external_id': order.externalId,
            'amount': order.amount,
            'total_amount': order.totalAmount,
            'kode_unik': order.kodeUnik,
            'status': order.status.toUpperCase(),
            'payment_url': order.paymentUrl,
            'qris_url': order.qrisUrl,
            'qris_string': order.qrisString,
            'payment_type': order.paymentType,
            'transaction_id': transactionId,
            'supporter_id': supporterId,
            'expired_at': order.expiredAt?.toIso8601String(),
            'raw': raw,
          })
          .select('id')
          .maybeSingle();
      return row?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Cek status order (polling). Mengembalikan status huruf besar.
  Future<String> checkStatus(String rcbOrderId) async {
    final cfg = await loadConfig();
    final mode = cfg['mode']?.toString() ?? '';
    if (mode == 'sandbox_direct' && (cfg['api_key']?.toString() ?? '').isNotEmpty) {
      final baseUrl = cfg['base_url']?.toString() ?? '';
      final apiKey = cfg['api_key']?.toString() ?? '';
      try {
        final resp = await http.get(
          Uri.parse('$baseUrl/payment-status/$rcbOrderId'),
          headers: {'x-api-key': apiKey},
        ).timeout(const Duration(seconds: 20));
        final json = (jsonDecode(resp.body) as Map).cast<String, dynamic>();
        final data = (json['data'] is Map) ? (json['data'] as Map) : json;
        return (data['status'] ?? json['status'] ?? 'PENDING').toString().toUpperCase();
      } catch (_) {
        return 'PENDING';
      }
    }
    try {
      final res = await _client.functions.invoke('rcb_check_status', body: {
        'order_id': rcbOrderId,
      });
      final data = (res.data is Map) ? (res.data as Map) : const {};
      return (data['status'] ?? 'PENDING').toString().toUpperCase();
    } catch (_) {
      return 'PENDING';
    }
  }

  /// Tandai order PAID (hasil polling) + aktivasi langganan bila perlu.
  Future<void> confirmPaid(String rcbOrderId, {String status = 'PAID'}) async {
    try {
      await _client.rpc('confirm_pg_order', params: {
        'p_rcb_order_id': rcbOrderId,
        'p_status': status,
      });
    } catch (_) {
      // best-effort: status tetap tersimpan di sisi RCB.
    }
  }

  // ---------------------------------------------------------------------------
  // Kompatibilitas lama
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> createCharge({
    required String orderId,
    required double amount,
    required String qrisType,
    String outletId = '',
    String itemName = 'Pembayaran KasirGo',
  }) async {
    if (qrisType == 'static') {
      return {'status': 'success', 'mode': 'static'};
    }
    try {
      final order = await createQris(
        outletId: outletId,
        amount: amount,
        itemName: itemName,
        externalId: orderId,
      );
      return {
        'status': 'success',
        'mode': 'dynamic',
        'order': order,
        'order_id': order.rcbOrderId,
        'payment_url': order.paymentUrl,
        'qris_url': order.qrisUrl,
        'qris_string': order.qrisString,
        'total_amount': order.totalAmount,
      };
    } catch (e) {
      return {'error': e.toString(), 'status': 'failed'};
    }
  }

  Map<String, dynamic> getFinancialConfig() {
    return {
      'min_payment': 1000.0,
      'max_payment': 1000000.0,
      'free_threshold': 50000.0,
    };
  }
}
