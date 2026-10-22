import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/utils/speech_text_utils.dart';

void main() {
  group('mergeTranscriptSegments', () {
    test('menggabungkan tanpa tumpang tindih', () {
      expect(
        mergeTranscriptSegments('omzet minggu ini', 'turun drastis'),
        'omzet minggu ini turun drastis',
      );
    });

    test('membuang kata yang tumpang tindih di sambungan', () {
      expect(
        mergeTranscriptSegments('omzet minggu', 'minggu ini turun'),
        'omzet minggu ini turun',
      );
    });

    test('membuang frasa tumpang tindih lebih dari satu kata', () {
      expect(
        mergeTranscriptSegments('stok gula pasir', 'gula pasir tinggal berapa'),
        'stok gula pasir tinggal berapa',
      );
    });

    test('tahan base kosong atau potongan kosong', () {
      expect(mergeTranscriptSegments('', 'halo bos'), 'halo bos');
      expect(mergeTranscriptSegments('halo bos', ''), 'halo bos');
      expect(mergeTranscriptSegments('   ', '  '), '');
    });

    test('potongan baru yang mengulang seluruh transkrip lama', () {
      expect(
        mergeTranscriptSegments('omzet turun', 'omzet turun minggu ini'),
        'omzet turun minggu ini',
      );
    });
  });

  group('collapseRepeats', () {
    test('membuang satu kata berulang', () {
      expect(collapseRepeats('omzet turun turun minggu ini'),
          'omzet turun minggu ini');
    });

    test('membuang frasa dua kata berulang', () {
      expect(
        collapseRepeats('stok gula pasir stok gula pasir tinggal berapa'),
        'stok gula pasir tinggal berapa',
      );
    });

    test('tidak merusak kalimat normal', () {
      expect(collapseRepeats('berapa omzet hari ini'), 'berapa omzet hari ini');
    });

    test('mengabaikan tanda baca dan huruf besar saat membandingkan', () {
      expect(collapseRepeats('Omzet, omzet turun'), 'Omzet, turun');
    });
  });

  group('cleanTranscript', () {
    test('merapikan spasi dan pengulangan', () {
      expect(
        cleanTranscript('  omzet   turun turun   minggu ini '),
        'omzet turun minggu ini',
      );
    });
  });
}
