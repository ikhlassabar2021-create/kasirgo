import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/customer.dart';

class LocalDatabase {
  Database? _db;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final dbFolder = await getApplicationDocumentsDirectory();
    final path = p.join(dbFolder.path, 'kasirgo_local.db');
    _db = sqlite3.open(path);
    _createTables();
    _initialized = true;
  }

  void _createTables() {
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT,
        price REAL NOT NULL,
        cost_price REAL,
        stock INTEGER DEFAULT 0,
        unit TEXT,
        barcode TEXT,
        image_local_path TEXT,
        thumb_key TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        cashier_id TEXT,
        customer_id TEXT,
        items TEXT NOT NULL,
        total_amount REAL NOT NULL,
        discount_amount REAL,
        tax_amount REAL,
        final_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        payment_status TEXT,
        notes TEXT,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        total_transactions INTEGER,
        total_spent REAL,
        last_visit TEXT,
        created_at TEXT
      )
    ''');
  }

  Database get _ensureDb {
    if (_db == null) throw StateError('Database not initialized');
    return _db!;
  }

  Future<List<Product>> getAllProducts(String outletId) async {
    final result = _ensureDb.select(
      'SELECT * FROM products WHERE outlet_id = ? AND is_active = 1 ORDER BY name',
      [outletId],
    );
    return result.map((row) => Product.fromMap(_rowToMap(result.columnNames, row))).toList();
  }

  Future<Product?> getProduct(String id) async {
    final result = _ensureDb.select(
      'SELECT * FROM products WHERE id = ?',
      [id],
    );
    if (result.isEmpty) return null;
    return Product.fromMap(_rowToMap(result.columnNames, result.first));
  }

  void insertProduct(Product product) {
    _ensureDb.execute(
      '''INSERT OR REPLACE INTO products 
      (id, outlet_id, name, category, price, cost_price, stock, unit, barcode, image_local_path, thumb_key, is_active, created_at, updated_at) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        product.id, product.outletId, product.name, product.category,
        product.price, product.costPrice, product.stock, product.unit,
        product.barcode, product.imageLocalPath, product.thumbKey,
        product.isActive ? 1 : 0,
        product.createdAt?.toIso8601String(),
        product.updatedAt?.toIso8601String(),
      ],
    );
  }

  void updateProduct(Product product) {
    _ensureDb.execute(
      '''UPDATE products SET name=?, category=?, price=?, cost_price=?, stock=?, 
      unit=?, barcode=?, image_local_path=?, thumb_key=?, is_active=?, 
      updated_at=? WHERE id=?''',
      [
        product.name, product.category, product.price, product.costPrice,
        product.stock, product.unit, product.barcode, product.imageLocalPath,
        product.thumbKey, product.isActive ? 1 : 0,
        product.updatedAt?.toIso8601String(), product.id,
      ],
    );
  }

  void deleteProduct(String id) {
    _ensureDb.execute(
      'UPDATE products SET is_active = 0 WHERE id = ?',
      [id],
    );
  }

  void updateStock(String productId, int newStock) {
    _ensureDb.execute(
      'UPDATE products SET stock = ? WHERE id = ?',
      [newStock, productId],
    );
  }

  void batchInsertProducts(List<Product> products) {
    final db = _ensureDb;
    db.execute('BEGIN TRANSACTION');
    try {
      for (final product in products) {
        insertProduct(product);
      }
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<Transaction> getAllTransactions(String outletId) {
    final result = _ensureDb.select(
      'SELECT * FROM transactions WHERE outlet_id = ? ORDER BY created_at DESC',
      [outletId],
    );
    return result.map((row) => Transaction.fromMap(_rowToMap(result.columnNames, row))).toList();
  }

  void insertTransaction(Transaction transaction) {
    _ensureDb.execute(
      '''INSERT INTO transactions 
      (id, outlet_id, cashier_id, customer_id, items, total_amount, discount_amount, 
      tax_amount, final_amount, payment_method, payment_status, notes, is_synced, created_at) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        transaction.id, transaction.outletId, transaction.cashierId,
        transaction.customerId, transaction.toJson()['items'],
        transaction.totalAmount, transaction.discountAmount,
        transaction.taxAmount, transaction.finalAmount,
        transaction.paymentMethod, transaction.paymentStatus,
        transaction.notes, 0, transaction.createdAt.toIso8601String(),
      ],
    );
  }

  List<Transaction> getUnsyncedTransactions() {
    final result = _ensureDb.select(
      'SELECT * FROM transactions WHERE is_synced = 0',
    );
    return result.map((row) => Transaction.fromMap(_rowToMap(result.columnNames, row))).toList();
  }

  void markTransactionSynced(String id) {
    _ensureDb.execute(
      'UPDATE transactions SET is_synced = 1 WHERE id = ?',
      [id],
    );
  }

  List<Customer> getAllCustomers(String outletId) {
    final result = _ensureDb.select(
      'SELECT * FROM customers WHERE outlet_id = ? ORDER BY name',
      [outletId],
    );
    return result.map((row) => Customer.fromMap(_rowToMap(result.columnNames, row))).toList();
  }

  void insertCustomer(Customer customer) {
    _ensureDb.execute(
      '''INSERT OR REPLACE INTO customers 
      (id, outlet_id, name, phone, email, address, total_transactions, 
      total_spent, last_visit, created_at) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        customer.id, customer.outletId, customer.name, customer.phone,
        customer.email, customer.address, customer.totalTransactions,
        customer.totalSpent, customer.lastVisit?.toIso8601String(),
        customer.createdAt?.toIso8601String(),
      ],
    );
  }

  void close() {
    _db?.dispose();
    _db = null;
    _initialized = false;
  }

  Map<String, dynamic> _rowToMap(List<String> columns, Row row) {
    final map = <String, dynamic>{};
    for (var i = 0; i < columns.length; i++) {
      map[columns[i]] = row[i];
    }
    return map;
  }
}