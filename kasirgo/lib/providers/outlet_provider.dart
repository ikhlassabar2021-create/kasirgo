import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/outlet.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) => SupabaseService());

final outletProvider = FutureProvider<Outlet?>((ref) async {
  final outletId = ref.watch(userOutletIdProvider).valueOrNull;
  if (outletId == null) return null;
  final service = ref.read(supabaseServiceProvider);
  return service.getOutlet(outletId);
});