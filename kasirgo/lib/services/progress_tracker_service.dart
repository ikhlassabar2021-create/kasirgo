import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/progress_tracker.dart';
import 'business_doctor_service.dart';
import 'supabase_service.dart';

/// Sumber data Progress Tracker (13.24 #6).
///
/// Menggabungkan transaksi 30 hari, target omzet, resep aktif, dan jejak aksi
/// Dokter Bisnis menjadi satu laporan [ProgressTrackerReport].
class ProgressTrackerService {
  final SupabaseClient _db;
  final SupabaseService _supabase;
  final BusinessDoctorService _doctor;

  ProgressTrackerService({
    SupabaseClient? client,
    SupabaseService? supabaseService,
    BusinessDoctorService? doctorService,
  })  : _db = client ?? Supabase.instance.client,
        _supabase = supabaseService ?? SupabaseService(client: client),
        _doctor = doctorService ?? BusinessDoctorService(client: client);

  Future<ProgressTrackerReport> load(String outletId, {DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final since = ProgressTracker.dayOf(clock)
        .subtract(const Duration(days: 29));

    final results = await Future.wait<dynamic>([
      _supabase.getTransactions(
        outletId,
        limit: 500,
        startDate: since,
      ),
      _doctor.getTargets(outletId),
      _doctor.getActivePrescription(outletId),
      _loadActionLogs(outletId),
    ]);

    final transactions = results[0] as List;
    final targets = results[1] as List<Map<String, dynamic>>;
    final prescription = results[2] as Map<String, dynamic>?;
    final logs = results[3] as List<Map<String, dynamic>>;

    return ProgressTracker.build(
      transactions: transactions.cast(),
      target: targets.isNotEmpty ? targets.first : null,
      prescription: prescription,
      actionLogs: logs,
      now: clock,
    );
  }

  Future<List<Map<String, dynamic>>> _loadActionLogs(String outletId) async {
    try {
      final res = await _db
          .from('doctor_action_logs')
          .select('id, action_type, status, outcome, description, action_date')
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false)
          .limit(60);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  /// Catat progres hari ini ke jejak aksi Dokter Bisnis.
  Future<void> logProgress({
    required String outletId,
    required ProgressTrackerReport report,
  }) async {
    await _db.from('doctor_action_logs').insert({
      'outlet_id': outletId,
      'action_type': 'progress_tracker',
      'channel': 'offline',
      'description': 'Cek progres: ${report.verdict} '
          '(skor ${report.score}, omzet 7 hari ${report.trendLabel})',
      'action_date': DateTime.now().toIso8601String().substring(0, 10),
      'result': {
        'score': report.score,
        'trend': report.salesTrend.trend.name,
        'trend_label': report.trendLabel,
        'sales_7d': report.salesTrend.current,
        'sales_prev_7d': report.salesTrend.previous,
        'target_percent': report.targetPercent,
        'prescription_done': report.prescriptionDone,
        'prescription_total': report.prescriptionTotal,
        'actions_done': report.actionsDone,
        'actions_total': report.actionsTotal,
      },
      'outcome': report.salesTrend.trend.name,
      'status': 'done',
    });
  }
}
