import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/services/sync_service.dart';
import 'package:kasirgo/utils/id_gen.dart';
import 'package:kasirgo/utils/offline_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper: buat item antrean operasi stok.
// ignore_for_file: use_null_aware_elements
Map<String, dynamic> stockItem(String productId, num delta,
        {String? ts, String? eventId}) =>
    {
      'operation': 'update_stock',
      'data': {
        'product_id': productId,
        'delta': delta,
        if (eventId != null) 'event_id': eventId,
      },
      'timestamp': ts ?? '2026-10-02T10:00:00.000Z',
      'retryCount': 0,
    };

Map<String, dynamic> txItem(String id) => {
      'operation': 'create_transaction',
      'data': {'id': id, 'total_amount': 10000},
      'timestamp': '2026-10-02T10:00:05.000Z',
      'retryCount': 0,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ST12-2 OfflineQueue stress', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('300 add konkurensi + removeMany: tidak ada item hilang', () async {
      final queue = OfflineQueue();

      // Burst concurrent add (simulasi kasir mengetok cepat saat offline).
      await Future.wait([
        for (var i = 0; i < 300; i++) queue.addToQueue('sync_event', {'i': i}),
      ]);
      expect(await queue.getQueueLength(), 300);

      // Hapus setengah dalam SATU operasi (indeks genap).
      final evenIndices = <int>{for (var i = 0; i < 300; i += 2) i};
      await queue.removeMany(evenIndices);
      expect(await queue.getQueueLength(), 150);

      // Sisanya indeks ganjil, urutan terjaga.
      final rest = await queue.getQueue();
      expect(
        rest.map((e) => (e['data'] as Map)['i'] as int),
        everyElement(predicate<int>((v) => v.isOdd)),
      );
    });

    test('Tulis paralel add & remove tidak merusak antrean (race lock)',
        () async {
      final queue = OfflineQueue();
      final futures = <Future>[];
      for (var i = 0; i < 100; i++) {
        futures.add(queue.addToQueue('create_transaction', {'id': 't$i'}));
        if (i.isEven) {
          futures.add(queue.removeMany({}));
        }
      }
      await Future.wait(futures);
      expect(await queue.getQueueLength(), 100);
    });

    test('Item gagal >= maxRetries masuk dead-letter, bukan dibuang',
        () async {
      final queue = OfflineQueue();
      await queue.addToQueue('create_transaction', {'id': 'bad-1'});
      await queue.moveToDeadLetter({0: (await queue.getQueue()).first});

      expect(await queue.getQueueLength(), 0);
      expect(await queue.getDeadLetterLength(), 1);
    });

    test('getQueue setelah restart (memori kosong) tetap terbaca dari prefs',
        () async {
      final queue = OfflineQueue();
      await queue.addToQueue('create_transaction', {'id': 'persist-1'});
      // "Restart": instans baru, cache memori baru.
      final queue2 = OfflineQueue();
      final items = await queue2.getQueue();
      expect(items, hasLength(1));
      expect((items.first['data'] as Map)['id'], 'persist-1');
    });
  });

  group('ST12-2 Resolver stok (Isolate worker)', () {
    test('Delta stok terakumulasi per produk + LWW timestamp', () {
      final queue = [
        txItem('t1'),
        stockItem('p1', -2, ts: '2026-10-02T10:01:00.000Z'),
        stockItem('p2', -5, ts: '2026-10-02T10:02:00.000Z'),
        stockItem('p1', -3, ts: '2026-10-02T10:03:00.000Z'),
        txItem('t2'),
      ];

      final resolved = SyncService.prepareAndResolveConflictQueue(queue);

      // Panjang & posisi SEJAJAR dengan input (kunci anti data-loss).
      expect(resolved.length, queue.length);
      expect((resolved[0]!['data'] as Map)['id'], 't1');
      expect((resolved[4]!['data'] as Map)['id'], 't2');

      // p1 digabung di posisi pertamanya: -2 + -3 = -5.
      final p1 = resolved[1]!['data'] as Map;
      expect(p1['aggregated_delta'], -5);
      expect(p1['resolved_at'], '2026-10-02T10:03:00.000Z');

      // Slot kedua p1 jadi null (sudah digabung).
      expect(resolved[3], isNull);

      // p2 tetap di posisinya sendiri.
      final p2 = resolved[2]!['data'] as Map;
      expect(p2['aggregated_delta'], -5);
    });

    test('Idempotency: resolver dijalankan dua kali -> hasil sama', () {
      final queue = [
        stockItem('p1', -2),
        stockItem('p1', -3),
        txItem('t1'),
      ];
      final r1 = SyncService.prepareAndResolveConflictQueue(queue);
      final r2 = SyncService.prepareAndResolveConflictQueue(queue);
      expect(jsonEncode(r1), jsonEncode(r2));
    });

    test('Dedupe: event_id sama dalam satu batch hanya diproses sekali', () {
      final queue = [
        stockItem('p1', -2, eventId: 'e-1'),
        stockItem('p1', -2, eventId: 'e-1'),
        stockItem('p2', -7, eventId: 'e-2'),
      ];
      final resolved = SyncService.prepareAndResolveConflictQueue(queue);
      // p1: satu entri agregat (delta -2, bukan -4), duplikat jadi null.
      final p1 = resolved[0]!['data'] as Map;
      expect(p1['aggregated_delta'], -2);
      expect(resolved[1], isNull);
      expect(
          (resolved[2]!['data'] as Map)['aggregated_delta'], -7);
    });

    test('Beban 5000 event: resolver selesai cepat & hasil konsisten', () {
      final queue = <Map<String, dynamic>>[];
      for (var i = 0; i < 5000; i++) {
        queue.add(stockItem('p${i % 50}', -1,
            ts: DateTime(2026, 1, 1)
                .add(Duration(minutes: i))
                .toIso8601String()));
      }
      final sw = Stopwatch()..start();
      final resolved = SyncService.prepareAndResolveConflictQueue(queue);
      sw.stop();

      expect(resolved.length, 5000);
      // 50 produk -> 50 entri agregat (masing-masing -100), sisanya null.
      final aggregated = resolved.whereType<Map<String, dynamic>>().length;
      expect(aggregated, 50);
      for (final item in resolved.whereType<Map<String, dynamic>>()) {
        expect((item['data'] as Map)['aggregated_delta'], -100);
      }
      // Harus selesai jauh di bawah 1 detik (batas longgar untuk CI lambat).
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('ST12-2 IdGen', () {
    test('uuidV4 unik & berformat', () {
      final ids = {for (var i = 0; i < 1000; i++) IdGen.uuidV4()};
      expect(ids.length, 1000);
      final re = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(ids, everyElement(matches(re)));
    });

    test('deterministic: seed sama -> id sama; seed beda -> id beda', () {
      final a1 = IdGen.deterministic('tx1|prod1|0');
      final a2 = IdGen.deterministic('tx1|prod1|0');
      final b = IdGen.deterministic('tx1|prod1|1');
      final c = IdGen.deterministic('tx2|prod1|0');
      expect(a1, a2);
      expect(a1, isNot(b));
      expect(a1, isNot(c));
    });
  });
}
