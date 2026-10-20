import 'dart:async';
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
      ).timeout(const Duration(seconds: 75));
      if (res.data is Map) return (res.data as Map).cast<String, dynamic>();
      return <String, dynamic>{};
    } on TimeoutException {
      throw Exception('Dokter Bisnis lama merespons. Coba lagi sebentar.');
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

  /// Hapus satu kasus konsultasi (pesan ikut terhapus via ON DELETE CASCADE).
  Future<void> deleteConversation(String conversationId) async {
    await _client.from('doctor_conversations').delete().eq('id', conversationId);
  }

  /// Hapus satu catatan memori.
  Future<void> deleteMemory(String memoryId) async {
    await _client.from('doctor_memory').delete().eq('id', memoryId);
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
    String? memoryId,
    required Map<String, dynamic> block,
    String? status,
  }) async {
    final id = (memoryId ?? block['memory_id']?.toString() ?? '').trim();
    if (id.isEmpty) return;
    await _client.from('doctor_memory').update({
      'content': jsonEncode({
        'verdict': block['verdict'] ?? block['title'] ?? '',
        'target_days': block['target_days'] ?? 7,
        'started_at': block['started_at'],
        'steps': block['items'] ?? const [],
      }),
      if (status != null) 'status': status,
    }).eq('id', id);
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

  // --- ST15-4: Addendum & Hardening (L/M/N/O) ---

  /// Laporan mingguan terbaru (kind='weekly_report'); null bila belum ada.
  Future<Map<String, dynamic>?> getLatestWeeklyReport(String outletId) async {
    final res = await _client
        .from('doctor_memory')
        .select('id, title, content, data, created_at')
        .eq('outlet_id', outletId)
        .eq('kind', 'weekly_report')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return res;
  }

  /// Aksi otomatis yang menunggu persetujuan owner (guardrail).
  Future<List<Map<String, dynamic>>> listPendingActions(String outletId) async {
    final res = await _client
        .from('doctor_pending_actions')
        .select('*')
        .eq('outlet_id', outletId)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Setujui / tolak aksi yang diusulkan AI.
  Future<void> decidePendingAction({
    required String actionId,
    required bool approve,
    String? note,
  }) async {
    await _client.from('doctor_pending_actions').update({
      'status': approve ? 'approved' : 'rejected',
      'decision_note': note,
      'decided_at': DateTime.now().toIso8601String(),
    }).eq('id', actionId);
  }

  /// Profil/identitas bisnis (fase, penyakit aktif, skor kesehatan).
  Future<Map<String, dynamic>?> getOutletIdentity(String outletId) async {
    final res = await _client
        .from('doctor_outlet_profile')
        .select(
            'phase, health_score, active_disease, active_disease_since, business_age_days, last_weekly_report_at')
        .eq('outlet_id', outletId)
        .maybeSingle();
    return res;
  }

  // --- Dokter Bisnis 3.0: persona, dosis harian, briefing ---

  /// Persona & gamifikasi ringan (nada bicara, rentetan hari, XP/level).
  Future<Map<String, dynamic>?> getProfile(String outletId) async {
    final res = await _client
        .from('doctor_outlet_profile')
        .select(
            'preferred_tone, daily_streak, last_dose_at, boss_wa_number, audio_prefs, xp, level')
        .eq('outlet_id', outletId)
        .maybeSingle();
    return res;
  }

  /// Simpan master switch suara Dokter Bisnis per outlet.
  Future<void> setAudioPrefs({
    required String outletId,
    required bool aktif,
    required bool soundboxPos,
    required bool teguran,
  }) async {
    await _client.from('doctor_outlet_profile').upsert({
      'outlet_id': outletId,
      'audio_prefs': {
        'aktif': aktif,
        'soundbox_pos': soundboxPos,
        'teguran': teguran,
      },
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'outlet_id');
  }

  /// Simpan nomor WhatsApp "Bos Besar" untuk laporan otomatis.
  Future<void> setBossWaNumber({
    required String outletId,
    required String number,
  }) async {
    await _client.from('doctor_outlet_profile').upsert({
      'outlet_id': outletId,
      'boss_wa_number': number.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'outlet_id');
  }

  /// Catat bahwa laporan sudah dikirim ke Bos via WhatsApp (jejak audit).
  Future<void> logBossReport({
    required String outletId,
    required String kind,
    String? summary,
  }) async {
    await _client.from('doctor_action_logs').insert({
      'outlet_id': outletId,
      'action_type': 'boss_report',
      'channel': 'whatsapp',
      'description': '$kind: ${summary ?? ''}'.trim(),
      'action_date': DateTime.now().toIso8601String().substring(0, 10),
      'result': {'kind': kind},
      'outcome': 'sent',
    });
  }

  /// Simpan pilihan persona/nada bicara Dokter Bisnis.
  Future<void> setPreferredTone({
    required String outletId,
    required String tone,
  }) async {
    await _client.from('doctor_outlet_profile').upsert({
      'outlet_id': outletId,
      'preferred_tone': tone,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'outlet_id');
  }

  /// Dosis harian hari ini (checklist harian); null bila belum dibuat.
  Future<Map<String, dynamic>?> getDailyDose(String outletId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final res = await _client
        .from('doctor_daily_doses')
        .select('id, dose_date, title, items, total_items, done_items, status')
        .eq('outlet_id', outletId)
        .eq('dose_date', today)
        .maybeSingle();
    return res;
  }

  /// Perbarui progres dosis harian (centang langkah) langsung di DB.
  Future<void> updateDailyDose({
    required String outletId,
    required List items,
    required int doneItems,
    required String status,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _client
        .from('doctor_daily_doses')
        .update({
          'items': items,
          'done_items': doneItems,
          'total_items': items.length,
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('outlet_id', outletId)
        .eq('dose_date', today);
  }

  /// Briefing "Apel Pagi" hari ini via Edge Function doctor_briefing.
  Future<Map<String, dynamic>?> getBriefing(String outletId) async {
    try {
      final res = await _client.functions.invoke(
        'doctor_briefing',
        body: {'outlet_id': outletId},
      ).timeout(const Duration(seconds: 30));
      if (res.data is Map) return (res.data as Map).cast<String, dynamic>();
      return null;
    } on TimeoutException {
      return null;
    }
  }

  // --- Dokter Bisnis 3.0: Kamera Klinis (vitals) + gamifikasi XP ---

  /// Simpan hasil "Kamera Klinis": skor dihitung server dari rating per aspek.
  /// Kembalikan {ok, score, xp, level, leveled_up} bila sukses.
  Future<Map<String, dynamic>> saveVitals({
    required String outletId,
    required List aspects,
    String? notes,
  }) async {
    final res = await _client.rpc('doctor_save_vitals', params: {
      'p_outlet': outletId,
      'p_aspects': aspects,
      'p_notes': ?notes,
    });
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// Tambah XP server-authoritative untuk sebuah aktivitas.
  Future<Map<String, dynamic>> awardXp({
    required String outletId,
    required String reason,
  }) async {
    final res = await _client.rpc('doctor_award_xp', params: {
      'p_outlet': outletId,
      'p_reason': reason,
    });
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// Beri XP satu kali per `eventKey` (mis. `dosis:2026-11-26`), sehingga
  /// aktivitas yang dibatalkan lalu ditandai ulang tidak menambah XP ganda.
  Future<Map<String, dynamic>> awardXpOnce({
    required String outletId,
    required String reason,
    required String eventKey,
  }) async {
    final res = await _client.rpc('doctor_award_xp_once', params: {
      'p_outlet': outletId,
      'p_reason': reason,
      'p_key': eventKey,
    });
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// Config Kamera Klinis dari Control Plane
  /// (platform_configs 'business_doctor' -> 'kamera_klinis').
  /// Kembalikan {aktif, aspek:[{key,label}]}; fallback 3 aspek default.
  Future<Map<String, dynamic>> getKameraKlinisConfig() async {
    const defaultAspects = [
      {'key': 'fisik', 'label': 'Kondisi Fisik Toko'},
      {'key': 'tampilan', 'label': 'Tampilan & Kerapian'},
      {'key': 'perilaku', 'label': 'Perilaku Pelayanan'},
    ];
    try {
      final res = await _client
          .from('platform_configs')
          .select('value')
          .eq('key', 'business_doctor')
          .eq('scope', 'global')
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();
      final value = res?['value'];
      if (value is Map && value['kamera_klinis'] is Map) {
        final cfg = Map<String, dynamic>.from(value['kamera_klinis'] as Map);
        final aspek = cfg['aspek'];
        if (aspek is List && aspek.isNotEmpty) {
          return {
            'aktif': cfg['aktif'] ?? true,
            'aspek': aspek
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList(),
          };
        }
        return {'aktif': cfg['aktif'] ?? true, 'aspek': defaultAspects};
      }
    } catch (_) {}
    return {'aktif': true, 'aspek': defaultAspects};
  }

  /// Riwayat pemeriksaan Kamera Klinis (terbaru lebih dulu).
  Future<List<Map<String, dynamic>>> getVitalsHistory(String outletId) async {
    final rows = await _client
        .from('doctor_vitals_checks')
        .select('id, check_date, aspects, score, notes, created_at')
        .eq('outlet_id', outletId)
        .order('check_date', ascending: false)
        .limit(30);
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
