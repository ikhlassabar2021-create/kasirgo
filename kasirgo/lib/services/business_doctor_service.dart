import 'dart:convert';

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

  Future<List<Map<String, dynamic>>> listConversations(String outletId) async {
    final res = await _client
        .from('doctor_conversations')
        .select('id, title, phase, status, escalation_level, updated_at')
        .eq('outlet_id', outletId)
        .order('updated_at', ascending: false)
        .limit(50);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listMemories(String outletId) async {
    final res = await _client
        .from('doctor_memory')
        .select('id, kind, title, content, status, lesson, created_at')
        .eq('outlet_id', outletId)
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// Teguran terbaru hari ini (kind='reprimand'); null bila tidak ada.
  Future<Map<String, dynamic>?> getLatestReprimand(String outletId) async {
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final res = await _client
        .from('doctor_memory')
        .select('id, title, content, data, created_at')
        .eq('outlet_id', outletId)
        .eq('kind', 'reprimand')
        .gte('created_at', '${today}T00:00:00Z')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return res;
  }

  Future<List<Map<String, dynamic>>> listMessages(String conversationId) async {
    final res = await _client
        .from('doctor_messages')
        .select('role, content, blocks')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(60);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> getActivePrescription(String outletId) async {
    final res = await _client
        .from('doctor_memory')
        .select('id, title, content, status, due_at, created_at')
        .eq('outlet_id', outletId)
        .eq('kind', 'prescription')
        .eq('status', 'open')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return _toBlock(res);
  }

  Map<String, dynamic> _toBlock(Map<String, dynamic> row) {
    Map<String, dynamic> content = const {};
    final raw = row['content'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) content = d.cast<String, dynamic>();
      } catch (_) {}
    } else if (raw is Map) {
      content = raw.cast<String, dynamic>();
    }
    return {
      'type': 'prescription',
      'memory_id': row['id']?.toString(),
      'title': row['title'] ?? content['verdict'] ?? 'Resep',
      'verdict': content['verdict'] ?? row['title'] ?? '',
      'target_days': content['target_days'] ?? 7,
      'started_at': content['started_at'],
      'due_at': row['due_at'] ?? content['due_at'],
      'items': content['steps'] ?? const [],
    };
  }

  Future<void> savePrescription({
    required String memoryId,
    required Map<String, dynamic> block,
    String? status,
  }) async {
    await _client.from('doctor_memory').update({
      'content': jsonEncode({
        'verdict': block['verdict'] ?? block['title'] ?? '',
        'target_days': block['target_days'] ?? 7,
        'started_at': block['started_at'],
        'steps': block['items'] ?? const [],
      }),
      if (status != null) 'status': status,
    }).eq('id', memoryId);
  }

  // --- ST15-2: Bos Virtual Analitik ---

  /// Baca target omzet aktif untuk outlet (harian/bulanan).
  Future<List<Map<String, dynamic>>> getTargets(String outletId) async {
    final res = await _client
        .from('outlet_targets')
        .select('*')
        .eq('outlet_id', outletId)
        .order('effective_from', ascending: false)
        .limit(4);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Simpan / perbarui target omzet outlet.
  Future<void> saveTarget({
    required String outletId,
    required String period,
    required double targetAmount,
    String setBy = 'owner',
    String? note,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _client.from('outlet_targets').upsert({
      'outlet_id': outletId,
      'period': period,
      'target_amount': targetAmount,
      'set_by': setBy,
      'source': 'app_owner',
      'note': note,
      'effective_from': today,
    }, onConflict: 'outlet_id,period,effective_from');
  }

  /// Baca rencana scaling aktif outlet.
  Future<List<Map<String, dynamic>>> getScalingPlans(String outletId) async {
    final res = await _client
        .from('doctor_scaling_plans')
        .select('*')
        .eq('outlet_id', outletId)
        .order('created_at', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Simpan / perbarui status scaling plan.
  Future<void> updateScalingPlanStatus(String planId, String status) async {
    await _client
        .from('doctor_scaling_plans')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', planId);
  }

  /// Ambil catatan intel pasar terbaru (dari doctor_memory kind market).
  Future<List<Map<String, dynamic>>> getMarketIntel(String outletId) async {
    final res = await _client
        .from('doctor_memory')
        .select('*')
        .eq('outlet_id', outletId)
        .eq('kind', 'market')
        .order('created_at', ascending: false)
        .limit(5);
    return List<Map<String, dynamic>>.from(res as List);
  }
}
