// ponytail: no-op stub for web. Upgrade to drift+sqlite3_web when offline-web needed.
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/customer.dart';

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
  void close() {}
}
