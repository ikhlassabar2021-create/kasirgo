import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/utils/speech_lexicon.dart';

void main() {
  group('SpeechLexicon frasa', () {
    test('memperbaiki istilah usaha umum', () {
      final lx = SpeechLexicon();
      expect(lx.correct('kasir go bagus'), 'KasirGo bagus');
      expect(lx.correct('qris statis nya error'), 'QRIS statisnya error');
      expect(lx.correct('omset nya turun'), 'Omzetnya turun');
      expect(lx.correct('stok nya habis'), 'Stoknya habis');
      expect(lx.correct('whats app nya mati'), 'WhatsAppnya mati');
    });

    test('tidak mengubah kata di dalam kata lain', () {
      final lx = SpeechLexicon();
      expect(lx.correct('bukan qrisan'), 'Bukan qrisan');
    });

    test('merapikan spasi sebelum tanda baca', () {
      final lx = SpeechLexicon();
      expect(lx.correct('stok gula  habis , besok kulakan'),
          'Stok gula habis, besok kulakan');
    });

    test('teks kosong aman', () {
      final lx = SpeechLexicon();
      expect(lx.correct('   '), '');
    });
  });

  group('SpeechLexicon kosakata outlet', () {
    test('mengoreksi nama produk salah dengar', () {
      final lx = SpeechLexicon(vocabulary: ['Gula Pasir', 'Minyak Goreng']);
      expect(lx.correct('gula paser tinggal lima'), 'Gula Pasir tinggal lima');
      expect(lx.correct('minyak goreng naik'), 'Minyak Goreng naik');
    });

    test('mengabaikan kata umum pendek', () {
      final lx = SpeechLexicon(vocabulary: ['Kopi']);
      expect(lx.correct('apa kabar hari ini'), 'Apa kabar hari ini');
    });

    test('tidak mengoreksi kata yang jauh berbeda', () {
      final lx = SpeechLexicon(vocabulary: ['Beras Premium']);
      expect(lx.correct('pelanggan ramai sekali'), 'Pelanggan ramai sekali');
    });

    test('kosakata dedupe dan abaikan kata terlalu pendek', () {
      final lx = SpeechLexicon(vocabulary: ['Gula', 'gula', 'ab', '']);
      expect(lx.vocabulary, ['Gula']);
    });
  });
}
