import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasirgo/services/sidak_service.dart';
import 'package:kasirgo/utils/sidak_report_pdf.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  SidakCountRow row({
    String name = 'Gula 1kg',
    double stockSystem = 10,
    double? physical,
    double costPrice = 10000,
    double basePrice = 13000,
    bool isService = false,
  }) =>
      SidakCountRow(
        productId: 'p-$name',
        name: name,
        unit: 'pcs',
        stockSystem: stockSystem,
        costPrice: costPrice,
        basePrice: basePrice,
        isService: isService,
        physical: physical,
      );

  final findings = <SidakFinding>[
    const SidakFinding(
      code: 'kas_selisih',
      title: 'Uang laci kurang',
      detail: 'Selisih Rp 60.000 dari kas seharusnya.',
      severity: 'tinggi',
      amount: -60000,
    ),
    const SidakFinding(
      code: 'stok_selisih',
      title: 'Selisih stok: Gula 1kg',
      detail: 'Sistem 10 pcs, fisik 8 pcs (-2).',
      amount: -20000,
    ),
  ];

  group('SidakReportPdf', () {
    test('verdictLabel membedakan bersih, selisih, dan perlu tindak lanjut', () {
      expect(SidakReportPdf.verdictLabel(true, 0), 'BERSIH');
      expect(SidakReportPdf.verdictLabel(false, 1), 'ADA SELISIH');
      expect(SidakReportPdf.verdictLabel(false, 2), 'ADA SELISIH');
      expect(SidakReportPdf.verdictLabel(false, 3), 'PERLU DITINDAKLANJUTI');
    });

    test('build menghasilkan PDF tidak kosong', () async {
      final rows = [row(physical: 8), row(name: 'Kopi', stockSystem: 5)];
      final bytes = await SidakReportPdf.build(
        storeName: 'Toko Test',
        periodFrom: DateTime(2026, 10, 15),
        periodTo: DateTime(2026, 10, 21),
        cashSales: 250000,
        nonCashSales: 90000,
        expectedCash: 300000,
        actualCash: 240000,
        cashDiff: -60000,
        stockValueSystem: 150000,
        stockValuePhysical: 130000,
        stockDiffValue: -20000,
        findings: findings,
        rows: rows,
        note: 'Setoran belum dihitung.',
      );
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('build aman tanpa temuan dan tanpa catatan', () async {
      final bytes = await SidakReportPdf.build(
        storeName: '',
        periodFrom: DateTime(2026, 10, 15),
        periodTo: DateTime(2026, 10, 21),
        cashSales: 0,
        nonCashSales: 0,
        expectedCash: 0,
        actualCash: 0,
        cashDiff: 0,
        stockValueSystem: 0,
        stockValuePhysical: 0,
        stockDiffValue: 0,
        findings: const [],
        rows: const [],
      );
      expect(bytes.length, greaterThan(500));
    });

    test('buildText memuat hasil, kas, stok, dan temuan', () {
      final text = SidakReportPdf.buildText(
        storeName: 'Toko Test',
        periodFrom: DateTime(2026, 10, 15),
        periodTo: DateTime(2026, 10, 21),
        cashSales: 250000,
        nonCashSales: 90000,
        expectedCash: 300000,
        actualCash: 240000,
        cashDiff: -60000,
        stockDiffValue: -20000,
        findings: findings,
        rows: [row(physical: 8)],
        note: 'Periksa setoran',
      );
      expect(text, contains('Laporan Sidak Bos'));
      expect(text, contains('ADA SELISIH'));
      expect(text, contains('Tunai: Rp 250.000'));
      expect(text, contains('Selisih: -Rp 60.000'));
      expect(text, contains('Gula 1kg: -2 pcs'));
      expect(text, contains('1. Uang laci kurang'));
      expect(text, contains('Periksa setoran'));
    });
  });

  group('SidakCountRow', () {
    test('diff dan diffValue dihitung dari stok fisik', () {
      final r = row(stockSystem: 10, physical: 8, costPrice: 10000);
      expect(r.diff, -2);
      expect(r.diffValue, -20000);
      expect(r.isChecked, isTrue);
    });

    test('fisik default sama dengan stok sistem', () {
      final r = row(stockSystem: 7);
      expect(r.physical, 7);
      expect(r.diff, 0);
      expect(r.diffValue, 0);
    });

    test('produk layanan ditandai tidak dihitung', () {
      expect(row(isService: true).isChecked, isFalse);
    });
  });

  group('SidakFinding', () {
    test('toJson dan fromJson bolak-balik utuh', () {
      final json = findings.first.toJson();
      final back = SidakFinding.fromJson(json);
      expect(back.code, 'kas_selisih');
      expect(back.title, 'Uang laci kurang');
      expect(back.severity, 'tinggi');
      expect(back.amount, -60000);
    });

    test('fromJson toleran untuk data kosong', () {
      final f = SidakFinding.fromJson(const {});
      expect(f.code, '');
      expect(f.severity, 'sedang');
      expect(f.amount, isNull);
    });
  });

  group('SidakSession', () {
    test('fromJson membaca angka dan temuan', () {
      final s = SidakSession.fromJson({
        'id': 's-1',
        'created_at': '2026-10-21T08:00:00Z',
        'kind': 'lengkap',
        'opening_cash': 50000,
        'expected_cash': 300000,
        'actual_cash': 240000,
        'cash_diff': -60000,
        'cash_sales': 250000,
        'non_cash_sales': 90000,
        'stock_value_system': 150000,
        'stock_value_physical': 130000,
        'stock_diff_value': -20000,
        'stock_checked': 12,
        'stock_diff_count': 1,
        'findings': [findings.first.toJson()],
      });
      expect(s.id, 's-1');
      expect(s.cashDiff, -60000);
      expect(s.stockDiffCount, 1);
      expect(s.findings, hasLength(1));
      expect(s.findings.first.code, 'kas_selisih');
      expect(s.isClean, isFalse);
    });

    test('isClean benar saat kas dan stok tidak berselisih', () {
      final s = SidakSession.fromJson({
        'id': 's-2',
        'cash_diff': 0,
        'stock_diff_value': 0,
        'findings': [],
      });
      expect(s.isClean, isTrue);
      expect(s.kind, 'lengkap');
      expect(s.findings, isEmpty);
    });
  });

  group('SidakService.manualFindings', () {
    final service = SidakService(
      client: SupabaseClient('http://localhost:54321', 'test-anon-key'),
    );

    test('kas selisih besar jadi temuan severity tinggi', () {
      final result = service.manualFindings(
        rows: const [],
        cashDiff: -75000,
        cashChecked: true,
      );
      expect(result, hasLength(1));
      expect(result.first.code, 'kas_selisih');
      expect(result.first.severity, 'tinggi');
    });

    test('selisih kecil severity sedang dan produk layanan dilewati', () {
      final result = service.manualFindings(
        rows: [
          row(physical: 9, costPrice: 1000),
          row(name: 'Jasa Servis', isService: true, physical: 0),
        ],
        cashDiff: 0,
        cashChecked: false,
      );
      expect(result, hasLength(1));
      expect(result.first.code, 'stok_selisih');
      expect(result.first.severity, 'sedang');
      expect(result.first.amount, -1000);
    });
  });
}
