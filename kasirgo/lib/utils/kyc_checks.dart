/// Helper validasi KYC murni (tanpa platform) — bisa diuji.
library;

import 'dart:typed_data';

/// Validasi format NIK Indonesia: WAJIB tepat 16 digit angka.
///
/// CATATAN (fix false-negative): dulu validator menolak NIK bila kode wilayah
/// atau tanggal lahir tidak lazim, sehingga NIK asli berjumlah 16 digit ikut
/// ditolak ("NIK harus 16 digit" padahal sudah 16). Sekarang cukup 16 digit
/// (semua angka, bukan digit seragam). Anti-data-palsu ditegakkan pada
/// verifikasi FOTO KTP (bukan pada format NIK).
bool isValidNikFormat(String? raw) {
  final s = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  if (s.length != 16) return false;
  // Tolak NIK yang jelas palsu: semua digit sama (mis. 1111... atau 0000...).
  if (RegExp(r'^(\d)\1{15}$').hasMatch(s)) return false;
  return true;
}

/// Cari NIK dari teks OCR (16 digit berurutan). Diprioritaskan angka yang
/// berdekatan dengan label "NIK". Pencarian dilakukan pada teks yang sudah
/// dinormalisasi agar indeks "NIK" dan posisi angka konsisten (fix bug offset).
String? extractNikFromText(String text) {
  final cleaned = text.replaceAll(RegExp(r'[ \t.]'), '');
  final matches =
      RegExp(r'\d{16}').allMatches(cleaned).map((m) => m.group(0)!).toList();
  if (matches.isEmpty) return null;

  final upper = cleaned.toUpperCase();
  final nikIdx = upper.indexOf('NIK');
  if (nikIdx >= 0) {
    final after = cleaned.substring(nikIdx);
    final m = RegExp(r'\d{16}').firstMatch(after);
    if (m != null) return m.group(0);
  }
  // Utamakan yang lolos format; jika tidak ada, tetap kembalikan 16 digit
  // pertama agar kolom NIK terisi dan bisa direvisi pengguna.
  final valid = matches.where(isValidNikFormat).toList();
  return valid.isNotEmpty ? valid.first : matches.first;
}

/// Validasi isi berkas berupa GAMBAR berdasarkan magic bytes. Mencegah unggahan
/// berkas palsu (PDF/teks/apk yang di-rename) untuk memalsukan KTP.
bool isLikelyImageBytes(Uint8List bytes) {
  if (bytes.length < 12) return false;
  // JPEG: FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return true;
  }
  // GIF: "GIF87a"/"GIF89a"
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
  // BMP: "BM"
  if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
  // WEBP: "RIFF"...."WEBP"
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return true;
  }
  // HEIC/HEIF: offset 4..7 == "ftyp", brand "heic"/"heif"/"mif1"/"msf1".
  if (bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (brand == 'heic' || brand == 'heif' || brand == 'mif1' || brand == 'msf1') {
      return true;
    }
  }
  return false;
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