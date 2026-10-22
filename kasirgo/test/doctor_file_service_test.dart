import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/services/doctor_file_service.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  final service = DoctorFileService();

  test('CSV diekstrak apa adanya', () {
    const csv = 'produk,harga,stok\nKopi,5000,12\nRoti,3000,4\n';
    final a = service.parse(name: 'stok.csv', bytes: _bytes(csv));
    expect(a.kind, 'csv');
    expect(a.text, contains('Kopi,5000,12'));
    expect(a.truncated, isFalse);
    expect(a.chars, greaterThan(10));
  });

  test('TXT diekstrak', () {
    final a = service.parse(
      name: 'catatan.txt',
      bytes: _bytes('Omzet minggu ini 1.500.000'),
    );
    expect(a.text, contains('Omzet minggu ini'));
  });

  test('Excel xlsx dibaca per sheet', () {
    final excel = Excel.createExcel();
    final sheet = excel['Penjualan'];
    sheet.appendRow([
      TextCellValue('Produk'),
      TextCellValue('Qty'),
    ]);
    sheet.appendRow([
      TextCellValue('Teh'),
      IntCellValue(7),
    ]);
    final bytes = Uint8List.fromList(excel.encode()!);
    final a = service.parse(name: 'laporan.xlsx', bytes: bytes);
    expect(a.kind, 'xlsx');
    expect(a.text, contains('Sheet: Penjualan'));
    expect(a.text, contains('Teh'));
    expect(a.text, contains('7'));
  });

  test('format tidak didukung ditolak', () {
    expect(
      () => service.parse(name: 'gambar.png', bytes: _bytes('xx')),
      throwsA(isA<DoctorFileException>()),
    );
  });

  test('berkas kosong ditolak', () {
    expect(
      () => service.parse(name: 'kosong.csv', bytes: _bytes('   ')),
      throwsA(isA<DoctorFileException>()),
    );
  });

  test('teks panjang dipotong ke batas karakter', () {
    final long = List.filled(DoctorFileService.maxChars + 500, 'a').join();
    final a = service.parse(name: 'besar.csv', bytes: _bytes(long));
    expect(a.truncated, isTrue);
    expect(a.chars, DoctorFileService.maxChars);
  });

  test('berkas lebih dari 5 MB ditolak', () {
    final big = Uint8List(DoctorFileService.maxBytes + 1);
    expect(
      () => service.parse(name: 'besar.csv', bytes: big),
      throwsA(isA<DoctorFileException>()),
    );
  });

  test('ekstensi kosong ditolak', () {
    expect(
      () => service.parse(name: 'tanpaekstensi', bytes: _bytes('abc')),
      throwsA(isA<DoctorFileException>()),
    );
  });
}
