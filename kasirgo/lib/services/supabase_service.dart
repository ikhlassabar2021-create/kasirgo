import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/customer.dart';
import '../models/employee.dart';
import '../models/outlet.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Products
  Future<List<Product>> getProducts(String outletId) async {
    final data = await _client.from('products').select().eq('outlet_id', outletId).order('name');
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<Product> createProduct(Product product) async {
    final data = await _client.from('products').insert(product.toJson()).select().single();
    return Product.fromJson(data);
  }

  Future<Product> updateProduct(Product product) async {
    final data = await _client.from('products').update(product.toJson()).eq('id', product.id).select().single();
    return Product.fromJson(data);
  }

  Future<void> deleteProduct(String id) async {
    await _client.from('products').delete().eq('id', id);
  }

  // Transactions
  Future<List<Transaction>> getTransactions(String outletId) async {
    final data = await _client.from('transactions').select('*, transaction_items(*)').eq('outlet_id', outletId).order('created_at', ascending: false);
    return (data as List).map((e) => Transaction.fromJson(e)).toList();
  }

  Future<Transaction> createTransaction(Transaction transaction) async {
    final txData = transaction.toJson();
    txData.remove('transaction_items');
    final result = await _client.from('transactions').insert(txData).select().single();
    final txId = result['id'];
    for (final item in transaction.items) {
      await _client.from('transaction_items').insert({...item.toJson(), 'transaction_id': txId});
    }
    return Transaction.fromJson({...result, 'transaction_items': transaction.items.map((e) => e.toJson()).toList()});
  }

  // Customers
  Future<List<Customer>> getCustomers(String outletId) async {
    final data = await _client.from('customers').select().eq('outlet_id', outletId).order('name');
    return (data as List).map((e) => Customer.fromJson(e)).toList();
  }

  Future<Customer> createCustomer(Customer customer) async {
    final data = await _client.from('customers').insert(customer.toJson()).select().single();
    return Customer.fromJson(data);
  }

  // Employees
  Future<List<Employee>> getEmployees(String outletId) async {
    final data = await _client.from('employees').select().eq('outlet_id', outletId).order('date', ascending: false);
    return (data as List).map((e) => Employee.fromJson(e)).toList();
  }

  // Outlet
  Future<Outlet?> getOutlet(String outletId) async {
    final data = await _client.from('outlets').select().eq('id', outletId).maybeSingle();
    if (data == null) return null;
    return Outlet.fromJson(data);
  }

  // Sync: push local data to Supabase
  Future<void> syncProducts(List<Product> products) async {
    for (final p in products) {
      try {
        final exists = await _client.from('products').select('id').eq('id', p.id).maybeSingle();
        if (exists != null) {
          await _client.from('products').update(p.toJson()).eq('id', p.id);
        } else {
          await _client.from('products').insert(p.toJson());
        }
      } catch (_) {}
    }
  }

  Future<void> syncTransactions(List<Transaction> transactions) async {
    for (final t in transactions) {
      try {
        final exists = await _client.from('transactions').select('id').eq('id', t.id).maybeSingle();
        if (exists == null) {
          final txData = t.toJson();
          txData.remove('transaction_items');
          await _client.from('transactions').insert(txData);
          for (final item in t.items) {
            await _client.from('transaction_items').insert({...item.toJson(), 'transaction_id': t.id});
          }
        }
      } catch (_) {}
    }
  }
}