import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/dynamic_pricing.dart';
import 'supabase_service.dart';

/// Penerapan rekomendasi Dynamic Pricing ke database (diskon & harga jual).
///
/// Analisisnya murni lokal di [DynamicPricing]; kelas ini hanya menyentuh
/// jaringan saat owner menekan "Terapkan".
class DynamicPricingService {
  DynamicPricingService({SupabaseClient? client, SupabaseService? service})
      : _client = client ?? Supabase.instance.client,
        _service = service ?? SupabaseService(client: client);

  final SupabaseClient _client;
  final SupabaseService _service;

  Future<DynamicPricingPlan> loadPlan(
    String outletId, {
    double minMarginPercent = DynamicPricing.defaultMinMarginPercent,
    int daysThreshold = DynamicPricing.defaultInactiveDays,
    int transactionDays = 90,
  }) async {
    final products = await _service.getProducts(outletId);
    final since = DateTime.now().subtract(Duration(days: transactionDays));
    final transactions = await _service.getTransactions(
      outletId,
      limit: 500,
      startDate: since,
    );
    return DynamicPricing.build(
      products,
      transactions,
      minMarginPercent: minMarginPercent,
      daysThreshold: daysThreshold,
    );
  }

  /// Pasang diskon untuk produk. Diskon aktif yang menutupi hari ini akan
  /// diperbarui, bukan ditumpuk.
  Future<void> applyDiscount(
    PriceRecommendation rec, {
    int days = 7,
  }) async {
    final now = DateTime.now();
    final end = now.add(Duration(days: days));
    final payload = {
      'product_id': rec.product.id,
      'discount_percent': rec.discountPercent,
      'discount_amount': null,
      'start_date': now.toUtc().toIso8601String(),
      'end_date': end.toUtc().toIso8601String(),
      'is_flash_sale': true,
    };

    final existing = await _client
        .from('product_discounts')
        .select('id')
        .eq('product_id', rec.product.id)
        .gte('end_date', now.toUtc().toIso8601String())
        .order('end_date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('product_discounts')
          .update(payload)
          .eq('id', existing['id']);
    } else {
      await _client.from('product_discounts').insert(payload);
    }
  }

  /// Naikkan harga jual dasar agar margin tidak lagi di bawah ambang.
  Future<void> applyPrice(MarginAlert alert) async {
    await _client.from('products').update({
      'base_price': alert.suggestedPrice,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', alert.product.id);
  }

  /// Catat aksi ke jejak Dokter Bisnis supaya bisa dievaluasi & ditindaklanjuti.
  Future<void> logAction({
    required String outletId,
    required String description,
    required Map<String, dynamic> result,
    String? outcome,
    String actionType = 'dynamic_pricing',
    String? channel,
  }) async {
    try {
      await _client.from('doctor_action_logs').insert({
        'outlet_id': outletId,
        'action_type': actionType,
        'channel': channel,
        'description': description,
        'action_date': DateTime.now().toIso8601String().substring(0, 10),
        'result': result,
        'outcome': outcome,
        'status': 'done',
      });
    } catch (_) {
      // Jejak aksi pelengkap; jangan gagalkan penerapan harga.
    }
  }
}
