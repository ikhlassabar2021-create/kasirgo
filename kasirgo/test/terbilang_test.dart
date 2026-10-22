import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/utils/terbilang.dart';

void main() {
  group('Terbilang', () {
    test('nol dan satuan', () {
      expect(Terbilang.convert(0), 'nol');
      expect(Terbilang.convert(1), 'satu');
      expect(Terbilang.convert(9), 'sembilan');
    });

    test('belasan dan puluhan', () {
      expect(Terbilang.convert(11), 'sebelas');
      expect(Terbilang.convert(12), 'dua belas');
      expect(Terbilang.convert(19), 'sembilan belas');
      expect(Terbilang.convert(20), 'dua puluh');
      expect(Terbilang.convert(25), 'dua puluh lima');
      expect(Terbilang.convert(99), 'sembilan puluh sembilan');
    });

    test('ratusan dan ribuan', () {
      expect(Terbilang.convert(100), 'seratus');
      expect(Terbilang.convert(115), 'seratus lima belas');
      expect(Terbilang.convert(1000), 'seribu');
      expect(Terbilang.convert(25000), 'dua puluh lima ribu');
      expect(Terbilang.convert(150000), 'seratus lima puluh ribu');
      expect(Terbilang.convert(1250000), 'satu juta dua ratus lima puluh ribu');
    });

    test('juta dan miliar', () {
      expect(Terbilang.convert(1000000), 'satu juta');
      expect(Terbilang.convert(2000000000), 'dua miliar');
    });

    test('pembulatan dan negatif', () {
      expect(Terbilang.convert(24999.6), 'dua puluh lima ribu');
      expect(Terbilang.convert(-5000), 'minus lima ribu');
    });
  });
}
