import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasirgo/utils/doctor_result_pdf.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  final steps = <Map<String, dynamic>>[
    {'text': 'Rapikan etalase depan', 'done': true},
    {'text': 'Buat paket hemat sembako', 'done': false, 'action_key': 'bundling'},
  ];

  test('build menghasilkan PDF tidak kosong', () async {
    final bytes = await DoctorResultPdf.build(
      storeName: 'Toko Test',
      verdictTitle: 'Omzet turun karena stok tidak lengkap',
      verdictBody: 'Barang sering kosong saat pembeli datang.',
      score: 42,
      scoreHint: 'Perlu perhatian',
      targetDays: 7,
      dueDate: DateTime(2026, 11, 1),
      steps: steps,
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('build aman tanpa skor dan tanpa langkah', () async {
    final bytes = await DoctorResultPdf.build(
      storeName: '',
      verdictTitle: 'Vonis',
      verdictBody: '',
      steps: const [],
    );
    expect(bytes.length, greaterThan(500));
  });

  test('buildText memuat skor, langkah, dan status', () {
    final text = DoctorResultPdf.buildText(
      storeName: 'Toko Test',
      verdictTitle: 'Stok sering kosong',
      verdictBody: 'Lengkapi barang laris.',
      score: 85,
      targetDays: 7,
      dueDate: DateTime(2026, 11, 1),
      steps: steps,
    );
    expect(text, contains('Hasil Pemeriksaan Usaha'));
    expect(text, contains('85/100'));
    expect(text, contains('SEHAT'));
    expect(text, contains('[x] 1. Rapikan etalase depan'));
    expect(text, contains('[ ] 2. Buat paket hemat sembako'));
    expect(text, contains('Selesaikan dalam 7 hari'));
  });

  test('scoreTone memberi tiga tingkat', () {
    expect(DoctorResultPdf.scoreTone(80), 'SEHAT');
    expect(DoctorResultPdf.scoreTone(55), 'PERLU PERHATIAN');
    expect(DoctorResultPdf.scoreTone(10), 'BUTUH PENANGANAN');
  });
}
