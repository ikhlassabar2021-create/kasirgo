import '../models/transaction.dart';

/// Arah tren kemajuan usaha (13.14 komponen #6).
enum ProgressTrend { up, flat, down }

extension ProgressTrendLabel on ProgressTrend {
  /// Teks awam sesuai spesifikasi: "membaik / masih sama / menurun".
  String get label => switch (this) {
        ProgressTrend.up => 'membaik',
        ProgressTrend.flat => 'masih sama',
        ProgressTrend.down => 'menurun',
      };

  String get title => switch (this) {
        ProgressTrend.up => 'Membaik',
        ProgressTrend.flat => 'Masih sama',
        ProgressTrend.down => 'Menurun',
      };
}

/// Omzet satu hari (tanggal dinormalisasi ke 00:00 waktu lokal).
class DailySales {
  final DateTime date;
  final double amount;

  const DailySales(this.date, this.amount);
}

/// Perbandingan omzet periode berjalan vs periode sebelumnya.
class TrendInfo {
  final double current;
  final double previous;
  final ProgressTrend trend;

  const TrendInfo({
    required this.current,
    required this.previous,
    required this.trend,
  });

  bool get hasData => current > 0 || previous > 0;

  /// Perubahan persen; 100% bila sebelumnya nol lalu ada omzet.
  double get changePercent {
    if (previous <= 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous) * 100;
  }

  String get label => trend.label;
}

/// Hasil analisis Progress Tracker (murni lokal, tanpa jaringan).
class ProgressTrackerReport {
  final TrendInfo salesTrend;
  final double todaySales;
  final String targetPeriod;
  final double targetAmount;
  final double targetSales;
  final int prescriptionDone;
  final int prescriptionTotal;
  final int actionsDone;
  final int actionsRunning;
  final int actionsPlanned;
  final int score;
  final List<DailySales> last7Days;

  const ProgressTrackerReport({
    required this.salesTrend,
    required this.todaySales,
    required this.targetPeriod,
    required this.targetAmount,
    required this.targetSales,
    required this.prescriptionDone,
    required this.prescriptionTotal,
    required this.actionsDone,
    required this.actionsRunning,
    required this.actionsPlanned,
    required this.score,
    required this.last7Days,
  });

  bool get hasTarget => targetAmount > 0;

  bool get hasPrescription => prescriptionTotal > 0;

  int get actionsTotal => actionsDone + actionsRunning + actionsPlanned;

  double get targetProgress =>
      hasTarget ? (targetSales / targetAmount).clamp(0.0, 1.0) : 0.0;

  int get targetPercent => (targetProgress * 100).round();

  double get prescriptionProgress => prescriptionTotal <= 0
      ? 0.0
      : (prescriptionDone / prescriptionTotal).clamp(0.0, 1.0);

  int get prescriptionPercent => (prescriptionProgress * 100).round();

  /// Ada data yang cukup untuk menampilkan tren & skor.
  bool get hasData =>
      salesTrend.hasData ||
      hasTarget ||
      hasPrescription ||
      actionsTotal > 0;

  String get trendLabel => salesTrend.label;

  String get trendText {
    if (!salesTrend.hasData) return 'Belum ada penjualan untuk dibandingkan';
    return 'Omzet 7 hari terakhir ${salesTrend.label} '
        'dibanding 7 hari sebelumnya';
  }

  String get verdict {
    if (!hasData) return 'Data belum cukup';
    if (score >= 70) return 'Usaha Anda membaik';
    if (score >= 45) return 'Usaha Anda masih sama';
    return 'Usaha Anda menurun';
  }

  double get maxDaily {
    var max = 0.0;
    for (final d in last7Days) {
      if (d.amount > max) max = d.amount;
    }
    return max;
  }
}

/// Analisis Progress Tracker: memadukan omzet, target, resep aktif, dan aksi.
class ProgressTracker {
  const ProgressTracker._();

  static const int trendWindowDays = 7;
  static const double flatThresholdPercent = 5;

  static bool isPaid(Transaction t) {
    final status = (t.paymentStatus ?? '').toLowerCase();
    if (status.isEmpty) return true;
    return status == 'paid' ||
        status == 'completed' ||
        status == 'success' ||
        status == 'settlement' ||
        status == 'capture';
  }

  static DateTime dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Omzet harian [days] hari terakhir (termasuk hari ini), urut lama -> baru.
  static List<DailySales> dailySales(
    List<Transaction> transactions, {
    int days = 30,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final today = dayOf(clock);
    final start = today.subtract(Duration(days: days - 1));
    final buckets = <DateTime, double>{};
    for (var i = 0; i < days; i++) {
      buckets[start.add(Duration(days: i))] = 0;
    }
    for (final t in transactions) {
      if (!isPaid(t)) continue;
      final day = dayOf(t.createdAt);
      if (day.isBefore(start) || day.isAfter(today)) continue;
      buckets[day] = (buckets[day] ?? 0) + t.finalAmount;
    }
    final keys = buckets.keys.toList()..sort();
    return keys.map((d) => DailySales(d, buckets[d] ?? 0)).toList();
  }

  /// Bandingkan [window] hari terakhir vs [window] hari sebelumnya.
  static TrendInfo trendInfo(
    List<DailySales> daily, {
    int window = trendWindowDays,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final today = dayOf(clock);
    final currentStart = today.subtract(Duration(days: window - 1));
    final previousStart = currentStart.subtract(Duration(days: window));
    final previousEnd = currentStart.subtract(const Duration(days: 1));

    var current = 0.0;
    var previous = 0.0;
    for (final d in daily) {
      final day = dayOf(d.date);
      if (day.isBefore(currentStart) || day.isAfter(today)) {
        if (!day.isBefore(previousStart) && !day.isAfter(previousEnd)) {
          previous += d.amount;
        }
        continue;
      }
      current += d.amount;
    }

    final trend = classify(current, previous);
    return TrendInfo(current: current, previous: previous, trend: trend);
  }

  static ProgressTrend classify(double current, double previous) {
    if (previous <= 0 && current <= 0) return ProgressTrend.flat;
    if (previous <= 0) return ProgressTrend.up;
    final change = ((current - previous) / previous) * 100;
    if (change > flatThresholdPercent) return ProgressTrend.up;
    if (change < -flatThresholdPercent) return ProgressTrend.down;
    return ProgressTrend.flat;
  }

  /// Omzet bulan berjalan (1 s/d hari ini).
  static double monthToDate(
    List<Transaction> transactions, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    var total = 0.0;
    for (final t in transactions) {
      if (!isPaid(t)) continue;
      if (t.createdAt.year != clock.year || t.createdAt.month != clock.month) {
        continue;
      }
      if (t.createdAt.isAfter(clock)) continue;
      total += t.finalAmount;
    }
    return total;
  }

  static ({int done, int total}) prescriptionProgress(
    Map<String, dynamic>? prescription,
  ) {
    final raw = prescription?['items'];
    if (raw is! List || raw.isEmpty) return (done: 0, total: 0);
    var done = 0;
    for (final item in raw) {
      if (item is Map && item['done'] == true) done++;
    }
    return (done: done, total: raw.length);
  }

  static ProgressTrackerReport build({
    required List<Transaction> transactions,
    Map<String, dynamic>? target,
    Map<String, dynamic>? prescription,
    List<Map<String, dynamic>> actionLogs = const [],
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final daily = dailySales(transactions, days: 30, now: clock);
    final salesTrend = trendInfo(daily, now: clock);

    final today = dayOf(clock);
    var todaySales = 0.0;
    for (final d in daily) {
      if (sameDay(d.date, today)) todaySales = d.amount;
    }

    final period = target?['period']?.toString() == 'month' ? 'month' : 'day';
    final targetAmount = (target?['target_amount'] as num?)?.toDouble() ?? 0;
    final targetSales =
        period == 'month' ? monthToDate(transactions, now: clock) : todaySales;

    final rx = prescriptionProgress(prescription);

    var done = 0;
    var running = 0;
    var planned = 0;
    for (final log in actionLogs) {
      switch (log['status']?.toString()) {
        case 'done':
          done++;
        case 'running':
          running++;
        default:
          planned++;
      }
    }

    final last7 = daily.length <= 7
        ? daily
        : daily.sublist(daily.length - 7);

    final score = scoreOf(
      trend: salesTrend.trend,
      hasTrendData: salesTrend.hasData,
      targetProgress: targetAmount > 0
          ? (targetSales / targetAmount).clamp(0.0, 1.0)
          : 0,
      hasTarget: targetAmount > 0,
      prescriptionProgress: rx.total > 0 ? rx.done / rx.total : 0,
      hasPrescription: rx.total > 0,
      actionProgress: (done + running + planned) > 0
          ? done / (done + running + planned)
          : 0,
      hasActions: (done + running + planned) > 0,
    );

    return ProgressTrackerReport(
      salesTrend: salesTrend,
      todaySales: todaySales,
      targetPeriod: period,
      targetAmount: targetAmount,
      targetSales: targetSales,
      prescriptionDone: rx.done,
      prescriptionTotal: rx.total,
      actionsDone: done,
      actionsRunning: running,
      actionsPlanned: planned,
      score: score,
      last7Days: last7,
    );
  }

  /// Skor 0-100 dari komponen yang datanya tersedia (bobot ternormalisasi).
  static int scoreOf({
    required ProgressTrend trend,
    required bool hasTrendData,
    required double targetProgress,
    required bool hasTarget,
    required double prescriptionProgress,
    required bool hasPrescription,
    required double actionProgress,
    required bool hasActions,
  }) {
    var points = 0.0;
    var weights = 0.0;

    if (hasTrendData) {
      points += switch (trend) {
        ProgressTrend.up => 100,
        ProgressTrend.flat => 62,
        ProgressTrend.down => 25,
      } *
          40;
      weights += 40;
    }
    if (hasTarget) {
      points += targetProgress.clamp(0.0, 1.0) * 100 * 30;
      weights += 30;
    }
    if (hasPrescription) {
      points += prescriptionProgress.clamp(0.0, 1.0) * 100 * 20;
      weights += 20;
    }
    if (hasActions) {
      points += actionProgress.clamp(0.0, 1.0) * 100 * 10;
      weights += 10;
    }
    if (weights <= 0) return 0;
    return (points / weights).round().clamp(0, 100);
  }
}
