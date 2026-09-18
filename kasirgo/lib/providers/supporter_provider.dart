import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supporter.dart';
import 'outlet_provider.dart';

final supporterListProvider =
    FutureProvider.family<List<Supporter>, String>((ref, outletId) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.getSupporters(outletId);
});

final activeSupporterProvider =
    FutureProvider.family<Supporter?, String>((ref, outletId) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.getActiveSupporter(outletId);
});

final isSupporterProvider =
    FutureProvider.family<bool, String>((ref, outletId) async {
  final supporter = await ref.watch(activeSupporterProvider(outletId).future);
  return supporter != null && supporter.status == 'active';
});

final supporterBenefitsProvider =
    FutureProvider.family<List<SupporterBenefit>, String>((ref, outletId) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.getSupporterBenefits(outletId);
});
