/// Perbaikan hasil transkrip suara (STT) untuk istilah usaha UMKM.
///
/// Mesin STT (Google/Web Speech) cukup baik untuk bahasa Indonesia umum,
/// tetapi sering salah pada istilah khas warung: "kasir go", "omset",
/// "qris", "kulakan", nama produk, dan merek. Kelas ini memperbaiki hasil
/// transkrip memakai dua lapis:
///
/// 1. Kamus frasa tetap ([phrases]) - pemetaan ejaan salah yang sering muncul.
/// 2. Koreksi jarak edit terhadap kosakata outlet ([vocabulary]) - nama produk
///    dan istilah yang dipakai warung ini, sehingga "gula paser" menjadi
///    "Gula Pasir" bila produk itu memang ada di katalog.
///
/// Semua proses lokal, tanpa jaringan dan tanpa biaya.
class SpeechLexicon {
  /// Ejaan salah (huruf kecil) -> bentuk baku.
  static const Map<String, String> phrases = {
    'kasir go': 'KasirGo',
    'kasirgo': 'KasirGo',
    'kasir gu': 'KasirGo',
    'qris': 'QRIS',
    'kris': 'QRIS',
    'krisq': 'QRIS',
    'qr is': 'QRIS',
    'qriss': 'QRIS',
    'q r i s': 'QRIS',
    'omset': 'omzet',
    'omset nya': 'omzetnya',
    'omzet nya': 'omzetnya',
    'omsetku': 'omzetku',
    'stok nya': 'stoknya',
    'stock': 'stok',
    'stokan': 'stok',
    'untung nya': 'untungnya',
    'rugi nya': 'ruginya',
    'laba nya': 'labanya',
    'modal nya': 'modalnya',
    'harga nya': 'harganya',
    'diskon nya': 'diskonnya',
    'promo nya': 'promonya',
    'kulakan': 'kulakan',
    'kulak an': 'kulakan',
    'kulak': 'kulak',
    'grosir': 'grosir',
    'grosiran': 'grosiran',
    'sembako': 'sembako',
    'sembakoan': 'sembako',
    'warung madura': 'warung Madura',
    'madura': 'Madura',
    'kelontong': 'kelontong',
    'kasbon': 'kasbon',
    'kas bon': 'kasbon',
    'piutang': 'piutang',
    'hutang': 'utang',
    'hutangnya': 'utangnya',
    'pelanggan': 'pelanggan',
    'langganan': 'langganan',
    'karyawan': 'karyawan',
    'pegawai': 'pegawai',
    'shift': 'shift',
    'sif': 'shift',
    'struk': 'struk',
    'nota': 'nota',
    'bon': 'bon',
    'wa': 'WhatsApp',
    'whats app': 'WhatsApp',
    'whatsap': 'WhatsApp',
    'whatsapp': 'WhatsApp',
    'wa bisnis': 'WhatsApp Bisnis',
    'tiktok': 'TikTok',
    'tik tok': 'TikTok',
    'shopee': 'Shopee',
    'shope': 'Shopee',
    'gofood': 'GoFood',
    'go food': 'GoFood',
    'grabfood': 'GrabFood',
    'grab food': 'GrabFood',
    'transfer': 'transfer',
    'tunai': 'tunai',
    'cash': 'tunai',
    'qris statis': 'QRIS statis',
    'qris dinamis': 'QRIS dinamis',
    'resep': 'resep',
    'diagnosa': 'diagnosa',
    'diagnosis': 'diagnosa',
    'dokter bisnis': 'Dokter Bisnis',
    'dokter bisnis ai': 'Dokter Bisnis AI',
    'doktor': 'dokter',
    'ai': 'AI',
    'rp': 'Rp',
    'rupiah': 'rupiah',
    'ribu': 'ribu',
    'rb': 'ribu',
    'juta': 'juta',
    'persen': 'persen',
    'prosen': 'persen',
  };

  /// Kata yang tidak boleh dikoreksi jarak edit (kata umum pendek).
  static const Set<String> _protected = {
    'yang', 'dan', 'dengan', 'untuk', 'saya', 'kami', 'kita', 'anda',
    'ini', 'itu', 'apa', 'ada', 'tidak', 'bukan', 'sudah', 'belum',
    'mau', 'bisa', 'harus', 'akan', 'dari', 'pada', 'juga', 'saja',
    'lagi', 'hari', 'bulan', 'tahun', 'minggu', 'berapa', 'bagaimana',
    'kenapa', 'mengapa', 'kapan', 'siapa', 'dimana', 'mana',
  };

  final Map<String, String> _phraseMap;
  final List<String> _vocabulary;
  final Map<String, String> _vocabLower;
  final Map<int, List<_VocabPhrase>> _vocabByWords;
  final int _vocabMaxWords;

  SpeechLexicon({List<String> vocabulary = const []})
      : _phraseMap = phrases,
        _vocabulary = _dedupe(vocabulary),
        _vocabLower = {
          for (final v in _dedupe(vocabulary)) v.toLowerCase(): v,
        },
        _vocabByWords = _groupByWords(_dedupe(vocabulary)),
        _vocabMaxWords = _maxWords(_dedupe(vocabulary));

  static Map<int, List<_VocabPhrase>> _groupByWords(List<String> items) {
    final out = <int, List<_VocabPhrase>>{};
    for (final item in items) {
      final words = _wordsOf(item);
      if (words.isEmpty) continue;
      out.putIfAbsent(words.length, () => []).add(
            _VocabPhrase(words, item),
          );
    }
    return out;
  }

  static int _maxWords(List<String> items) {
    var max = 1;
    for (final item in items) {
      final n = _wordsOf(item).length;
      if (n > max) max = n;
    }
    return max;
  }

  static List<String> _wordsOf(String text) => text
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w.toLowerCase())
      .toList(growable: false);

  static List<String> _dedupe(List<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in items) {
      final v = raw.trim();
      if (v.length < 3) continue;
      if (seen.add(v.toLowerCase())) out.add(v);
    }
    return out;
  }

  /// Kosakata yang dipakai untuk koreksi.
  List<String> get vocabulary => List.unmodifiable(_vocabulary);

  /// Perbaiki [raw] menjadi transkrip yang lebih rapi.
  String correct(String raw) {
    var t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return t;

    t = _applyPhrases(t);
    if (_vocabulary.isNotEmpty) t = _applyVocabulary(t);
    t = _fixPunctuation(t);
    t = _capitalizeFirst(t);
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _applyPhrases(String text) {
    var t = text;
    // Frasa panjang lebih dulu agar "qris statis" tidak ditimpa "qris".
    final keys = _phraseMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      final pattern = RegExp(
        r'(?<![A-Za-z0-9])' + RegExp.escape(key) + r'(?![A-Za-z0-9])',
        caseSensitive: false,
      );
      t = t.replaceAll(pattern, _phraseMap[key]!);
    }
    // STT Indonesia sering memisahkan akhiran "-nya": "omset nya" -> "omzetnya".
    t = t.replaceAllMapped(
      RegExp(r'(?<=[A-Za-z])\s+nya\b', caseSensitive: false),
      (_) => 'nya',
    );
    return t;
  }

  String _applyVocabulary(String text) {
    if (_vocabulary.isEmpty) return text;
    final tokens = text.split(' ');
    final out = <String>[];
    var i = 0;
    while (i < tokens.length) {
      var matched = false;
      // Frasa panjang (nama produk multi kata) dicoba lebih dulu.
      for (var n = _vocabMaxWords; n >= 1 && i + n <= tokens.length; n--) {
        final slice = tokens.sublist(i, i + n);
        final words = _wordsOf(slice.join(' '));
        if (words.length != n) continue;
        if (n == 1) {
          final w = words.first;
          // Kata pendek terlalu rawan salah koreksi.
          if (w.length < 4 || _protected.contains(w)) continue;
        }
        final hit = _matchPhrase(words);
        if (hit == null) continue;
        out.add(_keepEdgePunctuation(hit, slice.last));
        i += n;
        matched = true;
        break;
      }
      if (matched) continue;
      out.add(tokens[i]);
      i++;
    }
    return out.join(' ');
  }

  /// Cari kosakata terdekat untuk deretan [words] (sudah huruf kecil).
  ///
  /// Toleransi: 1 huruf untuk kata 4-6 huruf, 2 huruf untuk 7+ huruf. Untuk
  /// frasa multi kata, toleransi = jumlah kata (satu salah dengar per kata).
  String? _matchPhrase(List<String> words) {
    final joined = words.join(' ');
    final exact = _vocabLower[joined];
    if (exact != null) return exact;
    final candidates = _vocabByWords[words.length];
    if (candidates == null) return null;
    final tolerance = words.length == 1
        ? (words.first.length >= 7 ? 2 : 1)
        : words.length;
    String? best;
    var bestDistance = tolerance + 1;
    for (final candidate in candidates) {
      var distance = 0;
      var ok = true;
      for (var j = 0; j < words.length; j++) {
        final w = words[j];
        final c = candidate.words[j];
        if ((c.length - w.length).abs() > 2) {
          ok = false;
          break;
        }
        // Hindari koreksi agresif pada kata yang sangat berbeda awalnya.
        if (w.length > 3 && c.length > 3 && c[0] != w[0]) {
          ok = false;
          break;
        }
        distance += _levenshtein(w, c);
        if (distance > tolerance) {
          ok = false;
          break;
        }
      }
      if (!ok || distance > tolerance) continue;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate.original;
        if (distance == 0) break;
      }
    }
    return best;
  }

  static String _keepEdgePunctuation(String replacement, String source) {
    final trailing = RegExp(r'[,.!?]+$').firstMatch(source)?.group(0);
    return trailing == null ? replacement : '$replacement$trailing';
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        final del = prev[j + 1] + 1;
        final ins = curr[j] + 1;
        final sub = prev[j] + cost;
        var min = del < ins ? del : ins;
        if (sub < min) min = sub;
        curr[j + 1] = min;
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[b.length];
  }

  String _fixPunctuation(String text) =>
      text.replaceAllMapped(RegExp(r'\s+([,.!?])'), (m) => m.group(1) ?? '');

  String _capitalizeFirst(String text) {
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return text;
    final first = trimmed[0];
    if (first.toUpperCase() == first) return text;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }
}

class _VocabPhrase {
  const _VocabPhrase(this.words, this.original);

  final List<String> words;
  final String original;
}
