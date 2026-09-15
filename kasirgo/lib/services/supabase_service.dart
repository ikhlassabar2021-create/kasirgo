import 'package:flutter/foundation.dart';
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
          .order('name');

      return (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<Product?> getProduct(String id) async {
    try {
      final response = await _client
          .from('products')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Product.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<Product?> getProductByBarcode(String outletId, String barcode) async {
    try {
      final response = await _client
          .from('products')
          .select()
          .eq('outlet_id', outletId)
          .eq('barcode', barcode)
          .maybeSingle();

      if (response == null) return null;
      return Product.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<Product>> searchProducts(String outletId, String query) async {
    try {
      final response = await _client
          .from('products')
          .select()
          .eq('outlet_id', outletId)
          .ilike('name', '%$query%')
          .order('name');

      return (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> getCategories(String outletId) async {
    try {
      final response = await _client
          .from('products')
          .select('category')
          .eq('outlet_id', outletId)
          .not('category', 'is', null);

      final categories = (response as List)
          .map((item) => item['category']?.toString() ?? '')
          .where((cat) => cat.isNotEmpty)
          .toSet()
          .toList();
      categories.sort();
      return categories;
    } catch (e) {
      return [];
    }
  }

  Future<Product?> createProduct(Product product) async {
    try {
      final data = product.toJson(includeId: product.id.isNotEmpty);
      final response = await _client
          .from('products')
          .insert(data)
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      debugPrint('createProduct error: $e');
      return null;
    }
  }

  Future<Product?> updateProduct(Product product) async {
    try {
      final response = await _client
          .from('products')
          .update(product.toJson(includeId: false))
          .eq('id', product.id)
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      debugPrint('updateProduct error: $e');
      return null;
    }
  }

  Future<bool> updateStock(String productId, int newStock) async {
    try {
      await _client
          .from('products')
          .update({
            'stock': newStock,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      await _client.from('products').delete().eq('id', id);
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

  Future<Transaction?> getTransaction(String id) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Transaction.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<Transaction?> createTransaction(Transaction transaction) async {
    try {
      final response = await _client
          .from('transactions')
          .insert(transaction.toJson())
          .select()
          .single();

      final created = Transaction.fromJson(response);

      if (transaction.items.isNotEmpty && created.id.isNotEmpty) {
        final itemRows = transaction.items
            .where((item) => item.productId.isNotEmpty)
            .map((item) => <String, dynamic>{
                  'transaction_id': created.id,
                  'product_id': item.productId,
                  'product_name': item.productName,
                  'quantity': item.quantity,
                  'unit_price': item.price,
                  'discount': 0,
                  'subtotal': item.subtotal,
                })
            .toList();

        if (itemRows.isNotEmpty) {
          await _client.from('transaction_items').insert(itemRows);
        }
      }

      return created;
    } catch (e) {
      debugPrint('createTransaction error: $e');
      return null;
    }
  }

  Future<bool> updateTransaction(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('transactions').update(data).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    try {
      await _client.from('transactions').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getTransactionItems(String transactionId) async {
    try {
      final response = await _client
          .from('transaction_items')
          .select()
          .eq('transaction_id', transactionId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTransactionItemsByOutlet(String outletId) async {
    try {
      final response = await _client
          .from('transaction_items')
          .select('*, transactions!inner(outlet_id)')
          .eq('transactions.outlet_id', outletId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> createTransactionItem(Map<String, dynamic> item) async {
    try {
      final response = await _client
          .from('transaction_items')
          .insert(item)
          .select()
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> createTransactionItems(List<Map<String, dynamic>> items) async {
    try {
      final response = await _client
          .from('transaction_items')
          .insert(items)
          .select();

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<bool> updateTransactionItem(String id, Map<String, dynamic> item) async {
    try {
      await _client.from('transaction_items').update(item).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTransactionItem(String id) async {
    try {
      await _client.from('transaction_items').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
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

  Future<Customer?> getCustomer(String id) async {
    try {
      final response = await _client
          .from('customers')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Customer.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<Customer?> createCustomer(Customer customer) async {
    try {
      final response = await _client
          .from('customers')
          .insert(customer.toJson())
          .select()
          .single();

      return Customer.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<Customer?> updateCustomer(Customer customer) async {
    try {
      final response = await _client
          .from('customers')
          .update(customer.toJson())
          .eq('id', customer.id)
          .select()
          .single();

      return Customer.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteCustomer(String id) async {
    try {
      await _client.from('customers').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
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

  Future<Employee?> getEmployee(String id) async {
    try {
      final response = await _client
          .from('employees')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Employee.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<Employee?> createEmployee(Employee employee) async {
    try {
      final response = await _client
          .from('employees')
          .insert(employee.toJson())
          .select()
          .single();

      return Employee.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<Employee?> updateEmployee(Employee employee) async {
    try {
      final response = await _client
          .from('employees')
          .update(employee.toJson())
          .eq('id', employee.id)
          .select()
          .single();

      return Employee.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteEmployee(String id) async {
    try {
      await _client.from('employees').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getSubscriptions(String outletId) async {
    try {
      final response = await _client
          .from('subscriptions')
          .select()
          .eq('outlet_id', outletId)
          .order('start_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getActiveSubscription(String outletId) async {
    try {
      final response = await _client
          .from('subscriptions')
          .select()
          .eq('outlet_id', outletId)
          .eq('payment_status', 'paid')
          .gte('end_date', DateTime.now().toIso8601String())
          .order('end_date', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> createSubscription(Map<String, dynamic> subscription) async {
    try {
      final response = await _client
          .from('subscriptions')
          .insert(subscription)
          .select()
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateSubscription(String id, Map<String, dynamic> subscription) async {
    try {
      await _client.from('subscriptions').update(subscription).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteSubscription(String id) async {
    try {
      await _client.from('subscriptions').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAiInsights(String outletId, {String? insightType}) async {
    try {
      var query = _client
          .from('ai_insights')
          .select()
          .eq('outlet_id', outletId);

      if (insightType != null) {
        query = query.eq('insight_type', insightType);
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getAiInsight(String id) async {
    try {
      final response = await _client
          .from('ai_insights')
          .select()
          .eq('id', id)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> createAiInsight(Map<String, dynamic> insight) async {
    try {
      final response = await _client
          .from('ai_insights')
          .insert(insight)
          .select()
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateAiInsight(String id, Map<String, dynamic> insight) async {
    try {
      await _client.from('ai_insights').update(insight).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAiInsight(String id) async {
    try {
      await _client.from('ai_insights').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Outlet?> getOutlet(String outletId) async {
    try {
      final response = await _client
          .from('outlets')
          .select()
          .eq('id', outletId)
          .single();

      return Outlet.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}
