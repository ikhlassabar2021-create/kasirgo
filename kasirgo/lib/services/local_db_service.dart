import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/customer.dart';

class LocalDbService {
  static const _productsKey = 'local_products';
  static const _transactionsKey = 'local_transactions';
  static const _customersKey = 'local_customers';
  static const _pendingSyncKey = 'pending_sync';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Products
  List<Product> getProducts() {
    final data = _prefs.getStringList(_productsKey) ?? [];
    return data.map((e) => Product.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveProduct(Product product) async {
    final products = getProducts();
    final idx = products.indexWhere((p) => p.id == product.id);
    final updated = product.copyWith(isSynced: false, lastModified: DateTime.now());
    if (idx >= 0) {
      products[idx] = updated;
    } else {
      products.add(updated);
    }
    await _prefs.setStringList(_productsKey, products.map((e) => jsonEncode(e.toJson())).toList());
    await _addToPendingSync('product', product.id);
  }

  Future<void> saveProducts(List<Product> products) async {
    final existing = getProducts();
    for (final p in products) {
      final idx = existing.indexWhere((e) => e.id == p.id);
      if (idx >= 0) {
        existing[idx] = p.copyWith(isSynced: true);
      } else {
        existing.add(p.copyWith(isSynced: true));
      }
    }
    await _prefs.setStringList(_productsKey, existing.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> deleteProduct(String id) async {
    final products = getProducts().where((p) => p.id != id).toList();
    await _prefs.setStringList(_productsKey, products.map((e) => jsonEncode(e.toJson())).toList());
    await _addToPendingSync('delete_product', id);
  }

  // Transactions
  List<Transaction> getTransactions() {
    final data = _prefs.getStringList(_transactionsKey) ?? [];
    return data.map((e) => Transaction.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveTransaction(Transaction transaction) async {
    final transactions = getTransactions();
    final updated = Transaction(
      id: transaction.id, outletId: transaction.outletId, userId: transaction.userId,
      customerId: transaction.customerId, channel: transaction.channel,
      paymentMethod: transaction.paymentMethod, totalAmount: transaction.totalAmount,
      totalDiscount: transaction.totalDiscount, finalAmount: transaction.finalAmount,
      status: transaction.status, createdAt: transaction.createdAt ?? DateTime.now(),
      items: transaction.items, isSynced: false, lastModified: DateTime.now(),
    );
    transactions.add(updated);
    await _prefs.setStringList(_transactionsKey, transactions.map((e) => jsonEncode(e.toJson())).toList());
    await _addToPendingSync('transaction', transaction.id);
  }

  Future<void> saveTransactions(List<Transaction> transactions) async {
    final existing = getTransactions();
    for (final t in transactions) {
      final idx = existing.indexWhere((e) => e.id == t.id);
      if (idx >= 0) {
        existing[idx] = t;
      } else {
        existing.add(t);
      }
    }
    await _prefs.setStringList(_transactionsKey, existing.map((e) => jsonEncode(e.toJson())).toList());
  }

  // Customers
  List<Customer> getCustomers() {
    final data = _prefs.getStringList(_customersKey) ?? [];
    return data.map((e) => Customer.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveCustomer(Customer customer) async {
    final customers = getCustomers();
    final idx = customers.indexWhere((c) => c.id == customer.id);
    if (idx >= 0) {
      customers[idx] = customer;
    } else {
      customers.add(customer);
    }
    await _prefs.setStringList(_customersKey, customers.map((e) => jsonEncode(e.toJson())).toList());
    await _addToPendingSync('customer', customer.id);
  }

  Future<void> saveCustomers(List<Customer> customers) async {
    await _prefs.setStringList(_customersKey, customers.map((e) => jsonEncode(e.toJson())).toList());
  }

  // Pending Sync Queue
  Future<void> _addToPendingSync(String type, String id) async {
    final pending = _prefs.getStringList(_pendingSyncKey) ?? [];
    pending.add(jsonEncode({'type': type, 'id': id, 'timestamp': DateTime.now().toIso8601String()}));
    await _prefs.setStringList(_pendingSyncKey, pending);
  }

  List<Map<String, dynamic>> getPendingSync() {
    final data = _prefs.getStringList(_pendingSyncKey) ?? [];
    return data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  Future<void> clearPendingSync() async {
    await _prefs.remove(_pendingSyncKey);
  }
}