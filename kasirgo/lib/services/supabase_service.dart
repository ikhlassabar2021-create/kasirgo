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
      final response = await _queryTransactions(
        outletId,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
        withItems: true,
      );
      return response;
    } catch (_) {
      try {
        return await _queryTransactions(
          outletId,
          limit: limit,
          startDate: startDate,
          endDate: endDate,
          withItems: false,
        );
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<Transaction>> _queryTransactions(
    String outletId, {
    required int limit,
    DateTime? startDate,
    DateTime? endDate,
    required bool withItems,
  }) async {
    final select = withItems ? '*, transaction_items(*)' : '*';
    var query = _client.from('transactions').select(select).eq('outlet_id', outletId);

    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }

    final response = await query.order('created_at', ascending: false).limit(limit);

    return (response as List)
        .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Pesanan dine-in (QR meja) untuk kasir/dapur — termasuk rincian item.
  Future<List<Transaction>> getDineInOrders(String outletId, {int limit = 40}) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
      final response = await _client
          .from('transactions')
          .select('*, transaction_items(*)')
          .eq('outlet_id', outletId)
          .eq('channel', 'dine_in')
          .gte('created_at', startOfDay)
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List)
          .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getDineInOrders error: $e');
      return [];
    }
  }

  /// Ubah status pesanan dine-in (baru/diproses/siap/selesai).
  Future<bool> setOrderStatus(String transactionId, String status) async {
    try {
      await _client.rpc('set_order_status', params: {
        'p_tx': transactionId,
        'p_status': status,
      });
      return true;
    } catch (e) {
      debugPrint('setOrderStatus error: $e');
      return false;
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
      final txJson = transaction.toSupabaseJson();
      final response = await _client
          .from('transactions')
          .insert(txJson)
          .select()
          .single();

      final created = Transaction.fromJson(response);

      if (transaction.items.isNotEmpty && created.id.isNotEmpty) {
        final itemRows = transaction.items
            .where((item) => item.productId.isNotEmpty)
            .map((item) => <String, dynamic>{
                  'transaction_id': created.id,
                  'product_id': item.productId,
                  if (item.variantId != null && item.variantId!.isNotEmpty)
                    'variant_id': item.variantId,
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
          .from('user_roles')
          .select('*, outlets(name)')
          .eq('outlet_id', outletId);

      return (response as List).map((json) {
        final role = json['role']?.toString() ?? 'cashier';
        final userId = json['user_id']?.toString() ?? '';
        return Employee(
          id: (json['id'] ?? '').toString(),
          outletId: outletId,
          userId: userId,
          name: 'Staf (${role.toUpperCase()})',
          role: role,
          isActive: true,
          createdAt: json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Employee?> getEmployee(String id) async {
    try {
      final response = await _client
          .from('user_roles')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      final role = response['role']?.toString() ?? 'cashier';
      return Employee(
        id: response['id'].toString(),
        outletId: response['outlet_id']?.toString() ?? '',
        userId: response['user_id']?.toString() ?? '',
        name: 'Staf (${role.toUpperCase()})',
        role: role,
        isActive: true,
      );
    } catch (e) {
      return null;
    }
  }

  Future<Employee?> createEmployee(Employee employee) async {
    // Tanpa user_id (akun login belum dibuat), tidak bisa simpan ke user_roles.
    if (employee.userId.isEmpty) return null;
    try {
      final response = await _client
          .from('user_roles')
          .upsert({
            'outlet_id': employee.outletId,
            'user_id': employee.userId,
            'role': employee.role,
          }, onConflict: 'user_id,outlet_id')
          .select()
          .single();

      return Employee(
        id: response['id'].toString(),
        outletId: employee.outletId,
        userId: employee.userId,
        name: employee.name,
        role: employee.role,
        isActive: true,
      );
    } catch (e) {
      return null;
    }
  }

  Future<Employee?> updateEmployee(Employee employee) async {
    try {
      final response = await _client
          .from('user_roles')
          .update({
            'role': employee.role,
          })
          .eq('id', employee.id)
          .select()
          .single();

      return Employee(
        id: response['id'].toString(),
        outletId: employee.outletId,
        userId: employee.userId,
        name: employee.name,
        role: employee.role,
        isActive: true,
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateEmployeeRole(String employeeId, String newRole, {String? userId, String? outletId}) async {
    try {
      await _client
          .from('user_roles')
          .update({'role': newRole})
          .eq('id', employeeId);
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
      await _client.from('user_roles').delete().eq('id', id);
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

  Future<List<Debt>> getDebts(String outletId, {String? status, String? customerId}) async {
    try {
      var query = _client.from('debts').select().eq('outlet_id', outletId);
      if (status != null) {
        query = query.eq('status', status);
      }
      if (customerId != null) {
        query = query.eq('customer_id', customerId);
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
  // SHIFTS & TIPS (metode lengkap di bagian SHIFT KASIR, TIP & SPLIT BILL)
  // ==========================================

  Future<Shift?> getActiveShift(String outletId, {String? userId}) async {
    try {
      var query = _client
          .from('shifts')
          .select()
          .eq('outlet_id', outletId)
          .eq('status', 'open');
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

  Future<ProductVariant?> updateProductVariant(ProductVariant variant) async {
    if (variant.id.isEmpty) return null;
    try {
      final response = await _client
          .from('product_variants')
          .update(variant.toJson())
          .eq('id', variant.id)
          .select()
          .single();
      return ProductVariant.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Upsert daftar varian: insert baru, update yang ada, hapus yang hilang.
  Future<bool> syncProductVariants({
    required String outletId,
    required String productId,
    required List<ProductVariant> variants,
    List<String> removeIds = const [],
  }) async {
    try {
      for (final id in removeIds) {
        await _client.from('product_variants').delete().eq('id', id);
      }
      for (final v in variants) {
        final withIds = v.copyWith(outletId: outletId, productId: productId);
        if (v.id.isEmpty) {
          await createProductVariant(withIds);
        } else {
          await updateProductVariant(withIds);
        }
      }
      return true;
    } catch (e) {
      debugPrint('syncProductVariants error: $e');
      return false;
    }
  }

  /// Jumlah varian aktif per produk (untuk badge di daftar produk).
  Future<Map<String, int>> getVariantCounts(List<String> productIds) async {
    if (productIds.isEmpty) return {};
    try {
      final response = await _client
          .from('product_variants')
          .select('product_id')
          .inFilter('product_id', productIds)
          .eq('is_active', true);
      final counts = <String, int>{};
      for (final row in (response as List)) {
        final pid = (row as Map)['product_id'].toString();
        counts[pid] = (counts[pid] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      return {};
    }
  }

  Future<bool> deleteProductVariant(String variantId) async {
    try {
      await _client.from('product_variants').delete().eq('id', variantId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Set flag has_variants produk.
  Future<bool> setProductHasVariants(String productId, bool value) async {
    try {
      await _client
          .from('products')
          .update({'has_variants': value}).eq('id', productId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Kurangi stok varian manual (mis. koreksi) + catat stock_logs.
  Future<bool> decrementVariantStock({
    required String outletId,
    required String variantId,
    required double qty,
    required String reason,
    String? refId,
  }) async {
    try {
      final rows = await _client
          .from('product_variants')
          .select('stock, product_id')
          .eq('id', variantId)
          .limit(1);
      if ((rows as List).isEmpty) return false;
      final row = rows.first as Map;
      final current = (row['stock'] as num?)?.toDouble() ?? 0;
      final newStock = current - qty;
      await _client
          .from('product_variants')
          .update({'stock': newStock, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', variantId);
      await recordStockLog(StockLog(
        id: '',
        outletId: outletId,
        productId: row['product_id']?.toString(),
        variantId: variantId,
        delta: -qty,
        reason: reason,
        refId: refId,
        createdAt: DateTime.now(),
      ));
      return true;
    } catch (e) {
      debugPrint('decrementVariantStock error: $e');
      return false;
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
          .upsert(recipe.toJson(), onConflict: 'outlet_id,product_id')
          .select()
          .single();
      final savedRecipe = Recipe.fromJson(recRes);
      await _client.from('recipe_items').delete().eq('recipe_id', savedRecipe.id);
      if (items.isNotEmpty) {
        final itemsPayload = items
            .where((i) => (i.ingredientProductId ?? '').isNotEmpty)
            .map((i) => <String, dynamic>{
                  ...i.copyWith(recipeId: savedRecipe.id, id: '').toJson(),
                  'outlet_id': savedRecipe.outletId,
                })
            .toList();
        if (itemsPayload.isNotEmpty) {
          await _client.from('recipe_items').insert(itemsPayload);
        }
      }
      return savedRecipe;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteRecipe(String recipeId) async {
    try {
      await _client.from('recipe_items').delete().eq('recipe_id', recipeId);
      await _client.from('recipes').delete().eq('id', recipeId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Recipe>> getRecipesForOutlet(String outletId) async {
    try {
      final response = await _client
          .from('recipes')
          .select('*, recipe_items(*), product:products(id, name, price, cost_price)')
          .eq('outlet_id', outletId);
      return (response as List)
          .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Kurangi stok bahan sesuai resep saat produk terjual.
  /// Konsumsi per bahan = qty_resep x (jumlah terjual / yield_qty).
  /// Best effort: gagal tidak memblokir transaksi.
  Future<void> deductRecipeIngredients(
      String outletId, String productId, double soldQty, String refTxId) async {
    try {
      final recipe = await getRecipe(productId);
      if (recipe == null || recipe.items.isEmpty || recipe.yieldQty <= 0) return;
      final factor = soldQty / recipe.yieldQty;
      for (final item in recipe.items) {
        final ingredientId = item.ingredientProductId;
        if (ingredientId == null || ingredientId.isEmpty) continue;
        final consume = item.qty * factor;
        if (consume <= 0) continue;
        final ing = await _client
            .from('products')
            .select('id, outlet_id, stock')
            .eq('id', ingredientId)
            .maybeSingle();
        if (ing == null) continue;
        final currentStock =
            double.tryParse(ing['stock']?.toString() ?? '0') ?? 0;
        final newStock = currentStock - consume;
        await _client
            .from('products')
            .update({
              'stock': newStock,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', ingredientId);
        await _client.from('stock_logs').insert({
          'outlet_id':
              (ing['outlet_id']?.toString().isNotEmpty ?? false)
                  ? ing['outlet_id']
                  : outletId,
          'product_id': ingredientId,
          'change': -consume,
          'reason': 'resep',
          'ref_id': refTxId,
        });
      }
    } catch (e) {
      // best effort: kegagalan pengurangan bahan tidak memblokir transaksi
    }
  }

  // ==========================================
  // SHIFT KASIR, TIP & SPLIT BILL
  // ==========================================

  Future<Shift?> getOpenShift(String outletId) async {
    try {
      final response = await _client
          .from('shifts')
          .select()
          .eq('outlet_id', outletId)
          .eq('status', 'open')
          .order('opened_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response == null) return null;
      return Shift.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<Shift?> openShift(
      String outletId, String userId, double openingCash) async {
    try {
      final existing = await getOpenShift(outletId);
      if (existing != null) return existing;
      final response = await _client
          .from('shifts')
          .insert({
            'outlet_id': outletId,
            'user_id': userId,
            'status': 'open',
            'opened_at': DateTime.now().toIso8601String(),
            'opening_cash': openingCash,
            'total_tip': 0,
          })
          .select()
          .single();
      return Shift.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<Shift>> getShiftHistory(String outletId, {int limit = 20}) async {
    try {
      final response = await _client
          .from('shifts')
          .select()
          .eq('outlet_id', outletId)
          .order('opened_at', ascending: false)
          .limit(limit);
      return (response as List)
          .map((r) => Shift.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Tutup shift: hitung total cash/qris/transfer dari transaction_payments
  /// (shift_id), tip dari tips, expected = opening + cash, difference = closing - expected.
  Future<Shift?> closeShift(String shiftId, double closingCash, String? note) async {
    try {
      final payRes = await _client
          .from('transaction_payments')
          .select('method, amount')
          .eq('shift_id', shiftId);
      double cash = 0, qris = 0, transfer = 0;
      for (final row in (payRes as List)) {
        final amount = double.tryParse(row['amount']?.toString() ?? '0') ?? 0;
        switch (row['method']?.toString()) {
          case 'cash':
            cash += amount;
            break;
          case 'qris':
            qris += amount;
            break;
          case 'bank_transfer':
            transfer += amount;
            break;
        }
      }
      final tipRes = await _client
          .from('tips')
          .select('amount')
          .eq('shift_id', shiftId);
      double tip = 0;
      for (final row in (tipRes as List)) {
        tip += double.tryParse(row['amount']?.toString() ?? '0') ?? 0;
      }

      final cur = await _client
          .from('shifts')
          .select('opening_cash')
          .eq('id', shiftId)
          .single();
      final opening = double.tryParse(cur['opening_cash']?.toString() ?? '0') ?? 0;
      final expected = opening + cash;
      final diff = closingCash - expected;

      final response = await _client
          .from('shifts')
          .update({
            'status': 'closed',
            'closed_at': DateTime.now().toIso8601String(),
            'closing_cash': closingCash,
            'expected_cash': expected,
            'difference': diff,
            'total_cash': cash,
            'total_qris': qris,
            'total_transfer': transfer,
            'total_tip': tip,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          })
          .eq('id', shiftId)
          .select()
          .single();
      return Shift.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<bool> addTransactionPayment({
    required String outletId,
    required String transactionId,
    required String method,
    required double amount,
    String? ref,
    String? userId,
    String? shiftId,
  }) async {
    try {
      await _client.from('transaction_payments').insert({
        'outlet_id': outletId,
        'transaction_id': transactionId,
        'method': method,
        'amount': amount,
        if (ref != null) 'ref': ref,
        if (userId != null) 'user_id': userId,
        if (shiftId != null) 'shift_id': shiftId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addTip({
    required String outletId,
    required double amount,
    String? transactionId,
    String? userId,
    String? shiftId,
    String? note,
  }) async {
    try {
      await _client.from('tips').insert({
        'outlet_id': outletId,
        'amount': amount,
        if (transactionId != null) 'transaction_id': transactionId,
        if (userId != null) 'user_id': userId,
        if (shiftId != null) 'shift_id': shiftId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });
      return true;
    } catch (e) {
      return false;
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

  /// Simpan/pilih tipe usaha outlet (dipakai saat owner daftar via Google
  /// atau ingin mengubah tipe setelahnya).
  Future<bool> updateOutletType({
    required String outletId,
    required String businessType,
  }) async {
    try {
      await _client
          .from('outlets')
          .update({'type': businessType})
          .eq('id', outletId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Menu publik untuk pelanggan QR meja (tanpa login).
  Future<List<Product>> getPublicMenu(String outletId) async {
    try {
      final response =
          await _client.rpc('get_public_menu', params: {'p_outlet': outletId});
      return (response as List)
          .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (_) {
      // Fallback: query langsung (berhasil bila RLS mengizinkan anon).
      return getProducts(outletId);
    }
  }

  /// Kirim pesanan dine-in pelanggan (tersinkron ke kasir/dapur).
  /// Mengembalikan id transaksi, atau null bila gagal.
  Future<String?> placeDineInOrder({
    required String outletId,
    required String tableNumber,
    required List<TransactionItem> items,
    String paymentMethod = 'cash',
  }) async {
    try {
      final orderItems = items
          .where((i) => i.productId.isNotEmpty)
          .map((i) => {'product_id': i.productId, 'quantity': i.quantity})
          .toList();
      if (orderItems.isEmpty) return null;

      const allowed = {'cash', 'qris', 'bank_transfer'};
      final method = allowed.contains(paymentMethod) ? paymentMethod : 'cash';
      final baseParams = {
        'p_outlet': outletId,
        'p_table': tableNumber,
        'p_items': orderItems,
      };

      dynamic result;
      try {
        result = await _client.rpc('place_dine_in_order', params: {
          ...baseParams,
          'p_payment_method': method,
        });
      } catch (_) {
        // Fallback: fungsi 3-arg (migrasi p_payment_method belum dijalankan).
        result = await _client.rpc('place_dine_in_order', params: baseParams);
      }
      if (result == null) return null;
      return result.toString();
    } catch (e) {
      debugPrint('placeDineInOrder error: $e');
      return null;
    }
  }

  /// Info pembayaran outlet (QRIS/transfer) untuk pelanggan anonim via RPC.
  Future<Map<String, dynamic>?> getPublicOutletPayment(String outletId) async {
    try {
      final res = await _client
          .rpc('get_public_outlet_payment', params: {'p_outlet': outletId});
      final list = res as List;
      if (list.isEmpty) return null;
      return Map<String, dynamic>.from(list.first as Map);
    } catch (e) {
      debugPrint('getPublicOutletPayment error: $e');
      return null;
    }
  }

  /// Simpan info pembayaran outlet (owner). Teks saja.
  Future<bool> saveOutletPayment({
    required String outletId,
    required String merchantName,
    required String bankWallet,
    required String accountNumber,
    required String nmid,
    String instruction = '',
  }) async {
    try {
      await _client.from('outlet_payment_configs').upsert({
        'outlet_id': outletId,
        'merchant_name': merchantName,
        'bank_wallet': bankWallet,
        'account_number': accountNumber,
        'nmid': nmid,
        'instruction': instruction,
        'is_active': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('saveOutletPayment error: $e');
      return false;
    }
  }

  /// Cari outlet publik (id/nama) untuk pelanggan anonim via RPC.
  Future<({String id, String name, String type})?> findOutlet(
      String codeOrName) async {
    final code = codeOrName.trim();
    if (code.isEmpty) return null;
    try {
      final res = await _client
          .rpc('get_public_outlet', params: {'p_code': code});
      final list = (res as List);
      if (list.isNotEmpty) {
        final row = Map<String, dynamic>.from(list.first as Map);
        final id = row['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          return (
            id: id,
            name: row['name']?.toString() ?? '',
            type: row['type']?.toString() ?? '',
          );
        }
      }
    } catch (_) {}
    // Fallback bila RPC belum terpasang (mis. pengguna login owner/kasir).
    try {
      final byId =
          await _client.from('outlets').select().eq('id', code).maybeSingle();
      if (byId != null) {
        return (
          id: byId['id'].toString(),
          name: byId['name']?.toString() ?? '',
          type: (byId['type'] ?? byId['outlet_type'])?.toString() ?? '',
        );
      }
    } catch (_) {}
    return null;
  }
}
