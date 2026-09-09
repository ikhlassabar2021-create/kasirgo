import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import 'outlet_provider.dart';

final localDbServiceProvider = Provider<LocalDbService>((ref) {
  final service = LocalDbService();
  service.init();
  return service;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final localDb = ref.read(localDbServiceProvider);
  final supabaseService = ref.read(supabaseServiceProvider);
  return SyncService(localDb, supabaseService);
});