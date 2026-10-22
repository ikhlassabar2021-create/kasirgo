/// Utilitas pembersih hasil speech-to-text.
///
/// Mesin STT di HP sering mengulang kata saat sesi rekaman di-restart
/// (mengenali ulang ekor audio) sehingga muncul "omzet turun turun minggu
/// ini". Fungsi di sini dipakai bersama oleh [SpeechService] dan layar
/// Dokter Bisnis agar hasil transkrip konsisten.
library;

/// Normalisasi kata untuk pembanding: huruf kecil tanpa tanda baca.
String _normWord(String word) =>
    word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Sambung potongan transkrip baru ke transkrip sebelumnya tanpa mengulang
/// kata di bagian sambungan.
///
/// [base] transkrip yang sudah ada, [words] potongan baru dari sesi terakhir.
/// Bila awal [words] sama dengan ekor [base] (case-insensitive), bagian yang
/// tumpang tindih dibuang.
String mergeTranscriptSegments(String base, String words) {
  final b = base.trim();
  final w = words.trim();
  if (b.isEmpty) return w;
  if (w.isEmpty) return b;
  final bw = b.split(' ').where((e) => e.isNotEmpty).toList();
  final nw = w.split(' ').where((e) => e.isNotEmpty).toList();
  if (bw.isEmpty) return w;
  if (nw.isEmpty) return b;
  final max = nw.length < bw.length ? nw.length : bw.length;
  for (var n = max; n > 0; n--) {
    final tail = bw.sublist(bw.length - n).join(' ').toLowerCase();
    final head = nw.sublist(0, n).join(' ').toLowerCase();
    if (tail == head) {
      final rest = nw.sublist(n);
      return rest.isEmpty ? b : '$b ${rest.join(' ')}';
    }
  }
  return '$b $w';
}

/// Buang pengulangan kata/frasa (1-4 kata) yang berurutan langsung.
String collapseRepeats(String text) {
  final words = text.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.length < 2) return text;
  for (var n = 4; n >= 1; n--) {
    var i = 0;
    while (i + 2 * n <= words.length) {
      final a = words.sublist(i, i + n).map(_normWord).join(' ');
      final b = words.sublist(i + n, i + 2 * n).map(_normWord).join(' ');
      if (a.isNotEmpty && a == b) {
        words.removeRange(i + n, i + 2 * n);
      } else {
        i++;
      }
    }
  }
  return words.join(' ');
}

/// Rapikan spasi + buang pengulangan kata.
String cleanTranscript(String raw) =>
    collapseRepeats(raw.replaceAll(RegExp(r'\s+'), ' ').trim());
