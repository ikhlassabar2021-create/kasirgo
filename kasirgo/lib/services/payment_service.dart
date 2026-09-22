import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>> createCharge({
    required String orderId,
    required double amount,
    required String qrisType, // 'static' | 'dynamic'
  }) async {
    try {
      if (qrisType == 'static') {
        return {'status': 'success', 'mode': 'static'};
      }

      final response = await _client.functions.invoke(
        'create_midtrans_charge',
        body: {
          'order_id': orderId,
          'amount': amount,
        },
      );

      return response.data ?? {'status': 'success', 'mode': 'midtrans'};
    } catch (e) {
      return {'error': e.toString(), 'status': 'failed'};
    }
  }

  Future<void> updatePaymentStatus({
    required String transactionId,
    required String status,
  }) async {
    await _client
        .from('transactions')
        .update({'payment_status': status})
        .eq('id', transactionId);
  }

  Map<String, dynamic> getFinancialConfig() {
    return {
      'min_payment': 1000.0,
      'max_payment': 1000000.0,
      'free_threshold': 50000.0,
    };
  }
}
