import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/order_service.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

/// Jumlah pesanan yang belum diproses (online belum dikonfirmasi bayar +
/// dine-in belum dibayar). Dipakai badge "Pesanan Masuk" di dashboard
/// owner/admin/kasir agar pesanan baru tidak terlewat.
final pendingOrderCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final outletId = ref.watch(currentUserProvider.select((u) => u?.outletId));
  if (outletId == null || outletId.isEmpty) return 0;
  try {
    final online = await OrderService().pendingPaymentOrders(outletId);
    final dineIn = await SupabaseService().getDineInOrders(outletId, limit: 50);
    final unpaid = dineIn
        .where((t) => t.paymentStatus == 'unpaid' && t.orderStatus != 'selesai')
        .length;
    return online.where((o) => o.status != 'dibatalkan').length + unpaid;
  } catch (_) {
    return 0;
  }
});