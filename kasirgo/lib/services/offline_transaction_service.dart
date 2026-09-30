import '../models/transaction.dart';
import '../models/variant.dart';
import '../utils/id_gen.dart';
import 'local_db_service.dart';

/// Simpan transaksi saat OFFLINE ke SQLite lokal:
/// - transaksi (is_synced=0, event_id) -> didorong SyncService saat online
/// - stok produk lokal dikurangi (kalau produk ada di cache lokal)
/// - stock_logs (ledger, event_id) -> idempotent saat push
///
/// Stok server TIDAK dikirim manual: trigger decrement_stock berjalan saat
/// transaction_items masuk ke Supabase (sekali saja walau di-retry).
class OfflineTransactionService {
  Future<bool> saveOfflineCheckout(Transaction tx) async {
    try {
      final db = LocalDatabase.shared;
      if (!await db.ensureInitialized()) return false;

      final txId = tx.id.isNotEmpty ? tx.id : IdGen.uuidV4();
      final saved = tx.copyWith(
        id: txId,
        eventId: (tx.eventId?.isNotEmpty ?? false) ? tx.eventId : IdGen.uuidV4(),
        isSynced: false,
        syncStatus: 'pending',
      );

      for (final item in tx.items) {
        if (item.productId.isEmpty) continue;
        final local = await db.getProduct(item.productId);
        if (local != null) {
          final newStock = (local.stock - item.quantity).clamp(0, 1 << 30);
          db.updateStock(local.id, newStock);
        }
        db.insertStockLog(StockLog(
          id: IdGen.uuidV4(),
          outletId: tx.outletId,
          productId: item.productId,
          variantId: item.variantId,
          delta: -item.quantity.toDouble(),
          reason: 'sale_offline',
          refId: txId,
          eventId: IdGen.uuidV4(),
          createdAt: DateTime.now(),
        ));
      }
      db.insertTransaction(saved);
      return true;
    } catch (_) {
      return false;
    }
  }
}
