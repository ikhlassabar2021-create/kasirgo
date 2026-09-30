import 'dart:math';

/// Generator ID untuk offline-first sync.
/// Tidak pakai package uuid agar APK tetap ramping.
class IdGen {
  IdGen._();

  /// UUID v4 acak (untuk id transaksi/event baru saat offline).
  static String uuidV4() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// UUID deterministik dari seed — dipakai untuk id baris turunan yang harus
  /// STABIL antar-retry (idempotency upsert), mis. transaction_items offline.
  /// Hash FNV-1a 32-bit x4 (portabel web/VM, tanpa dependensi).
  static String deterministic(String seed) {
    int fnv(int salt) {
      var hash = 0x811c9dc5 ^ salt;
      for (final c in seed.codeUnits) {
        hash = (hash ^ c) & 0xFFFFFFFF;
        hash = (hash * 0x01000193) & 0xFFFFFFFF;
      }
      return hash;
    }

    final a = fnv(0), b = fnv(1), c = fnv(2), d = fnv(3);
    String hex(int v, [int len = 8]) => v.toRadixString(16).padLeft(len, '0');
    // Format UUID v4-style: 8-4-4-4-12 dengan version nibble 4, variant 8.
    return '${hex(a)}-${hex(b & 0xffff, 4)}-4${hex(c & 0x0fff, 3)}-'
        '8${hex(d & 0x0fff, 3)}-${hex(c)}${hex(d >> 16, 4)}';
  }
}
