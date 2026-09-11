import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) => SyncService());

final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final syncService = ref.watch(syncServiceProvider);
  while (true) {
    yield await syncService.isOnline();
    await Future.delayed(const Duration(seconds: 10));
  }
});

final pendingSyncProvider = FutureProvider<int>((ref) async {
  final syncService = ref.watch(syncServiceProvider);
  return await syncService.getPendingQueueLength();
});