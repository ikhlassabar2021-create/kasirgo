import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessDoctorService {
  BusinessDoctorService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> chat({
    required String outletId,
    required String message,
    String? conversationId,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'business_doctor_chat',
        body: {
          'outlet_id': outletId,
          'message': message,
          'conversation_id': ?conversationId,
        },
      );
      if (res.data is Map) return (res.data as Map).cast<String, dynamic>();
      return <String, dynamic>{};
    } on FunctionException catch (e) {
      throw Exception(_message(e.details) ?? 'Gagal menghubungi Dokter Bisnis.');
    }
  }

  String? _message(dynamic details) {
    if (details is Map) {
      final m = details['message'] ?? details['error'];
      if (m != null) return m.toString();
    }
    return details?.toString();
  }
}
