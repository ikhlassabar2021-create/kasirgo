import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';

/// ST17-1 (Phase 17 - Ekosistem Hyper-Local): layanan siklus pesanan online.
/// Pembeli: submit_order. Penjual: listOrders, validateOrderPayment,
/// completeOrder. Semua mutasi lewat RPC SECURITY DEFINER di DB.
class OrderService {
  OrderService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ---------------------------------------------------------------------------
  // PEMBELI
  // ---------------------------------------------------------------------------

  /// Buat pesanan (atomik: order + items + hitung ongkir).
  /// Mengembalikan {success, order_id, code, subtotal, delivery_fee, total,
  /// distance_km, buyer_id} atau {success:false, error}.
  Future<Map<String, dynamic>> submitOrder({
    required String outletId,
    required List<Map<String, dynamic>> items,
    String fulfillment = 'pickup',
    String? note,
    double? buyerLat,
    double? buyerLng,
    String? name,
    String? phone,
  }) async {
    try {
      final res = await _client.rpc('submit_order', params: {
        'p_outlet': outletId,
        'p_items': items,
        'p_fulfillment': fulfillment,
        'p_note': note,
        'p_buyer_lat': buyerLat,
        'p_buyer_lng': buyerLng,
        'p_name': name,
        'p_phone': phone,
      });
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'success': false, 'error': 'UNKNOWN'};
    } catch (e) {
      debugPrint('OrderService.submitOrder error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Pesanan milik pembeli yang sedang login (RLS buyer read own orders).
  Future<List<Order>> myOrders({int limit = 30}) async {
    try {
      final res = await _client
          .from('orders')
          .select('*, order_items(*)')
          .order('created_at', ascending: false)
          .limit(limit);
      return (res as List)
          .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('OrderService.myOrders error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // PENJUAL (owner/admin outlet)
  // ---------------------------------------------------------------------------

  /// Daftar pesanan outlet, opsional filter status.
  Future<List<Order>> listOrders(
    String outletId, {
    String? status,
    String? paymentStatus,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from('orders')
          .select('*, order_items(*)')
          .eq('outlet_id', outletId);
      if (status != null) query = query.eq('status', status);
      if (paymentStatus != null) query = query.eq('payment_status', paymentStatus);
      final res = await query.order('created_at', ascending: false).limit(limit);
      return (res as List)
          .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('OrderService.listOrders error: $e');
      return [];
    }
  }

  /// Pesanan menunggu validasi pembayaran (untuk badge "Pesanan Masuk").
  Future<List<Order>> pendingPaymentOrders(String outletId) =>
      listOrders(outletId, paymentStatus: 'belum_konfirmasi');

  /// Validasi/penolakan bukti pembayaran manual (QRIS statis/transfer).
  Future<Map<String, dynamic>> validateOrderPayment({
    required String orderId,
    required bool accept,
    String? proofPath,
  }) async {
    try {
      if (proofPath != null) {
        await _client
            .from('orders')
            .update({'proof_path': proofPath})
            .eq('id', orderId);
      }
      final res = await _client.rpc('validate_order_payment', params: {
        'p_order': orderId,
        'p_accept': accept,
      });
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'success': false, 'error': 'UNKNOWN'};
    } catch (e) {
      debugPrint('OrderService.validateOrderPayment error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Selesaikan pesanan -> buat transaksi + items (idempoten).
  Future<Map<String, dynamic>> completeOrder(String orderId) async {
    try {
      final res = await _client.rpc('complete_order', params: {
        'p_order': orderId,
      });
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'success': false, 'error': 'UNKNOWN'};
    } catch (e) {
      debugPrint('OrderService.completeOrder error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Ubah status pesanan (baru/diproses/siap/selesai/dibatalkan).
  Future<bool> setOrderStatus(String orderId, String status) async {
    try {
      await _client
          .from('orders')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('OrderService.setOrderStatus error: $e');
      return false;
    }
  }
}
