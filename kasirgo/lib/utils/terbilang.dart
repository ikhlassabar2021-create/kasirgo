/// Konversi angka menjadi kata dalam Bahasa Indonesia.
///
/// Dipakai Soundbox POS agar nominal pembayaran dilantunkan dengan tegas,
/// mis. 25000 -> "dua puluh lima ribu".
class Terbilang {
  static const _satuan = [
    '',
    'satu',
    'dua',
    'tiga',
    'empat',
    'lima',
    'enam',
    'tujuh',
    'delapan',
    'sembilan',
    'sepuluh',
    'sebelas',
  ];

  static const _skala = [
    '',
    'ribu',
    'juta',
    'miliar',
    'triliun',
  ];

  /// Ubah [value] menjadi kata. Nilai dibulatkan ke bawah (satuan rupiah).
  /// Angka negatif diberi awalan "minus".
  static String convert(num value) {
    final rounded = value.isFinite ? value.round() : 0;
    if (rounded == 0) return 'nol';
    if (rounded < 0) return 'minus ${convert(-rounded)}';
    return _spell(rounded).trim();
  }

  static String _spell(int value) {
    if (value < 12) return _satuan[value];
    if (value < 20) return '${_satuan[value - 10]} belas';
    if (value < 100) {
      final sisa = value % 10;
      return '${_satuan[value ~/ 10]} puluh${sisa == 0 ? '' : ' ${_satuan[sisa]}'}';
    }
    if (value < 200) {
      final sisa = value % 100;
      return 'seratus${sisa == 0 ? '' : ' ${_spell(sisa)}'}';
    }
    if (value < 1000) {
      final sisa = value % 100;
      return '${_satuan[value ~/ 100]} ratus${sisa == 0 ? '' : ' ${_spell(sisa)}'}';
    }
    if (value < 2000) {
      final sisa = value % 1000;
      return 'seribu${sisa == 0 ? '' : ' ${_spell(sisa)}'}';
    }

    for (var i = _skala.length - 1; i >= 1; i--) {
      final divisor = _pow1000(i);
      if (value >= divisor) {
        final depan = value ~/ divisor;
        final sisa = value % divisor;
        final kata = '${_spell(depan)} ${_skala[i]}';
        return sisa == 0 ? kata : '$kata ${_spell(sisa)}';
      }
    }
    return _satuan[value % 10];
  }

  static int _pow1000(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 1000;
    }
    return result;
  }
}
