import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/offline_queue.dart';

class SyncEvent {
  final String eventId;
  final String? deviceId;
  final String operation;
  final String entity;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  const SyncEvent({
    required this.eventId,
    this.deviceId,
    required this.operation,
    required this.entity,
    required this.payload,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'event_id': eventId,
        'device_id': deviceId,
        'operation': operation,
        'entity': entity,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SyncEvent.fromMap(Map<String, dynamic> map) => SyncEvent(
        eventId: map['event_id'] as String,
        deviceId: map['device_id'] as String?,
        operation: map['operation'] as String,
        entity: map['entity'] as String,
        payload: map['payload'] as Map<String, dynamic>,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}

class SyncService {
  final SupabaseClient _client = Supabase.instance.client;
  final OfflineQueue _offlineQueue = OfflineQueue();
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
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
        case 'create_debt':
          await _client.from('debts').insert(data);
          return true;
        case 'create_stock_log':
          await _client.from('stock_logs').insert(data);
          return true;
        case 'create_ppob_transaction':
          await _client.from('ppob_transactions').insert(data);
          return true;
        case 'sync_event':
          // Event-sourcing delta log sync (pondasi 5.5C)
          final entity = item['entity'] as String?;
          if (entity != null) {
            await _client.from(entity).upsert(data, onConflict: 'event_id');
            return true;
          }
          return false;
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

  Future<void> queueSyncEvent(SyncEvent event) async {
    await _offlineQueue.addToQueue('sync_event', {
      'entity': event.entity,
      'data': {
        ...event.payload,
        'event_id': event.eventId,
        'device_id': event.deviceId,
      },
    });
  }

  Future<int> getPendingQueueLength() async {
    return await _offlineQueue.getQueueLength();
  }
}
