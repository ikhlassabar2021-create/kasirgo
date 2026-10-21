import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/models/transaction.dart';
import 'package:kasirgo/utils/progress_tracker.dart';

Transaction tx(
  double amount, {
  required DateTime at,
  String? paymentStatus = 'paid',
  String id = 'tx',
}) =>
    Transaction(
      id: id,
      outletId: 'outlet-1',
      totalAmount: amount,
      finalAmount: amount,
      paymentMethod: 'cash',
      paymentStatus: paymentStatus,
      createdAt: at,
    );

void main() {
  final now = DateTime(2026, 10, 21, 15);

  group('isPaid', () {
    test('status kosong dianggap lunas', () {
      expect(ProgressTracker.isPaid(tx(1000, at: now, paymentStatus: null)),
          isTrue);
      expect(ProgressTracker.isPaid(tx(1000, at: now, paymentStatus: '')),
          isTrue);
    });

    test('status lunas dikenali', () {
      for (final s in ['paid', 'completed', 'success', 'settlement', 'capture']) {
        expect(ProgressTracker.isPaid(tx(1000, at: now, paymentStatus: s)),
            isTrue, reason: s);
      }
    });

    test('status belum bayar tidak dihitung', () {
      expect(ProgressTracker.isPaid(tx(1000, at: now, paymentStatus: 'unpaid')),
          isFalse);
      expect(ProgressTracker.isPaid(tx(1000, at: now, paymentStatus: 'pending')),
          isFalse);
    });
  });

  group('classify', () {
    test('naik bila kenaikan di atas 5 persen', () {
      expect(ProgressTracker.classify(120, 100), ProgressTrend.up);
    });

    test('flat bila perubahan dalam rentang 5 persen', () {
      expect(ProgressTracker.classify(104, 100), ProgressTrend.flat);
      expect(ProgressTracker.classify(96, 100), ProgressTrend.flat);
      expect(ProgressTracker.classify(100, 100), ProgressTrend.flat);
    });

    test('turun bila penurunan di atas 5 persen', () {
      expect(ProgressTracker.classify(80, 100), ProgressTrend.down);
    });

    test('sebelumnya nol lalu ada omzet = naik', () {
      expect(ProgressTracker.classify(5000, 0), ProgressTrend.up);
    });

    test('dua-duanya nol = flat', () {
      expect(ProgressTracker.classify(0, 0), ProgressTrend.flat);
    });
  });

  group('dailySales', () {
    test('membagi omzet ke hari dan mengabaikan transaksi belum bayar', () {
      final daily = ProgressTracker.dailySales(
        [
          tx(10000, at: DateTime(2026, 10, 21, 9), id: 'a'),
          tx(5000, at: DateTime(2026, 10, 21, 20), id: 'b'),
          tx(7000, at: DateTime(2026, 10, 20, 11), id: 'c'),
          tx(9000,
              at: DateTime(2026, 10, 21, 12),
              paymentStatus: 'unpaid',
              id: 'd'),
          tx(3000, at: DateTime(2026, 9, 1, 8), id: 'e'),
        ],
        days: 7,
        now: now,
      );

      expect(daily.length, 7);
      expect(daily.last.date, DateTime(2026, 10, 21));
      expect(daily.last.amount, 15000);
      expect(daily[5].amount, 7000);
      expect(daily.first.amount, 0);
      expect(daily.map((d) => d.amount).reduce((a, b) => a + b), 22000);
    });
  });

  group('trendInfo', () {
    test('membandingkan 7 hari terakhir dengan 7 hari sebelumnya', () {
      final daily = ProgressTracker.dailySales(
        [
          tx(10000, at: DateTime(2026, 10, 20), id: 'a'),
          tx(10000, at: DateTime(2026, 10, 21), id: 'b'),
          tx(5000, at: DateTime(2026, 10, 12), id: 'c'),
        ],
        days: 30,
        now: now,
      );
      final info = ProgressTracker.trendInfo(daily, now: now);

      expect(info.current, 20000);
      expect(info.previous, 5000);
      expect(info.trend, ProgressTrend.up);
      expect(info.hasData, isTrue);
      expect(info.changePercent, 300);
    });

    test('tanpa transaksi = flat tanpa data', () {
      final info = ProgressTracker.trendInfo(const [], now: now);
      expect(info.current, 0);
      expect(info.previous, 0);
      expect(info.trend, ProgressTrend.flat);
      expect(info.hasData, isFalse);
      expect(info.changePercent, 0);
    });

    test('sebelumnya nol lalu ada omzet = change 100 persen', () {
      const info =
          TrendInfo(current: 40000, previous: 0, trend: ProgressTrend.up);
      expect(info.changePercent, 100);
    });
  });

  group('monthToDate', () {
    test('hanya menghitung bulan berjalan dan transaksi lunas', () {
      final total = ProgressTracker.monthToDate(
        [
          tx(10000, at: DateTime(2026, 10, 1), id: 'a'),
          tx(5000, at: DateTime(2026, 10, 21), id: 'b'),
          tx(9000, at: DateTime(2026, 9, 30), id: 'c'),
          tx(7000,
              at: DateTime(2026, 10, 10), paymentStatus: 'unpaid', id: 'd'),
        ],
        now: now,
      );
      expect(total, 15000);
    });
  });

  group('prescriptionProgress', () {
    test('null atau kosong = nol', () {
      expect(ProgressTracker.prescriptionProgress(null), (done: 0, total: 0));
      expect(ProgressTracker.prescriptionProgress({'items': []}),
          (done: 0, total: 0));
    });

    test('menghitung langkah bertanda done', () {
      final result = ProgressTracker.prescriptionProgress({
        'items': [
          {'title': 'A', 'done': true},
          {'title': 'B', 'done': false},
          {'title': 'C', 'done': true},
        ],
      });
      expect(result.done, 2);
      expect(result.total, 3);
    });
  });

  group('scoreOf', () {
    test('tanpa data sama sekali = 0', () {
      expect(
        ProgressTracker.scoreOf(
          trend: ProgressTrend.flat,
          hasTrendData: false,
          targetProgress: 0,
          hasTarget: false,
          prescriptionProgress: 0,
          hasPrescription: false,
          actionProgress: 0,
          hasActions: false,
        ),
        0,
      );
    });

    test('bobot ternormalisasi: tren naik saja = 100', () {
      expect(
        ProgressTracker.scoreOf(
          trend: ProgressTrend.up,
          hasTrendData: true,
          targetProgress: 0,
          hasTarget: false,
          prescriptionProgress: 0,
          hasPrescription: false,
          actionProgress: 0,
          hasActions: false,
        ),
        100,
      );
    });

    test('tren turun saja = 25', () {
      expect(
        ProgressTracker.scoreOf(
          trend: ProgressTrend.down,
          hasTrendData: true,
          targetProgress: 0,
          hasTarget: false,
          prescriptionProgress: 0,
          hasPrescription: false,
          actionProgress: 0,
          hasActions: false,
        ),
        25,
      );
    });

    test('kombinasi tren naik + target penuh = 100', () {
      expect(
        ProgressTracker.scoreOf(
          trend: ProgressTrend.up,
          hasTrendData: true,
          targetProgress: 1,
          hasTarget: true,
          prescriptionProgress: 0,
          hasPrescription: false,
          actionProgress: 0,
          hasActions: false,
        ),
        100,
      );
    });

    test('nilai progres di-clamp ke 0-100', () {
      // Tren flat (62) + semua komponen progres >100% di-clamp ke 100%:
      // (62*40 + 100*30 + 100*20 + 100*10) / 100 = 84,8 -> 85.
      expect(
        ProgressTracker.scoreOf(
          trend: ProgressTrend.flat,
          hasTrendData: true,
          targetProgress: 5,
          hasTarget: true,
          prescriptionProgress: 3,
          hasPrescription: true,
          actionProgress: 9,
          hasActions: true,
        ),
        85,
      );
    });
  });

  group('build & verdict', () {
    test('outlet baru tanpa data = "Data belum cukup"', () {
      final report = ProgressTracker.build(
        transactions: const [],
        now: now,
      );
      expect(report.hasData, isFalse);
      expect(report.verdict, 'Data belum cukup');
      expect(report.score, 0);
      expect(report.trendLabel, 'masih sama');
      expect(report.trendText, 'Belum ada penjualan untuk dibandingkan');
      expect(report.last7Days.length, 7);
    });

    test('omzet naik + target bulan tercapai = membaik', () {
      final report = ProgressTracker.build(
        transactions: [
          tx(200000, at: DateTime(2026, 10, 21), id: 'a'),
          tx(50000, at: DateTime(2026, 10, 12), id: 'b'),
        ],
        target: {'period': 'month', 'target_amount': 250000},
        now: now,
      );
      expect(report.salesTrend.trend, ProgressTrend.up);
      expect(report.targetPeriod, 'month');
      expect(report.targetSales, 250000);
      expect(report.targetPercent, 100);
      expect(report.score, 100);
      expect(report.verdict, 'Usaha Anda membaik');
      expect(report.hasTarget, isTrue);
    });

    test('omzet turun + target jauh = menurun', () {
      final report = ProgressTracker.build(
        transactions: [
          tx(10000, at: DateTime(2026, 10, 21), id: 'a'),
          tx(90000, at: DateTime(2026, 10, 12), id: 'b'),
        ],
        target: {'period': 'day', 'target_amount': 500000},
        now: now,
      );
      expect(report.salesTrend.trend, ProgressTrend.down);
      expect(report.targetPeriod, 'day');
      expect(report.targetSales, 10000);
      expect(report.score, lessThan(45));
      expect(report.verdict, 'Usaha Anda menurun');
    });

    test('resep & aksi ikut dihitung', () {
      final report = ProgressTracker.build(
        transactions: [tx(50000, at: DateTime(2026, 10, 21), id: 'a')],
        prescription: {
          'items': [
            {'done': true},
            {'done': true},
          ],
        },
        actionLogs: [
          {'status': 'done'},
          {'status': 'running'},
          {'status': 'planned'},
        ],
        now: now,
      );
      expect(report.prescriptionDone, 2);
      expect(report.prescriptionTotal, 2);
      expect(report.prescriptionPercent, 100);
      expect(report.actionsDone, 1);
      expect(report.actionsRunning, 1);
      expect(report.actionsPlanned, 1);
      expect(report.actionsTotal, 3);
      expect(report.hasPrescription, isTrue);
    });

    test('target harian memakai omzet hari ini', () {
      final report = ProgressTracker.build(
        transactions: [
          tx(25000, at: DateTime(2026, 10, 21, 8), id: 'a'),
          tx(25000, at: DateTime(2026, 10, 20, 8), id: 'b'),
        ],
        target: {'period': 'day', 'target_amount': 100000},
        now: now,
      );
      expect(report.todaySales, 25000);
      expect(report.targetSales, 25000);
      expect(report.targetPercent, 25);
    });

    test('maxDaily dari 7 hari terakhir', () {
      final report = ProgressTracker.build(
        transactions: [
          tx(15000, at: DateTime(2026, 10, 20), id: 'a'),
          tx(40000, at: DateTime(2026, 10, 21), id: 'b'),
        ],
        now: now,
      );
      expect(report.last7Days.length, 7);
      expect(report.maxDaily, 40000);
    });
  });

  group('label tren', () {
    test('label & title sesuai spesifikasi', () {
      expect(ProgressTrend.up.label, 'membaik');
      expect(ProgressTrend.flat.label, 'masih sama');
      expect(ProgressTrend.down.label, 'menurun');
      expect(ProgressTrend.up.title, 'Membaik');
      expect(ProgressTrend.flat.title, 'Masih sama');
      expect(ProgressTrend.down.title, 'Menurun');
    });
  });
}
