import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/customer.dart';
import '../models/debt.dart';
import '../models/variant.dart';
import '../models/ppob.dart';

class LocalDatabase {
  Database? _db;
  bool _initialized = false;
  static const _storage = FlutterSecureStorage();
  static const _keyStorageKey = 'kasirgo_sqlcipher_key';

  Future<String> _getOrCreateEncryptionKey() async {
    String? key = await _storage.read(key: _keyStorageKey);
    if (key == null || key.isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      key = base64Url.encode(values);
      await _storage.write(key: _keyStorageKey, value: key);
    }
    return key;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    final dbFolder = await getApplicationDocumentsDirectory();
    final path = p.join(dbFolder.path, 'kasirgo_local.db');
    final encryptionKey = await _getOrCreateEncryptionKey();

    _db = sqlite3.open(path);
    // Apply SQLCipher encryption key via pragma
    _db!.execute("PRAGMA key = '$encryptionKey';");
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
        sync_status TEXT DEFAULT 'synced',
        event_id TEXT,
        device_id TEXT,
        gateway_ref TEXT,
        settlement_status TEXT DEFAULT 'n/a',
        tip_amount REAL DEFAULT 0,
        shift_id TEXT,
        debt_id TEXT,
        channel TEXT DEFAULT 'offline',
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

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS debts (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        customer_id TEXT,
        transaction_id TEXT,
        amount REAL NOT NULL,
        paid_amount REAL DEFAULT 0,
        status TEXT DEFAULT 'unpaid',
        due_date TEXT,
        note TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT NOT NULL
      )
    ''');

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS stock_logs (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        product_id TEXT,
        variant_id TEXT,
        delta REAL NOT NULL,
        reason TEXT NOT NULL,
        ref_id TEXT,
        device_id TEXT,
        event_id TEXT UNIQUE,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT NOT NULL
      )
    ''');

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS ppob_transactions (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        ppob_product_id TEXT,
        customer_ref TEXT,
        amount REAL NOT NULL,
        status TEXT DEFAULT 'pending',
        provider_ref TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT NOT NULL
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
      tax_amount, final_amount, payment_method, payment_status, notes, is_synced, 
      sync_status, event_id, device_id, gateway_ref, settlement_status, tip_amount, 
      shift_id, debt_id, channel, created_at) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        transaction.id, transaction.outletId, transaction.cashierId,
        transaction.customerId, transaction.toJson()['items'],
        transaction.totalAmount, transaction.discountAmount,
        transaction.taxAmount, transaction.finalAmount,
        transaction.paymentMethod, transaction.paymentStatus,
        transaction.notes,
        transaction.isSynced ? 1 : 0,
        transaction.syncStatus,
        transaction.eventId,
        transaction.deviceId,
        transaction.gatewayRef,
        transaction.settlementStatus,
        transaction.tipAmount,
        transaction.shiftId,
        transaction.debtId,
        transaction.channel,
        transaction.createdAt.toIso8601String(),
      ],
    );
  }

  List<Transaction> getUnsyncedTransactions() {
    final result = _ensureDb.select(
      "SELECT * FROM transactions WHERE is_synced = 0 OR sync_status = 'pending'",
    );
    return result.map((row) => Transaction.fromMap(_rowToMap(result.columnNames, row))).toList();
  }

  void markTransactionSynced(String id) {
    _ensureDb.execute(
      "UPDATE transactions SET is_synced = 1, sync_status = 'synced' WHERE id = ?",
      [id],
    );
  }

  // ==========================================
  // DEBTS (KASBON)
  // ==========================================

  List<Debt> getAllDebts(String outletId) {
    final result = _ensureDb.select(
      'SELECT * FROM debts WHERE outlet_id = ? ORDER BY created_at DESC',
      [outletId],
    );
    return result.map((row) => Debt.fromMap(_rowToMap(result.columnNames, row))).toList();
  }

  void insertDebt(Debt debt) {
    _ensureDb.execute(
      '''INSERT OR REPLACE INTO debts 
      (id, outlet_id, customer_id, transaction_id, amount, paid_amount, status, due_date, note, sync_status, created_at) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        debt.id, debt.outletId, debt.customerId, debt.transactionId,
        debt.amount, debt.paidAmount, debt.status,
        debt.dueDate?.toIso8601String(), debt.note, 'pending',
        debt.createdAt.toIso8601String(),
      ],
    );
  }

  List<Debt> getUnsyncedDebts() {
    final result = _ensureDb.select(
      "SELECT * FROM debts WHERE sync_status = 'pending'",
    );
    return result.map((row) => Debt.fromMap(_rowToMap(result.columnNames, row))).toList();
  }

  void markDebtSynced(String id) {
    _ensureDb.execute(
      "UPDATE debts SET sync_status = 'synced' WHERE id = ?",
      [id],
    );
  }

  // ==========================================
  // STOCK LOGS
  // ==========================================

  List<StockLog> getStockLogs(String outletId) {
    final result = _ensureDb.select(
      'SELECT * FROM stock_logs WHERE outlet_id = ? ORDER BY created_at DESC',
      [outletId],
    );
    return result.map((row) => StockLog.fromMap(_rowToMap(result.columnNames, row))).toList();
  }

  void insertStockLog(StockLog log) {
    _ensureDb.execute(
      '''INSERT OR REPLACE INTO stock_logs 
      (id, outlet_id, product_id, variant_id, delta, reason, ref_id, device_id, event_id, sync_status, created_at) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        log.id, log.outletId, log.productId, log.variantId,
        log.delta, log.reason, log.refId, log.deviceId, log.eventId,
        'pending', log.createdAt.toIso8601String(),
      ],
    );
  }

  List<StockLog> getUnsyncedStockLogs() {
    final result = _ensureDb.select(
      "SELECT * FROM stock_logs WHERE sync_status = 'pending'",
    );
    return result.map((row) => StockLog.fromMap(_rowToMap(result.columnNames, row))).toList();
  }

  void markStockLogSynced(String id) {
    _ensureDb.execute(
      "UPDATE stock_logs SET sync_status = 'synced' WHERE id = ?",
      [id],
    );
  }

  // ==========================================
  // PPOB TRANSACTIONS
  // ==========================================

  List<PpobTransaction> getAllPpobTransactions(String outletId) {
    final result = _ensureDb.select(
      'SELECT * FROM ppob_transactions WHERE outlet_id = ? ORDER BY created_at DESC',
      [outletId],
    );
    return result.map((row) => PpobTransaction.fromMap(_rowToMap(result.columnNames, row))).toList();
  }

  void insertPpobTransaction(PpobTransaction tx) {
    _ensureDb.execute(
      '''INSERT OR REPLACE INTO ppob_transactions 
      (id, outlet_id, ppob_product_id, customer_ref, amount, status, provider_ref, sync_status, created_at) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        tx.id, tx.outletId, tx.ppobProductId, tx.customerRef,
        tx.amount, tx.status, tx.providerRef,
        'pending', tx.createdAt.toIso8601String(),
      ],
    );
  }

  List<PpobTransaction> getUnsyncedPpobTransactions() {
    final result = _ensureDb.select(
      "SELECT * FROM ppob_transactions WHERE sync_status = 'pending'",
    );
    return result.map((row) => PpobTransaction.fromMap(_rowToMap(result.columnNames, row))).toList();
  }

  void markPpobTransactionSynced(String id) {
    _ensureDb.execute(
      "UPDATE ppob_transactions SET sync_status = 'synced' WHERE id = ?",
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
      map[columns[i]] = row.columnAt(i);
    }
    return map;
  }
}
