import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_db_service.dart';
import 'supabase_service.dart';

class SyncService {
  final LocalDbService _localDb;
  final SupabaseService _supabaseService;
  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncService(this._localDb, this._supabaseService);

  void startAutoSync({Duration interval = const Duration(seconds: 30)}) {
    _syncTimer = Timer.periodic(interval, (_) => syncIfOnline());
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<void> syncIfOnline() async {
    if (_isSyncing) return;
    if (!await isOnline()) return;
    _isSyncing = true;
    try {
      await _syncPendingData();
      await _pullRemoteData();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncPendingData() async {
    final pending = _localDb.getPendingSync();
    if (pending.isEmpty) return;

    final products = _localDb.getProducts().where((p) => !p.isSynced).toList();
    final transactions = _localDb.getTransactions().where((t) => !t.isSynced).toList();

    await _supabaseService.syncProducts(products);
    await _supabaseService.syncTransactions(transactions);
    await _localDb.clearPendingSync();
  }

  Future<void> _pullRemoteData() async {
    // Pull logic would be implemented based on outlet ID
  }
}