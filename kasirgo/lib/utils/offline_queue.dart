import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Antrean operasi offline yang aman-dikonkurensi.
///
/// Perbaikan ST12-2 (stress test result):
/// - SEMUA mutasi lewat lock serial -> tidak ada race antara addToQueue (UI)
///   dan penghapusan saat sync.
/// - Cache memori: baca prefs sekali, tulis hanya saat berubah.
/// - removeMany: SATU penulisan untuk N item (sebelumnya O(n) tulis penuh).
/// - Item gagal >= batas retry dipindah ke dead-letter, BUKAN dibuang diam-diam.
class OfflineQueue {
  static const String _queueKey = 'offline_sync_queue';
  static const String _deadLetterKey = 'offline_sync_dead_letter';
  static const int maxRetries = 5;

  List<Map<String, dynamic>>? _memory;
  Future<void> _lock = Future.value();

  Future<T> _locked<T>(Future<T> Function() body) {
    final run = _lock.then((_) => body());
    // Rantai tetap lanjut walau satu operasi gagal.
    _lock = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  Future<List<Map<String, dynamic>>> getQueue() =>
      _locked(() async => List.of(await _load()));

  Future<void> addToQueue(String operation, Map<String, dynamic> data) =>
      _locked(() async {
        final queue = await _load();
        queue.add({
          'operation': operation,
          'data': data,
          'timestamp': DateTime.now().toIso8601String(),
          'retryCount': 0,
        });
        await _store(queue);
      });

  /// Hapus banyak item dalam SATU penulisan. Indeks merujuk posisi pada
  /// snapshot yang sama (dijamin oleh lock). Indeks di luar jangkauan
  /// diabaikan dengan aman.
  Future<void> removeMany(Set<int> indices) => _locked(() async {
        if (indices.isEmpty) return;
        final queue = await _load();
        final keep = <Map<String, dynamic>>[];
        for (var i = 0; i < queue.length; i++) {
          if (!indices.contains(i)) keep.add(queue[i]);
        }
        await _store(keep);
      });

  Future<void> removeFromQueue(int index) => removeMany({index});

  /// Pindahkan item yang gagal berulang ke dead-letter agar tidak hilang
  /// dan bisa diperiksa/di-replay manual.
  Future<void> moveToDeadLetter(Map<int, Map<String, dynamic>> items) =>
      _locked(() async {
        if (items.isEmpty) return;
        final queue = await _load();
        final dead = await _loadDeadLetter();
        for (final entry in items.entries) {
          final i = entry.key;
          if (i >= 0 && i < queue.length) dead.add(queue[i]);
        }
        final keep = <Map<String, dynamic>>[];
        for (var i = 0; i < queue.length; i++) {
          if (!items.containsKey(i)) keep.add(queue[i]);
        }
        await _store(keep);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_deadLetterKey, jsonEncode(dead));
      });

  Future<int> getDeadLetterLength() async =>
      (await _loadDeadLetter()).length;

  Future<void> clearQueue() => _locked(() async {
        _memory = [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_queueKey);
      });

  Future<int> getQueueLength() async => (await _load()).length;

  Future<List<Map<String, dynamic>>> _load() async {
    if (_memory != null) return _memory!;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_queueKey);
    if (stored == null) {
      _memory = [];
      return _memory!;
    }
    try {
      final decoded = jsonDecode(stored) as List;
      _memory = decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      _memory = [];
    }
    return _memory!;
  }

  Future<List<Map<String, dynamic>>> _loadDeadLetter() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_deadLetterKey);
    if (stored == null) return [];
    try {
      final decoded = jsonDecode(stored) as List;
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _store(List<Map<String, dynamic>> queue) async {
    _memory = queue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(queue));
  }
}
