// ponytail: no-op stub for web. Upgrade to drift+sqlite3_web when offline-web needed.
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/customer.dart';
import '../models/debt.dart';
import '../models/variant.dart';
import '../models/ppob.dart';

class LocalDatabase {
  Future<void> initialize() async {
    throw UnsupportedError('SQLite not available on web');
  }

  Future<List<Product>> getAllProducts(String outletId) async => [];
  Future<Product?> getProduct(String id) async => null;
  void insertProduct(Product product) {}
  void updateProduct(Product product) {}
  void deleteProduct(String id) {}
  void updateStock(String productId, int newStock) {}
  void batchInsertProducts(List<Product> products) {}
  List<Transaction> getAllTransactions(String outletId) => [];
  void insertTransaction(Transaction transaction) {}
  List<Transaction> getUnsyncedTransactions() => [];
  void markTransactionSynced(String id) {}
  List<Customer> getAllCustomers(String outletId) => [];
  void insertCustomer(Customer customer) {}

  // KasirGo 3.0: debts, stock_logs, ppob_transactions
  List<Debt> getAllDebts(String outletId) => [];
  void insertDebt(Debt debt) {}
  List<Debt> getUnsyncedDebts() => [];
  void markDebtSynced(String id) {}

  List<StockLog> getStockLogs(String outletId) => [];
  void insertStockLog(StockLog log) {}
  List<StockLog> getUnsyncedStockLogs() => [];
  void markStockLogSynced(String id) {}

  List<PpobTransaction> getAllPpobTransactions(String outletId) => [];
  void insertPpobTransaction(PpobTransaction tx) {}
  List<PpobTransaction> getUnsyncedPpobTransactions() => [];
  void markPpobTransactionSynced(String id) {}

  void close() {}
}

