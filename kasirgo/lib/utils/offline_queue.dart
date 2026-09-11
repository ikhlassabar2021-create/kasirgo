import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineQueue {
  static const String _queueKey = 'offline_sync_queue';

  Future<void> addToQueue(String operation, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getQueue();
    queue.add({
      'operation': operation,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'retryCount': 0,
    });
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  Future<List<Map<String, dynamic>>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_queueKey);
    if (stored == null) return [];
    final decoded = jsonDecode(stored) as List;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> removeFromQueue(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getQueue();
    if (index < queue.length) {
      queue.removeAt(index);
      await prefs.setString(_queueKey, jsonEncode(queue));
    }
  }

  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  Future<int> getQueueLength() async {
    final queue = await getQueue();
    return queue.length;
  }
}