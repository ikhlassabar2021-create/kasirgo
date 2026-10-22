import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/services/business_doctor_service.dart';

void main() {
  group('resolveFixedTranscript', () {
    test('memakai teks perbaikan saat server sukses', () {
      final out = BusinessDoctorService.resolveFixedTranscript(
        {'ok': true, 'text': 'Omzetnya turun gak sih, bos?'},
        'omset nya turun gak sih bos',
      );
      expect(out, 'Omzetnya turun gak sih, bos?');
    });

    test('memangkas spasi di teks perbaikan', () {
      final out = BusinessDoctorService.resolveFixedTranscript(
        {'ok': true, 'text': '  Stok Gula Pasir tinggal berapa  '},
        'stok gula paser tinggal berapa',
      );
      expect(out, 'Stok Gula Pasir tinggal berapa');
    });

    test('kembali ke transkrip asli saat ok=false', () {
      final out = BusinessDoctorService.resolveFixedTranscript(
        {'ok': false, 'text': 'teks lain', 'error': 'unsafe_result'},
        'stok gula paser',
      );
      expect(out, 'stok gula paser');
    });

    test('kembali ke transkrip asli saat teks kosong', () {
      final out = BusinessDoctorService.resolveFixedTranscript(
        {'ok': true, 'text': '   '},
        'kasir go kenapa laporan kosong',
      );
      expect(out, 'kasir go kenapa laporan kosong');
    });

    test('tahan respons tanpa field text', () {
      final out = BusinessDoctorService.resolveFixedTranscript(
        const {},
        'tolong kasih saran promosi',
      );
      expect(out, 'tolong kasih saran promosi');
    });
  });
}
