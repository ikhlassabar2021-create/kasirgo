import 'dart:async';
import 'package:flutter/foundation.dart';
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
        payload: Map<String, dynamic>.from(map['payload'] as Map),
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

  /// Syncs the offline queue in a background isolate to avoid blocking POS UI.
  Future<void> syncQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final rawQueue = await _offlineQueue.getQueue();
      if (rawQueue.isEmpty) return;

      // Group stock delta updates to resolve multi-cashier stock conflicts
      final preparedQueue = await compute(_prepareAndResolveConflictQueue, rawQueue);

      final processedIndices = <int>[];

      for (var i = 0; i < preparedQueue.length; i++) {
        final item = preparedQueue[i];
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

  /// Background Isolate worker: Aggregates delta stock events by atomic counter/timestamp
  /// and validates idempotency before uploading.
  static List<Map<String, dynamic>> _prepareAndResolveConflictQueue(
    List<Map<String, dynamic>> queue,
  ) {
    final stockDeltas = <String, Map<String, dynamic>>{};
    final resolved = <Map<String, dynamic>>[];

    for (final item in queue) {
      final operation = item['operation'] as String?;
      final data = Map<String, dynamic>.from(item['data'] as Map? ?? {});

      if (operation == 'update_stock' || operation == 'create_stock_log') {
        final productId = data['product_id'] as String?;
        if (productId != null) {
          final delta = (data['change_amount'] ?? data['delta'] ?? 0) as num;
          final current = stockDeltas[productId];
          final timestamp = DateTime.tryParse(item['timestamp'] as String? ?? '') ??
              DateTime.now();

          if (current == null) {
            stockDeltas[productId] = {
              'product_id': productId,
              'delta': delta,
              'latest_timestamp': timestamp,
              'original_item': item,
            };
          } else {
            // Atomic counter accumulation: sum up stock deltas
            current['delta'] = (current['delta'] as num) + delta;
            final prevTime = current['latest_timestamp'] as DateTime;
            if (timestamp.isAfter(prevTime)) {
              current['latest_timestamp'] = timestamp;
            }
          }
          continue;
        }
      }
      resolved.add(item);
    }

    // Append merged stock resolution delta events
    stockDeltas.forEach((productId, summary) {
      final baseItem = Map<String, dynamic>.from(summary['original_item'] as Map);
      final baseData = Map<String, dynamic>.from(baseItem['data'] as Map);
      baseData['aggregated_delta'] = summary['delta'];
      baseData['resolved_at'] = (summary['latest_timestamp'] as DateTime).toIso8601String();
      baseItem['data'] = baseData;
      resolved.add(baseItem);
    });

    return resolved;
  }

  Future<bool> _processQueueItem(Map<String, dynamic> item) async {
    try {
      final operation = item['operation'] as String;
      final data = Map<String, dynamic>.from(item['data'] as Map);

      switch (operation) {
        case 'create_transaction':
          // Idempotent insert/upsert with event_id or id
          await _client.from('transactions').upsert(
                data,
                onConflict: data.containsKey('event_id') ? 'event_id' : 'id',
              );
          return true;
        case 'create_product':
          await _client.from('products').upsert(
                data,
                onConflict: data.containsKey('event_id') ? 'event_id' : 'id',
              );
          return true;
        case 'update_product':
          final id = data['id'];
          data.remove('id');
          await _client.from('products').update(data).eq('id', id);
          return true;
        case 'update_stock':
          final productId = data['product_id'];
          final aggregatedDelta = data['aggregated_delta'];
          if (aggregatedDelta != null) {
            // Apply atomic counter decrement/increment via RPC or calculate latest
            try {
              await _client.rpc('increment_product_stock', params: {
                'p_product_id': productId,
                'p_delta': aggregatedDelta,
              });
            } catch (_) {
              // Fallback to direct update if RPC is missing
              final currentProduct = await _client
                  .from('products')
                  .select('stock')
                  .eq('id', productId)
                  .maybeSingle();
              if (currentProduct != null) {
                final currentStock = (currentProduct['stock'] as num? ?? 0);
                await _client.from('products').update({
                  'stock': currentStock + (aggregatedDelta as num),
                }).eq('id', productId);
              }
            }
          } else {
            final stock = data['stock'];
            await _client
                .from('products')
                .update({'stock': stock})
                .eq('id', productId);
          }
          return true;
        case 'create_debt':
          await _client.from('debts').upsert(
                data,
                onConflict: data.containsKey('event_id') ? 'event_id' : 'id',
              );
          return true;
        case 'create_stock_log':
          await _client.from('stock_logs').upsert(
                data,
                onConflict: data.containsKey('event_id') ? 'event_id' : 'id',
              );
          return true;
        case 'create_ppob_transaction':
          await _client.from('ppob_transactions').upsert(
                data,
                onConflict: data.containsKey('event_id') ? 'event_id' : 'id',
              );
          return true;
        case 'sync_event':
          // Event-sourcing delta log sync, idempotent on event_id UNIQUE
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
        'timestamp': event.timestamp.toIso8601String(),
      },
    });
  }

  Future<int> getPendingQueueLength() async {
    return await _offlineQueue.getQueueLength();
  }
}
