import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/offline_queue.dart';

class SyncService {
  final SupabaseClient _client = Supabase.instance.client;
  final OfflineQueue _offlineQueue = OfflineQueue();
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<void> startPeriodicSync() async {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (await isOnline()) {
        await syncQueue();
      }
      return true;
    });
  }

  Future<void> syncQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final queue = await _offlineQueue.getQueue();
      final processedIndices = <int>[];

      for (var i = 0; i < queue.length; i++) {
        final item = queue[i];
        final success = await _processQueueItem(item);

        if (success) {
          processedIndices.add(i);
        } else {
          item['retryCount'] = (item['retryCount'] ?? 0) + 1;
          if (item['retryCount'] >= 5) {
            processedIndices.add(i);
          }
        }
      }

      for (final index in processedIndices.reversed) {
        await _offlineQueue.removeFromQueue(index);
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _processQueueItem(Map<String, dynamic> item) async {
    try {
      final operation = item['operation'] as String;
      final data = item['data'] as Map<String, dynamic>;

      switch (operation) {
        case 'create_transaction':
          await _client.from('transactions').insert(data);
          return true;
        case 'create_product':
          await _client.from('products').insert(data);
          return true;
        case 'update_product':
          final id = data['id'];
          data.remove('id');
          await _client.from('products').update(data).eq('id', id);
          return true;
        case 'update_stock':
          final productId = data['product_id'];
          final stock = data['stock'];
          await _client
              .from('products')
              .update({'stock': stock})
              .eq('id', productId);
          return true;
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> queueOperation(String operation, Map<String, dynamic> data) async {
    await _offlineQueue.addToQueue(operation, data);
  }

  Future<int> getPendingQueueLength() async {
    return await _offlineQueue.getQueueLength();
  }
}