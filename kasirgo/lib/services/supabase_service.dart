import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/customer.dart';
import '../models/outlet.dart';
import '../models/employee.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Product>> getProducts(String outletId) async {
    try {
      final response = await _client
          .from('products')
          .select()
          .eq('outlet_id', outletId)
          .eq('is_active', true)
          .order('name');

      return (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<Product?> createProduct(Product product) async {
    try {
      final response = await _client
          .from('products')
          .insert(product.toJson())
          .select()
          .single();

      return Product.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<Product?> updateProduct(Product product) async {
    try {
      final response = await _client
          .from('products')
          .update(product.toJson())
          .eq('id', product.id)
          .select()
          .single();

      return Product.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    try {
      await _client.from('products').update({'is_active': false}).eq(
        'id',
        productId,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Transaction>> getTransactions(String outletId, {int limit = 50}) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<Transaction?> createTransaction(Transaction transaction) async {
    try {
      final response = await _client
          .from('transactions')
          .insert(transaction.toJson())
          .select()
          .single();

      return Transaction.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<List<Customer>> getCustomers(String outletId) async {
    try {
      final response = await _client
          .from('customers')
          .select()
          .eq('outlet_id', outletId)
          .order('name');

      return (response as List)
          .map((json) => Customer.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<Customer?> createCustomer(Customer customer) async {
    try {
      final response = await _client
          .from('customers')
          .insert(customer.toJson())
          .select()
          .single();

      return Customer.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<Outlet?> getOutlet(String outletId) async {
    try {
      final response = await _client
          .from('outlets')
          .select()
          .eq('id', outletId)
          .single();

      return Outlet.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<List<Employee>> getEmployees(String outletId) async {
    try {
      final response = await _client
          .from('employees')
          .select()
          .eq('outlet_id', outletId)
          .order('name');

      return (response as List)
          .map((json) => Employee.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
}