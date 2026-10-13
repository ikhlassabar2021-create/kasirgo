import 'dart:async';

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
    String? address,
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
        'p_address': address,
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

  /// Satu pesanan berdasarkan id (untuk halaman pelacakan).
  Future<Order?> getOrder(String orderId) async {
    try {
      final res = await _client
          .from('orders')
          .select('*, order_items(*)')
          .eq('id', orderId)
          .maybeSingle();
      if (res == null) return null;
      return Order.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('OrderService.getOrder error: $e');
      return null;
    }
  }

  /// Pantau perubahan satu pesanan via Realtime (halaman pelacakan).
  Stream<Order?> watchOrder(String orderId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((rows) {
      if (rows.isEmpty) return null;
      return Order.fromJson(Map<String, dynamic>.from(rows.first));
    });
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

  /// Tandai pesanan antar sedang diantar (kurir sudah jalan).
  Future<Map<String, dynamic>> markOutForDelivery(String orderId) async {
    try {
      final res = await _client.rpc('mark_order_out_for_delivery', params: {
        'p_order': orderId,
      });
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'success': false, 'error': 'UNKNOWN'};
    } catch (e) {
      debugPrint('OrderService.markOutForDelivery error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Konfirmasi pesanan diterima (Proof of Delivery).
  /// - Kasir/kurir: sertakan [receiverCode] (kode 4 digit dari pembeli).
  /// - Pembeli (Grab/Gojek): panggil tanpa kode.
  Future<Map<String, dynamic>> confirmReceived({
    required String orderId,
    String? receiverCode,
  }) async {
    try {
      final res = await _client.rpc('confirm_order_received', params: {
        'p_order': orderId,
        'p_receiver_code': receiverCode,
      });
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'success': false, 'error': 'UNKNOWN'};
    } catch (e) {
      debugPrint('OrderService.confirmReceived error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Ubah status pesanan (baru/diproses/siap/diantar/terkirim/selesai/dibatalkan).
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

  /// Pilih kurir untuk pesanan antar (kurir_warung/grab/gojek).
  Future<bool> setOrderCourier(String orderId, String courier) async {
    try {
      await _client.from('orders').update({
        'courier': courier,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('OrderService.setOrderCourier error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // BLOKIR PEMBELI (owner/kasir)
  // ---------------------------------------------------------------------------

  /// Blokir pembeli online agar tidak bisa membuat pesanan baru di outlet ini.
  Future<Map<String, dynamic>> blockBuyer({
    required String outletId,
    required String buyerId,
    String? reason,
  }) async {
    try {
      final res = await _client.rpc('block_buyer', params: {
        'p_outlet': outletId,
        'p_buyer': buyerId,
        'p_reason': reason,
      });
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'success': false, 'error': 'UNKNOWN'};
    } catch (e) {
      debugPrint('OrderService.blockBuyer error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Buka blokir pembeli.
  Future<Map<String, dynamic>> unblockBuyer({
    required String outletId,
    required String buyerId,
  }) async {
    try {
      final res = await _client.rpc('unblock_buyer', params: {
        'p_outlet': outletId,
        'p_buyer': buyerId,
      });
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'success': false, 'error': 'UNKNOWN'};
    } catch (e) {
      debugPrint('OrderService.unblockBuyer error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Daftar pembeli yang diblokir di outlet ini.
  Future<List<Map<String, dynamic>>> listBlockedBuyers(String outletId) async {
    try {
      final res =
          await _client.rpc('list_blocked_buyers', params: {'p_outlet': outletId});
      return (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('OrderService.listBlockedBuyers error: $e');
      return [];
    }
  }
}
