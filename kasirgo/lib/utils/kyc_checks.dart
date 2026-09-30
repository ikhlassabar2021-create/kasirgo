/// Helper validasi KYC murni (tanpa platform) — bisa diuji.
library;

/// Validasi format NIK Indonesia (16 digit):
/// - 6 digit pertama kode wilayah (11..94, tidak diawali 0)
/// - digit 7-12 = tanggal lahir DDMMYY (perempuan: DD + 40)
bool isValidNikFormat(String? raw) {
  final s = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  if (s.length != 16) return false;
  if (s.startsWith('0')) return false;
  final region = int.tryParse(s.substring(0, 2)) ?? 0;
  if (region < 11 || region > 94) return false;

  var day = int.tryParse(s.substring(6, 8)) ?? 0;
  if (day > 40) day -= 40; // penanda perempuan
  final month = int.tryParse(s.substring(8, 10)) ?? 0;
  final year = int.tryParse(s.substring(10, 12)) ?? 0;
  if (day < 1 || day > 31) return false;
  if (month < 1 || month > 12) return false;
  // Tahun 2 digit: 00..99 (dua digit apa pun valid secara format).
  if (year < 0 || year > 99) return false;
  return true;
}

/// Cari NIK dari teks OCR (16 digit berurutan, divalidasi format).
/// Diprioritaskan angka yang berdekatan dengan label "NIK".
String? extractNikFromText(String text) {
  final cleaned = text.replaceAll(RegExp(r'[ \t.]'), '');
  final matches = RegExp(r'\d{16}').allMatches(cleaned);
  final valid = matches
      .map((m) => m.group(0)!)
      .where(isValidNikFormat)
      .toList();
  if (valid.isEmpty) return null;

  final upper = text.toUpperCase();
  final nikIdx = upper.indexOf('NIK');
  if (nikIdx >= 0) {
    // Ambil angka 16 digit pertama setelah kemunculan "NIK".
    final after = cleaned.substring(
      nikIdx.clamp(0, cleaned.length),
    );
    final m = RegExp(r'\d{16}').firstMatch(after);
    if (m != null && isValidNikFormat(m.group(0)!)) return m.group(0);
  }
  return valid.first;
}

/// Ambil nama dari teks OCR KTP (baris setelah label "Nama").
String? extractNameFromText(String text) {
  final lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  for (var i = 0; i < lines.length; i++) {
    final up = lines[i].toUpperCase();
    if (up == 'NAMA' || up.startsWith('NAMA')) {
      final inline =
          lines[i].replaceFirst(RegExp(r'^[Nn][Aa][Mm][Aa]', caseSensitive: false), '').trim();
      if (_looksLikeName(inline)) return _cleanName(inline);
      if (i + 1 < lines.length && _looksLikeName(lines[i + 1])) {
        return _cleanName(lines[i + 1]);
      }
    }
  }
  // Fallback: baris dengan 2+ kata huruf kapital.
  for (final l in lines) {
    final letters = l.replaceAll(RegExp(r'[^A-Za-z ]'), '');
    final words = letters.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    if (words.length >= 2 &&
        l == l.toUpperCase() &&
        !l.contains('PROVINSI') &&
        !l.contains('KARTU') &&
        !l.contains('REPUBLIK')) {
      return _cleanName(l);
    }
  }
  return null;
}

bool _looksLikeName(String s) {
  final letters = s.replaceAll(RegExp(r'[^A-Za-z ]'), '').trim();
  return letters.split(RegExp(r'\s+')).where((w) => w.length > 1).length >= 2;
}

String _cleanName(String s) =>
    s.replaceAll(RegExp(r'[^A-Za-z ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Normalisasi nama untuk perbandingan (huruf kecil, tanpa gelar/honorifik).
String normalizeName(String s) {
  var t = s.toLowerCase();
  const titles = {
    'h', 'hj', 'haji', 'hajah', 'dr', 'drs', 'dra', 'ir', 'prof', 'md',
    'sh', 'se', 'st', 'mm', 'mba', 'ma', 's', 'pd',
  };
  final tokens = t
      .replaceAll(RegExp(r'[^a-z ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 1 && !titles.contains(w))
      .toList();
  tokens.sort();
  return tokens.join(' ');
}

/// Apakah nama pemilik (input) cocok dengan nama pada KTP (OCR)?
/// Cocok bila seluruh token nama KTP ada di nama input (atau sebaliknya),
/// dengan toleransi bila salah satu tidak terbaca (null/empty -> dianggap
/// tidak dapat dipastikan, dikembalikan true agar review manual).
bool namesMatch(String inputName, String? ktpName) {
  final a = normalizeName(inputName);
  final b = normalizeName(ktpName ?? '');
  if (b.isEmpty || a.isEmpty) return true; // tak bisa dipastikan
  final setA = a.split(' ').toSet();
  final setB = b.split(' ').toSet();
  if (setA.isEmpty || setB.isEmpty) return true;
  final inter = setA.intersection(setB).length;
  final minLen = setA.length < setB.length ? setA.length : setB.length;
  // Minimal 1 token sama; atau >=60% token pendek cocok.
  return inter >= 1 && (inter / minLen) >= 0.6;
}