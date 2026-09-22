import 'package:supabase_flutter/supabase_flutter.dart';

class SettlementService {
  final SupabaseClient _supabase;

  SettlementService() : _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getSettlementStats({required int outletId}) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final qrissPending = await _supabase
        .from('transaksi')
        .select('amount, status')
        .eq('outlet_id', outletId)
        .eq('payment_method', 'qris_dynamic')
        .eq('status', 'PAID');

    final totalQrisPending = (qrissPending as List).fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());

    final transferredToday = await _supabase
        .from('settlements')
        .select('amount, status')
        .eq('outlet_id', outletId)
        .gte('settled_at', startOfDay.toIso8601String())
        .eq('status', 'SUCCESS');

    final totalTransferred = (transferredToday as List).fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());

    return {
      'qris_pending': totalQrisPending,
      'total_transferred': totalTransferred,
    };
  }

  Future<Map<String, double>> calculateSettlement({
    required int outletId,
    required String shiftId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final transactions = await _supabase
        .from('transaksi')
        .select('amount, payment_method, mdr')
        .eq('outlet_id', outletId)
        .eq('shift_id', shiftId)
        .eq('created_at', periodStart.toIso8601String())
        .or("status.eq.PAID,status.eq.SETTLED")
        .or("payment_method.eq.qris_static,payment_method.eq.qris_dynamic");

    final qrisTransactions = transactions as List;

    double grossAmount = 0;
    double totalMdr = 0;

    for (final t in qrisTransactions) {
      if (t['payment_method'] == 'qris_dynamic') {
        grossAmount += (t['amount'] as num).toDouble();
        totalMdr += ((t['mdr'] as num?)?.toDouble() ?? 0.0);
      } else if (t['payment_method'] == 'qris_static') {
        grossAmount += (t['amount'] as num).toDouble();
        totalMdr += ((t['mdr'] as num?)?.toDouble() ?? 0.0);
      }
    }

    final financialConfigs = await getFinancialConfig(outletId);
    final platformMarginRate = (financialConfigs['platform_margin_rate'] as num?)?.toDouble() ?? 0.02;
    final marginAmount = grossAmount * platformMarginRate;
    final netAmount = grossAmount - totalMdr - marginAmount;

    return {
      'gross_amount': grossAmount,
      'mdr': totalMdr,
      'margin': marginAmount,
      'net_amount': netAmount,
    };
  }

  Future<void> markSettlementAsPpobUsed({required int settlementId}) async {
    await _supabase
        .from('settlements')
        .update({'status': 'PPOB_USED'})
        .eq('id', settlementId);
  }

  Future<Map<String, dynamic>> getFinancialConfig(int outletId) async {
    return {
      'platform_margin_rate': 0.02,
      'instant_withdrawal_fee': 0.005,
      'min_withdrawal': 50000,
    };
  }

  Future<int> createSettlement({
    required int outletId,
    required String shiftId,
    required String settlementType,
    required double amount,
    bool isInstant = false,
  }) async {
    final now = DateTime.now().toIso8601String();
    final instantFeeRate = 0.005;
    final instantFee = isInstant ? amount * instantFeeRate : 0;
    final finalAmount = isInstant ? amount - instantFee : amount;

    final response = await _supabase.from('settlements').insert({
      'outlet_id': outletId,
      'shift_id': shiftId,
      'settlement_type': settlementType,
      'gross_amount': amount,
      'net_amount': finalAmount,
      'reference_number': 'SL-${DateTime.now().millisecondsSinceEpoch}',
      'status': isInstant ? 'PROCESSING' : 'PENDING',
      'is_instant': isInstant,
      'created_at': now,
    });

    return (response as List).isEmpty ? -1 : response[0]['id'];
  }
}
