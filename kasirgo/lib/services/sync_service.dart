import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/debt.dart';
import '../utils/id_gen.dart';
import '../utils/offline_queue.dart';
import 'local_db_service.dart';

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
      // 1) Dorong baris lokal yang belum tersinkron (SQLite -> Supabase).
      await _pushUnsyncedLocalRows();

      // 2) Proses antrean operasi generik (SharedPreferences).
      final rawQueue = await _offlineQueue.getQueue();
      if (rawQueue.isEmpty) return;

      // Resolver menjaga POSISI: item stok digabung di posisi kemunculan
      // pertamanya, duplikatnya jadi null -> indeks hasil == indeks mentah.
      // (Bug lama: indeks tidak align -> item salah terhapus = data loss.)
      final preparedQueue =
          await compute(prepareAndResolveConflictQueue, rawQueue);

      final processedIndices = <int>{};
      final deadLetters = <int, Map<String, dynamic>>{};

      for (var i = 0; i < preparedQueue.length; i++) {
        final item = preparedQueue[i];
        if (item == null) {
          // Digabung ke event agregat lain; aman dihapus.
          processedIndices.add(i);
          continue;
        }
        final success = await _processQueueItem(item);

        if (success) {
          processedIndices.add(i);
        } else {
          item['retryCount'] = (item['retryCount'] ?? 0) + 1;
          if (item['retryCount'] >= OfflineQueue.maxRetries) {
            deadLetters[i] = item;
          }
        }
      }

      await _offlineQueue.removeMany(processedIndices);
      if (deadLetters.isNotEmpty) {
        await _offlineQueue.moveToDeadLetter(deadLetters);
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Background Isolate worker: menggabungkan delta stok per produk
  /// (akumulasi atomik + LWW timestamp) dan mendeduplikasi event yang sama.
  ///
  /// Output SEJAJAR dengan input (panjang & posisi sama); slot null berarti
  /// item telah digabung ke slot lain atau duplikat event_id.
  @visibleForTesting
  static List<Map<String, dynamic>?> prepareAndResolveConflictQueue(
    List<Map<String, dynamic>> queue,
  ) {
    final stockDeltas = <String, Map<String, dynamic>>{};
    final firstStockIndex = <String, int>{};
    final seenEventIds = <String>{};
    final out = List<Map<String, dynamic>?>.filled(queue.length, null);

    for (var i = 0; i < queue.length; i++) {
      final item = queue[i];
      final operation = item['operation'] as String?;
      final data = Map<String, dynamic>.from(item['data'] as Map? ?? {});

      // Dedupe event identik (re-queue setelah crash): event_id sama = buang.
      final eventId = data['event_id'];
      if (eventId is String && eventId.isNotEmpty) {
        if (!seenEventIds.add('$operation|$eventId')) continue;
      }

      if (operation == 'update_stock' || operation == 'create_stock_log') {
        final productId = data['product_id'] as String?;
        if (productId != null) {
          final delta = (data['change_amount'] ?? data['delta'] ?? 0) as num;
          final timestamp =
              DateTime.tryParse(item['timestamp'] as String? ?? '') ??
                  DateTime.now();

          final current = stockDeltas[productId];
          if (current == null) {
            stockDeltas[productId] = {
              'delta': delta,
              'latest_timestamp': timestamp,
              'original_item': item,
            };
            firstStockIndex[productId] = i;
          } else {
            // Akumulasi delta atomik + ambil timestamp terbaru (LWW).
            current['delta'] = (current['delta'] as num) + delta;
            final prevTime = current['latest_timestamp'] as DateTime;
            if (timestamp.isAfter(prevTime)) {
              current['latest_timestamp'] = timestamp;
            }
          }
          continue;
        }
      }
      out[i] = item;
    }

    // Tulis event agregat di posisi kemunculan pertama tiap produk.
    stockDeltas.forEach((productId, summary) {
      final idx = firstStockIndex[productId]!;
      final baseItem =
          Map<String, dynamic>.from(summary['original_item'] as Map);
      final baseData = Map<String, dynamic>.from(baseItem['data'] as Map);
      baseData['aggregated_delta'] = summary['delta'];
      baseData['resolved_at'] =
          (summary['latest_timestamp'] as DateTime).toIso8601String();
      baseItem['data'] = baseData;
      out[idx] = baseItem;
    });

    return out;
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
          data.remove('is_active');
          data.remove('price');
          await _client.from('products').upsert(
                data,
                onConflict: data.containsKey('event_id') ? 'event_id' : 'id',
              );
          return true;
        case 'update_product':
          final id = data['id'];
          data.remove('id');
          data.remove('is_active');
          data.remove('price');
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

  // ============================================================
  // Push baris lokal unsynced (SQLite) -> Supabase (idempotent).
  // Stok TIDAK dikirim manual: trigger decrement_stock di server
  // berjalan saat transaction_items benar-benar INSERT (upsert yang
  // konflik id tidak men-trigger ulang -> tanpa deincrement ganda).
  // ============================================================
  Future<void> _pushUnsyncedLocalRows() async {
    final db = LocalDatabase.shared;
    if (!await db.ensureInitialized()) return;

    // 1) Transaksi + item (id item deterministik -> retry aman).
    for (final tx in db.getUnsyncedTransactions()) {
      try {
        final payload = tx.toSupabaseJson();
        payload['id'] = tx.id.isNotEmpty ? tx.id : IdGen.uuidV4();
        payload['sync_status'] = 'synced';
        payload['event_id'] =
            (tx.eventId?.isNotEmpty ?? false) ? tx.eventId : IdGen.uuidV4();
        payload['device_id'] = tx.deviceId;
        await _client.from('transactions').upsert(payload, onConflict: 'id');

        final rows = <Map<String, dynamic>>[];
        for (var i = 0; i < tx.items.length; i++) {
          final item = tx.items[i];
          if (item.productId.isEmpty) continue;
          rows.add({
            'id': IdGen.deterministic('${payload['id']}|${item.productId}|$i'),
            'transaction_id': payload['id'],
            'product_id': item.productId,
            if (item.variantId != null && item.variantId!.isNotEmpty)
              'variant_id': item.variantId,
            'product_name': item.productName,
            'quantity': item.quantity,
            'unit_price': item.price,
            'discount': 0,
            'subtotal': item.subtotal,
            if (item.note != null && item.note!.isNotEmpty) 'note': item.note,
          });
        }
        if (rows.isNotEmpty) {
          await _client
              .from('transaction_items')
              .upsert(rows, onConflict: 'id');
        }
        db.markTransactionSynced(tx.id);
      } catch (_) {
        // Tetap pending; dicoba lagi pada tick berikutnya.
      }
    }

    // 2) Kasbon.
    for (final debt in db.getUnsyncedDebts()) {
      try {
        await _client.from('debts').upsert(_debtPayload(debt),
            onConflict: 'id');
        db.markDebtSynced(debt.id);
      } catch (_) {}
    }

    // 3) Log stok (buku besar; event_id UNIQUE -> idempotent).
    for (final log in db.getUnsyncedStockLogs()) {
      try {
        final payload = {
          'id': log.id,
          'outlet_id': log.outletId,
          'product_id': log.productId,
          'variant_id': log.variantId,
          'delta': log.delta,
          'reason': log.reason,
          'ref_id': log.refId,
          'device_id': log.deviceId,
          'event_id': (log.eventId?.isNotEmpty ?? false)
              ? log.eventId
              : IdGen.uuidV4(),
          'created_at': log.createdAt.toIso8601String(),
        };
        await _client.from('stock_logs').upsert(payload, onConflict: 'event_id');
        db.markStockLogSynced(log.id);
      } catch (_) {}
    }

    // 4) Transaksi PPOB.
    for (final ptx in db.getUnsyncedPpobTransactions()) {
      try {
        await _client.from('ppob_transactions').upsert({
          'id': ptx.id,
          'outlet_id': ptx.outletId,
          'ppob_product_id': ptx.ppobProductId,
          'customer_ref': ptx.customerRef,
          'amount': ptx.amount,
          'status': ptx.status,
          'provider_ref': ptx.providerRef,
          'created_at': ptx.createdAt.toIso8601String(),
        }, onConflict: 'id');
        db.markPpobTransactionSynced(ptx.id);
      } catch (_) {}
    }
  }

  Map<String, dynamic> _debtPayload(Debt debt) => {
        'id': debt.id,
        'outlet_id': debt.outletId,
        'customer_id': debt.customerId,
        'transaction_id': debt.transactionId,
        'amount': debt.amount,
        'paid_amount': debt.paidAmount,
        'status': debt.status,
        'due_date': debt.dueDate?.toIso8601String(),
        'note': debt.note,
        'created_at': debt.createdAt.toIso8601String(),
      };

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
