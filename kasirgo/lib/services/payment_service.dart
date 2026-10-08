import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Order pembayaran QRIS (disimpan di tabel `payment_orders`).
class PgPaymentOrder {
  final String? dbId;
  final String providerOrderId;
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
    required this.providerOrderId,
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
    final orderId = (data['order_id'] ??
            data['provider_order_id'] ??
            json['order_id'] ??
            json['provider_ref'] ??
            '')
        .toString();
    final expired = data['expiry_time'] ?? data['expired_time'] ?? data['expired_at'];
    return PgPaymentOrder(
      dbId: dbId,
      providerOrderId: orderId,
      externalId: (data['external_id'] ?? orderId).toString(),
      amount: _toDouble(data['amount'] ?? data['gross_amount']),
      totalAmount: _toDouble(data['total_amount'] ?? data['gross_amount'] ?? data['amount']),
      kodeUnik: (data['kode_unik'] as num?)?.toInt(),
      status: (data['status'] ?? json['status'] ?? 'PENDING').toString(),
      paymentUrl: (data['payment_url'] ?? data['redirect_url'])?.toString(),
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

/// Parameter pembuatan tagihan QRIS dinamis.
class PgCreateQrisRequest {
  final String outletId;
  final double amount;
  final String itemName;
  final String externalId;
  final String purpose;
  final String? supporterId;
  final String? transactionId;
  final String? callbackUrl;

  const PgCreateQrisRequest({
    required this.outletId,
    required this.amount,
    required this.itemName,
    required this.externalId,
    required this.purpose,
    this.supporterId,
    this.transactionId,
    this.callbackUrl,
  });
}

/// Kontrak provider payment gateway (zero-custody: kredensial hanya di server).
///
/// Implementasi saat ini: [MidtransProvider]. Menambah provider lain cukup
/// dengan mengimplementasikan antarmuka ini tanpa mengubah UI pemanggil.
abstract class PgProviderClient {
  String get providerId;

  Future<PgPaymentOrder> createQris(PgCreateQrisRequest request);

  /// Status order huruf besar (PENDING/PAID/EXPIRED/FAILED).
  Future<String> checkStatus(String providerOrderId);

  /// Tandai order lunas. Untuk provider berbasis webhook (Midtrans) ini
  /// best-effort: sumber kebenaran adalah webhook server.
  Future<void> confirmPaid(String providerOrderId, {String status = 'PAID'});
}

/// Provider Midtrans (QRIS dinamis, zero-custody).
///
/// Aplikasi TIDAK PERNAH menyimpan/melihat Server Key. Pembuatan charge
/// dialihkan ke Edge Function `create_payment`; status dibaca dari tabel
/// `payment_orders` yang diperbarui oleh webhook `midtrans_webhook`.
class MidtransProvider implements PgProviderClient {
  MidtransProvider(this._client);

  final SupabaseClient _client;

  @override
  String get providerId => 'midtrans';

  @override
  Future<PgPaymentOrder> createQris(PgCreateQrisRequest request) async {
    final data = await _invokeEf(_client, 'create_payment', {
      'outlet_id': request.outletId,
      'amount': request.amount.round(),
      'item_name': request.itemName,
      'external_id': request.externalId,
      'purpose': request.purpose,
      'supporter_id': ?request.supporterId,
      'transaction_id': ?request.transactionId,
      'callback_url': ?request.callbackUrl,
    });
    if (data['success'] != true) {
      throw Exception(data['message']?.toString() ?? 'Gagal membuat QRIS.');
    }
    return PgPaymentOrder.fromApi(data);
  }

  @override
  Future<String> checkStatus(String providerOrderId) async {
    try {
      final row = await _client
          .from('payment_orders')
          .select('status')
          .or('provider_order_id.eq.$providerOrderId,external_id.eq.$providerOrderId')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row != null && row['status'] != null) {
        return row['status'].toString().toUpperCase();
      }
    } catch (_) {
      // offline / gagal: biarkan status PENDING.
    }
    return 'PENDING';
  }

  @override
  Future<void> confirmPaid(String providerOrderId, {String status = 'PAID'}) async {
    // Midtrans memverifikasi via webhook (SHA512) dan langsung menandai
    // payment_orders + transaksi + aktivasi langganan. Tidak ada aksi klien.
    return;
  }
}

/// Provider RCB Pay (PT Raga Cipta Bersama), zero-custody.
///
/// Kredensial (x-api-key) HANYA ada di server (`platform_integrations`).
/// Pembuatan charge dialihkan ke Edge Function `rcb_create_charge`; status
/// dicek via `rcb_check_status`; sumber kebenaran tetap webhook `rcb_webhook`.
class RcbProvider implements PgProviderClient {
  RcbProvider(this._client);

  final SupabaseClient _client;

  @override
  String get providerId => 'rcb';

  @override
  Future<PgPaymentOrder> createQris(PgCreateQrisRequest request) async {
    final data = await _invokeEf(_client, 'rcb_create_charge', {
      'outlet_id': request.outletId,
      'amount': request.amount.round(),
      'item_name': request.itemName,
      'external_id': request.externalId,
      'purpose': request.purpose,
      'supporter_id': ?request.supporterId,
      'transaction_id': ?request.transactionId,
      'callback_url': ?request.callbackUrl,
    });
    if (data['success'] != true) {
      throw Exception(data['message']?.toString() ?? 'Gagal membuat QRIS RCB.');
    }
    return PgPaymentOrder.fromApi(data);
  }

  @override
  Future<String> checkStatus(String providerOrderId) async {
    // 1) Status otoritatif dari webhook (tabel payment_orders).
    try {
      final row = await _client
          .from('payment_orders')
          .select('status')
          .or('rcb_order_id.eq.$providerOrderId,provider_order_id.eq.$providerOrderId,'
              'external_id.eq.$providerOrderId')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final local = row?['status']?.toString().toUpperCase();
      if (local == 'PAID' || local == 'EXPIRED' || local == 'FAILED') return local!;
    } catch (_) {
      // offline / gagal: lanjut cek server.
    }
    // 2) Tanya server (polling bila webhook belum tiba, mis. mode sandbox).
    try {
      final data = await _invokeEf(
          _client, 'rcb_check_status', {'order_id': providerOrderId});
      final status = data['status']?.toString().toUpperCase();
      if (status != null && status.isNotEmpty) return status;
    } catch (_) {}
    return 'PENDING';
  }

  @override
  Future<void> confirmPaid(String providerOrderId, {String status = 'PAID'}) async {
    // Tandai order PAID + aktivasi langganan (idempoten). Webhook tetap
    // sumber kebenaran; ini jalur polling bila webhook belum diterima.
    try {
      await _client.rpc('confirm_pg_order', params: {
        'p_rcb_order_id': providerOrderId,
        'p_status': status,
      });
    } catch (_) {
      // best-effort.
    }
  }
}

/// Facade Payment Gateway. Memilih provider aktif (saat ini Midtrans) dan
/// menyediakan helper config non-secret untuk UI.
class PaymentService {
  PaymentService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _cacheKey = 'financial_config_v1';
  static const String _pgProviderCacheKey = 'pg_provider_v1';
  Map<String, dynamic>? _finCache;

  /// Provider aktif ('rcb' | 'midtrans'), dibaca dari Control Plane
  /// (`platform_integrations.payment_gateway`) via RPC `get_pg_client_config`.
  /// Fallback aman: 'rcb' (default aplikasi). Bisa diubah superadmin tanpa kode.
  String _activeProviderId() => _pgProviderCache ?? 'rcb';
  String? _pgProviderCache;

  /// Muat provider aktif dari server sekali per sesi (cache in-memory + prefs).
  Future<String> _resolveProviderId() async {
    if (_pgProviderCache != null) return _pgProviderCache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_pgProviderCacheKey);
      if (cached != null && cached.isNotEmpty) _pgProviderCache = cached;
    } catch (_) {}
    try {
      final res = await _client.rpc('get_pg_client_config');
      if (res is Map) {
        final pid = (res['provider']?.toString() ?? '').toLowerCase();
        if (pid == 'midtrans' || pid == 'rcb') {
          _pgProviderCache = pid;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_pgProviderCacheKey, pid);
          } catch (_) {}
        }
      }
    } catch (_) {}
    return _activeProviderId();
  }

  PgProviderClient _providerFor(String providerId) =>
      providerId == 'midtrans' ? MidtransProvider(_client) : RcbProvider(_client);

  /// Buat tagihan QRIS dinamis. Mengembalikan order + data QR.
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
    final external = externalId ?? 'KGO-${DateTime.now().millisecondsSinceEpoch}';
    final provider = _providerFor(await _resolveProviderId());
    return provider.createQris(PgCreateQrisRequest(
      outletId: outletId,
      amount: amount,
      itemName: itemName,
      externalId: external,
      purpose: purpose,
      supporterId: supporterId,
      transactionId: transactionId,
      callbackUrl: callbackUrl,
    ));
  }

  /// Cek status order (polling). Mengembalikan status huruf besar.
  Future<String> checkStatus(String providerOrderId) async =>
      _providerFor(await _resolveProviderId()).checkStatus(providerOrderId);

  /// Tandai order PAID (best-effort; webhook adalah sumber kebenaran).
  Future<void> confirmPaid(String providerOrderId, {String status = 'PAID'}) async =>
      _providerFor(await _resolveProviderId())
          .confirmPaid(providerOrderId, status: status);

  /// Simpan kredensial Midtrans outlet. Server Key dikirim ke Edge Function
  /// (disimpan terenkripsi di Vault) dan TIDAK pernah dikembalikan ke klien.
  /// Kosongkan [serverKey] untuk mempertahankan key yang sudah ada.
  Future<Map<String, dynamic>> savePaymentConfig({
    required String outletId,
    String merchantId = '',
    String clientKey = '',
    String serverKey = '',
    bool isProduction = false,
  }) async {
    final data = await _invokeEf(_client, 'save_payment_config', {
      'outlet_id': outletId,
      'merchant_id': merchantId,
      'client_key': clientKey,
      'server_key': serverKey,
      'is_production': isProduction,
    });
    if (data['success'] != true) {
      throw Exception(
          data['message']?.toString() ?? 'Gagal menyimpan konfigurasi Midtrans.');
    }
    return (data['config'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  /// Uji kredensial Midtrans tanpa efek samping (probe status).
  Future<Map<String, dynamic>> testPaymentConnection(String outletId) async {
    final data = await _invokeEf(_client, 'test_payment_connection', {
      'outlet_id': outletId,
    });
    if (data['success'] != true) {
      throw Exception(
          data['message']?.toString() ?? 'Gagal menguji koneksi Midtrans.');
    }
    return data;
  }

  /// Baca konfigurasi PG outlet (ter-mask, tanpa Server Key).
  Future<Map<String, dynamic>> loadProviderConfig(String outletId) async {
    try {
      final res = await _client.rpc('get_outlet_payment_config',
          params: {'p_outlet': outletId});
      if (res is Map) return res.cast<String, dynamic>();
    } catch (_) {}
    return const {
      'provider': 'midtrans',
      'configured': false,
      'has_server_key': false,
      'is_production': false,
      'status': 'pending',
    };
  }

  /// Batas & ambang biaya QRIS dari Control Plane (fallback aman bila offline).
  Future<Map<String, dynamic>> getFinancialConfig() async {
    if (_finCache != null) return _finCache!;
    try {
      final res = await _client.rpc('get_financial_config');
      if (res is Map) {
        final m = res.cast<String, dynamic>();
        final cfg = <String, dynamic>{
          'min_payment': (m['min_qris_amount'] as num?)?.toDouble() ?? 1000.0,
          'max_payment': (m['max_qris_amount'] as num?)?.toDouble() ?? 10000000.0,
          'free_threshold':
              (m['qris_free_threshold'] as num?)?.toDouble() ?? 100000.0,
        };
        _finCache = cfg;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, jsonEncode(cfg));
        } catch (_) {}
        return cfg;
      }
    } catch (_) {
      // offline / gagal: pakai cache.
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        return _finCache = (jsonDecode(raw) as Map).cast<String, dynamic>();
      }
    } catch (_) {}
    return _finCache = const {
      'min_payment': 1000.0,
      'max_payment': 10000000.0,
      'free_threshold': 100000.0,
    };
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
        'order_id': order.providerOrderId,
        'payment_url': order.paymentUrl,
        'qris_url': order.qrisUrl,
        'qris_string': order.qrisString,
        'total_amount': order.totalAmount,
      };
    } catch (e) {
      return {'error': e.toString(), 'status': 'failed'};
    }
  }

}

/// Panggil Edge Function & kembalikan body JSON. Melempar pesan asli server
/// bila function mengembalikan status non-2xx.
Future<Map<String, dynamic>> _invokeEf(
    SupabaseClient client, String name, Map<String, dynamic> body) async {
  try {
    final res = await client.functions.invoke(name, body: body);
    if (res.data is Map) return (res.data as Map).cast<String, dynamic>();
    return <String, dynamic>{};
  } on FunctionException catch (e) {
    throw Exception(_efMessage(e.details) ?? 'Gagal menghubungi server ($name).');
  }
}

String? _efMessage(dynamic details) {
  if (details == null) return null;
  if (details is Map) {
    final msg = details['message'] ?? details['error'];
    if (msg != null) return msg.toString();
  }
  final s = details.toString();
  if (s.isEmpty) return null;
  try {
    final decoded = jsonDecode(s);
    if (decoded is Map && decoded['message'] != null) {
      return decoded['message'].toString();
    }
  } catch (_) {}
  return s;
}
