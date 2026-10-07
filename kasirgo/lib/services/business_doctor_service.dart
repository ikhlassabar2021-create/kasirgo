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

  Future<String?> saveIntake({
    required String outletId,
    required Map<String, dynamic> physical,
    String? visualNotes,
    required Map<String, dynamic> behavior,
  }) async {
    final res = await _client.from('doctor_intake').insert({
      'outlet_id': outletId,
      'physical': physical,
      'visual_notes': visualNotes,
      'behavior': behavior,
      'completed': true,
    }).select('id').maybeSingle();
    return res?['id']?.toString();
  }

  Future<String> getPhase(String outletId) async {
    final res = await _client
        .from('doctor_outlet_profile')
        .select('phase')
        .eq('outlet_id', outletId)
        .maybeSingle();
    final phase = res?['phase']?.toString();
    return (phase == null || phase.isEmpty) ? 'A' : phase;
  }

  Future<void> logPromotion({
    required String outletId,
    String? conversationId,
    required String actionType,
    String? channel,
    double cost = 0,
    String? description,
    DateTime? actionDate,
    double extraRevenue = 0,
    String? outcome,
  }) async {
    await _client.from('doctor_action_logs').insert({
      'outlet_id': outletId,
      'conversation_id': conversationId,
      'action_type': actionType,
      'channel': channel,
      'cost': cost,
      'description': description,
      'action_date':
          (actionDate ?? DateTime.now()).toIso8601String().substring(0, 10),
      'result': {'extra_revenue': extraRevenue},
      'outcome': outcome,
    });
  }

  Future<List<Map<String, dynamic>>> getActionLogs(String outletId) async {
    final res = await _client
        .from('doctor_action_logs')
        .select(
            'id, action_type, channel, cost, description, action_date, result, outcome')
        .eq('outlet_id', outletId)
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List).cast<Map<String, dynamic>>();
  }
}
