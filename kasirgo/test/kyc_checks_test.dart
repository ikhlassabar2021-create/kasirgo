import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/utils/kyc_checks.dart';

void main() {
  group('isValidNikFormat', () {
    test('menolak kosong / pendek / panjang', () {
      expect(isValidNikFormat(null), isFalse);
      expect(isValidNikFormat(''), isFalse);
      expect(isValidNikFormat('12345'), isFalse);
      expect(isValidNikFormat('12345678901234567'), isFalse);
    });

    test('menolak kode wilayah tak wajar', () {
      expect(isValidNikFormat('0101010101010001'), isFalse);
      expect(isValidNikFormat('9501010101010001'), isFalse);
    });

    test('menerima NIK laki-laki valid', () {
      expect(isValidNikFormat('3201010101800001'), isTrue);
    });

    test('menerima NIK perempuan (tanggal +40)', () {
      expect(isValidNikFormat('3201014101800001'), isTrue);
    });

    test('menolak tanggal/bulan tak valid', () {
      expect(isValidNikFormat('3201019901800001'), isFalse); // day 99
      expect(isValidNikFormat('3201011313800001'), isFalse); // month 13
    });

    test('membersihkan spasi/tanda baca', () {
      expect(isValidNikFormat('3201 0101 0180 0001'), isTrue);
      expect(isValidNikFormat('3201.0101.0180.0001'), isTrue);
    });
  });

  group('extractNikFromText', () {
    test('ambil 16 digit valid dari teks OCR', () {
      const text = 'PROVINSI JAWA TIMUR\nNIK : 3201010101800001\nNama : BUDI';
      expect(extractNikFromText(text), '3201010101800001');
    });

    test('prioritas angka setelah label NIK', () {
      const text = 'No 1234567890123456\nNIK 3201010101800001';
      expect(extractNikFromText(text), '3201010101800001');
    });

    test('null bila tidak ada 16 digit valid', () {
      expect(extractNikFromText('NIK 123'), isNull);
      expect(extractNikFromText('0000000000000000'), isNull);
    });
  });

  group('extractNameFromText', () {
    test('ambil nama setelah label', () {
      const text = 'NIK : 3201010101800001\nNama : BUDI SANTOSO\nAlamat : ...';
      expect(extractNameFromText(text), 'BUDI SANTOSO');
    });

    test('fallback baris kapital', () {
      const text = 'KARTU TANDA PENDUDUK\nREPUBLIK INDONESIA\nSITI AMINAH';
      expect(extractNameFromText(text), 'SITI AMINAH');
    });
  });

  group('namesMatch', () {
    test('cocok saat token lengkap', () {
      expect(namesMatch('Budi Santoso', 'BUDI SANTOSO'), isTrue);
    });

    test('cocok meski beda urutan', () {
      expect(namesMatch('Santoso Budi', 'BUDI SANTOSO'), isTrue);
    });

    test('abaikan gelar/honorifik', () {
      expect(namesMatch('H. Budi Santoso', 'BUDI SANTOSO'), isTrue);
    });

    test('tidak cocok saat nama berbeda', () {
      expect(namesMatch('Ahmad Fauzi', 'BUDI SANTOSO'), isFalse);
    });

    test('dianggap cocok bila KTP tak terbaca (review manual)', () {
      expect(namesMatch('Budi Santoso', null), isTrue);
      expect(namesMatch('Budi Santoso', ''), isTrue);
    });
  });
}