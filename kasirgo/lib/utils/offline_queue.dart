import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineQueue {
  static const _queueKey = 'offline_queue';
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> enqueue(String action, Map<String, dynamic> data) async {
    final queue = _getQueue();
    queue.add({'action': action, 'data': data, 'timestamp': DateTime.now().toIso8601String()});
    await _prefs.setString(_queueKey, jsonEncode(queue));
  }

  List<Map<String, dynamic>> _getQueue() {
    final data = _prefs.getString(_queueKey);
    if (data == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(data));
  }

  List<Map<String, dynamic>> getPending() => _getQueue();

  Future<void> clear() async {
    await _prefs.remove(_queueKey);
  }
}