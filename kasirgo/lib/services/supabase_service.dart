import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/customer.dart';
import '../models/outlet.dart';
import '../models/employee.dart';
import '../models/supporter.dart';
import '../models/debt.dart';
import '../models/shift.dart';
import '../models/tip.dart';
import '../models/recipe.dart';
import '../models/variant.dart';
import '../models/ppob.dart';
import '../models/restock.dart';

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

  Future<List<Transaction>> getTransactions(String outletId, {int limit = 50, DateTime? startDate, DateTime? endDate}) async {
    try {
      var query = _client
          .from('transactions')
          .select()
          .eq('outlet_id', outletId);

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Transaction>> getCustomerTransactions(String customerId, {int limit = 50}) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('customer_id', customerId)
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

  Future<bool> updateEmployeeRole(String employeeId, String newRole, {String? userId, String? outletId}) async {
    try {
      await _client
          .from('employees')
          .update({'role': newRole, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', employeeId);

      if (userId != null && userId.isNotEmpty && outletId != null && outletId.isNotEmpty) {
        await _client
            .from('user_roles')
            .upsert({
              'user_id': userId,
              'outlet_id': outletId,
              'role': newRole,
            });
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAttendanceLogs(String outletId) async {
    try {
      final response = await _client
          .from('employees')
          .select()
          .eq('outlet_id', outletId)
          .order('date', ascending: false)
          .order('check_in_time', ascending: false)
          .limit(100);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> checkInEmployee({
    required String outletId,
    required String userId,
    required String shift,
    String? employeeName,
  }) async {
    try {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final row = <String, dynamic>{
        'outlet_id': outletId,
        'user_id': userId,
        'shift': shift,
        'date': dateStr,
        'check_in_time': now.toIso8601String(),
      };
      if (employeeName != null && employeeName.isNotEmpty) {
        row['name'] = employeeName;
      }
      final response = await _client
          .from('employees')
          .insert(row)
          .select()
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  Future<bool> checkOutEmployee(String attendanceId) async {
    try {
      final now = DateTime.now();
      await _client
          .from('employees')
          .update({'check_out_time': now.toIso8601String()})
          .eq('id', attendanceId);
      return true;
    } catch (e) {
      return false;
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

  // ==========================================
  // SUPPORTERS & BENEFITS (Ganti Subscriptions)
  // ==========================================

  Future<List<Supporter>> getSupporters(String outletId) async {
    try {
      final response = await _client
          .from('supporters')
          .select()
          .eq('outlet_id', outletId)
          .order('start_date', ascending: false);

      return (response as List)
          .map((json) => Supporter.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<Supporter?> getActiveSupporter(String outletId) async {
    try {
      final response = await _client
          .from('supporters')
          .select()
          .eq('outlet_id', outletId)
          .eq('status', 'active')
          .order('start_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return Supporter.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<Supporter?> createSupporter(Supporter supporter) async {
    try {
      final response = await _client
          .from('supporters')
          .insert(supporter.toJson())
          .select()
          .single();

      return Supporter.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateSupporter(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('supporters').update(data).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteSupporter(String id) async {
    try {
      await _client.from('supporters').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<SupporterBenefit>> getSupporterBenefits(String outletId) async {
    try {
      final response = await _client
          .from('supporter_benefits')
          .select()
          .eq('outlet_id', outletId);

      return (response as List)
          .map((json) => SupporterBenefit.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> setSupporterBenefit(String outletId, String benefitKey, bool enabled) async {
    try {
      await _client.from('supporter_benefits').upsert({
        'outlet_id': outletId,
        'benefit_key': benefitKey,
        'enabled': enabled,
      }, onConflict: 'outlet_id,benefit_key');
      return true;
    } catch (e) {
      return false;
    }
  }

  // Backward compatibility alias for deprecated subscriptions
  @Deprecated('Use getSupporters instead')
  Future<List<Map<String, dynamic>>> getSubscriptions(String outletId) async {
    try {
      final response = await _client
          .from('supporters')
          .select()
          .eq('outlet_id', outletId)
          .order('start_date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  @Deprecated('Use getActiveSupporter instead')
  Future<Map<String, dynamic>?> getActiveSubscription(String outletId) async {
    try {
      final s = await getActiveSupporter(outletId);
      return s?.toJson();
    } catch (e) {
      return null;
    }
  }

  @Deprecated('Use createSupporter instead')
  Future<Map<String, dynamic>?> createSubscription(Map<String, dynamic> subscription) async {
    try {
      final response = await _client
          .from('supporters')
          .insert(subscription)
          .select()
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  // ==========================================
  // DEBTS & DEBT PAYMENTS (Kasbon / Piutang)
  // ==========================================

  Future<List<Debt>> getDebts(String outletId, {String? status}) async {
    try {
      var query = _client.from('debts').select().eq('outlet_id', outletId);
      if (status != null) {
        query = query.eq('status', status);
      }
      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((json) => Debt.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<Debt?> createDebt(Debt debt) async {
    try {
      final response = await _client
          .from('debts')
          .insert(debt.toJson())
          .select()
          .single();
      return Debt.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateDebt(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('debts').update(data).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<DebtPayment>> getDebtPayments(String debtId) async {
    try {
      final response = await _client
          .from('debt_payments')
          .select()
          .eq('debt_id', debtId)
          .order('paid_at', ascending: false);
      return (response as List)
          .map((json) => DebtPayment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<DebtPayment?> recordDebtPayment(DebtPayment payment) async {
    try {
      final response = await _client
          .from('debt_payments')
          .insert(payment.toJson())
          .select()
          .single();
      return DebtPayment.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // ==========================================
  // SHIFTS & TIPS
  // ==========================================

  Future<Shift?> getActiveShift(String outletId, {String? userId}) async {
    try {
      var query = _client
          .from('shifts')
          .select()
          .eq('outlet_id', outletId)
          .filter('closed_at', 'is', 'null');
      if (userId != null) {
        query = query.eq('user_id', userId);
      }
      final response = await query.order('opened_at', ascending: false).limit(1).maybeSingle();
      if (response == null) return null;
      return Shift.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<Shift?> openShift(Shift shift) async {
    try {
      final response = await _client
          .from('shifts')
          .insert(shift.toJson())
          .select()
          .single();
      return Shift.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<bool> closeShift(String shiftId, double closingCash) async {
    try {
      await _client.from('shifts').update({
        'closing_cash': closingCash,
        'closed_at': DateTime.now().toIso8601String(),
      }).eq('id', shiftId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Tip?> recordTip(Tip tip) async {
    try {
      final response = await _client
          .from('tips')
          .insert(tip.toJson())
          .select()
          .single();
      return Tip.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<Tip>> getTips(String outletId, {String? shiftId}) async {
    try {
      final response = await _client
          .from('tips')
          .select()
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => Tip.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ==========================================
  // PRODUCT VARIANTS & STOCK LOGS
  // ==========================================

  Future<List<ProductVariant>> getProductVariants(String productId) async {
    try {
      final response = await _client
          .from('product_variants')
          .select()
          .eq('product_id', productId);
      return (response as List)
          .map((json) => ProductVariant.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<ProductVariant?> createProductVariant(ProductVariant variant) async {
    try {
      final response = await _client
          .from('product_variants')
          .insert(variant.toJson())
          .select()
          .single();
      return ProductVariant.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<bool> recordStockLog(StockLog log) async {
    try {
      await _client.from('stock_logs').insert(log.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<StockLog>> getStockLogs(String outletId, {String? productId}) async {
    try {
      var query = _client.from('stock_logs').select().eq('outlet_id', outletId);
      if (productId != null) {
        query = query.eq('product_id', productId);
      }
      final response = await query.order('created_at', ascending: false).limit(100);
      return (response as List)
          .map((json) => StockLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ==========================================
  // RECIPES & BOM
  // ==========================================

  Future<Recipe?> getRecipe(String productId) async {
    try {
      final response = await _client
          .from('recipes')
          .select('*, recipe_items(*)')
          .eq('product_id', productId)
          .maybeSingle();
      if (response == null) return null;
      return Recipe.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<Recipe?> saveRecipe(Recipe recipe, List<RecipeItem> items) async {
    try {
      final recRes = await _client
          .from('recipes')
          .insert(recipe.toJson())
          .select()
          .single();
      final savedRecipe = Recipe.fromJson(recRes);
      if (items.isNotEmpty) {
        final itemsPayload = items.map((i) => i.copyWith(recipeId: savedRecipe.id).toJson()).toList();
        await _client.from('recipe_items').insert(itemsPayload);
      }
      return savedRecipe;
    } catch (e) {
      return null;
    }
  }

  // ==========================================
  // PPOB & RESTOCK ORDERS & FINTECH
  // ==========================================

  Future<List<PpobProduct>> getPpobProducts({String? category}) async {
    try {
      var query = _client.from('ppob_products').select();
      if (category != null) {
        query = query.eq('category', category);
      }
      final response = await query.order('name');
      return (response as List)
          .map((json) => PpobProduct.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<PpobTransaction?> createPpobTransaction(PpobTransaction tx) async {
    try {
      final response = await _client
          .from('ppob_transactions')
          .insert(tx.toJson())
          .select()
          .single();
      return PpobTransaction.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<RestockOrder>> getRestockOrders(String outletId) async {
    try {
      final response = await _client
          .from('restock_orders')
          .select()
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => RestockOrder.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<RestockOrder?> createRestockOrder(RestockOrder order) async {
    try {
      final response = await _client
          .from('restock_orders')
          .insert(order.toJson())
          .select()
          .single();
      return RestockOrder.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<bool> createFintechLead(String outletId, String partner, double amountRequested) async {
    try {
      await _client.from('fintech_leads').insert({
        'outlet_id': outletId,
        'partner': partner,
        'amount_requested': amountRequested,
        'status': 'lead',
      });
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
