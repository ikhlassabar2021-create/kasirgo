import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/outlet.dart';
import '../services/supabase_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) => SupabaseService());

final outletProvider = FutureProvider.family<Outlet?, String>((ref, outletId) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return await supabaseService.getOutlet(outletId);
});