import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/models/product.dart';
import 'package:kasirgo/models/transaction.dart';
import 'package:kasirgo/utils/dynamic_pricing.dart';

Product _product({
  required String id,
  required String name,
  required double price,
  double? cost,
  int stock = 20,
  DateTime? createdAt,
}) {
  return Product(
    id: id,
    outletId: 'outlet-1',
    name: name,
    basePrice: price,
    costPrice: cost,
    stock: stock,
    unit: 'pcs',
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(days: 120)),
  );
}

Transaction _tx({
  required String id,
  required DateTime createdAt,
  required List<TransactionItem> items,
}) {
  final total = items.fold<double>(0, (sum, item) => sum + item.subtotal);
  return Transaction(
    id: id,
    outletId: 'outlet-1',
    items: items,
    totalAmount: total,
    finalAmount: total,
    paymentMethod: 'cash',
    createdAt: createdAt,
  );
}

TransactionItem _item(Product product, double subtotal) {
  return TransactionItem(
    productId: product.id,
    productName: product.name,
    price: product.basePrice,
    quantity: 1,
    subtotal: subtotal,
  );
}

void main() {
  group('DynamicPricing.build', () {
    test('produk lambat laku mendapat saran diskon yang sehat', () {
      final product = _product(
        id: 'p1',
        name: 'Kopi Susu',
        price: 20000,
        cost: 8000,
      );

      final plan = DynamicPricing.build([product], []);

      expect(plan.discounts, hasLength(1));
      final rec = plan.discounts.first;
      expect(rec.product.id, 'p1');
      expect(rec.daysInactive, greaterThanOrEqualTo(30));
      expect(rec.suggestedPrice, lessThan(rec.currentPrice));
      expect(rec.discountPercent, greaterThanOrEqualTo(5));
      expect(rec.suggestedPrice % 500, 0);
      expect(rec.saving, greaterThan(0));
    });

    test('diskon produk kelas A dibatasi maksimal 15 persen', () {
      final now = DateTime.now();
      final a = _product(id: 'a', name: 'Produk A', price: 10000, cost: 2000);
      final b = _product(id: 'b', name: 'Produk B', price: 30000, cost: 9000);
      final c = _product(id: 'c', name: 'Produk C', price: 20000, cost: 6000);

      final old = now.subtract(const Duration(days: 100));
      final transactions = [
        _tx(
          id: 't1',
          createdAt: old,
          items: [_item(a, 80000), _item(b, 10000), _item(c, 10000)],
        ),
      ];

      final plan = DynamicPricing.build([a, b, c], transactions);

      expect(plan.rankOf('a'), 'A');
      final recA = plan.discounts.firstWhere((r) => r.product.id == 'a');
      expect(recA.discountPercent, lessThanOrEqualTo(15));
      expect(recA.discountPercent, greaterThanOrEqualTo(10));

      final recB = plan.discounts.firstWhere((r) => r.product.id == 'b');
      expect(recB.discountPercent, lessThanOrEqualTo(25));
      expect(recB.rank, 'B');

      final recC = plan.discounts.firstWhere((r) => r.product.id == 'c');
      expect(recC.rank, 'C');
      expect(recC.discountPercent, greaterThan(recA.discountPercent));
    });

    test('harga diskon tidak pernah jatuh di bawah modal + margin minimum', () {
      final product = _product(
        id: 'p1',
        name: 'Roti Bakar',
        price: 12000,
        cost: 9000,
      );

      final plan = DynamicPricing.build([product], []);
      expect(plan.discounts, hasLength(1));

      final rec = plan.discounts.first;
      final floor = 9000 / (1 - DynamicPricing.defaultMinMarginPercent / 100);
      expect(rec.suggestedPrice, greaterThanOrEqualTo(floor - 500));
      expect(
        (rec.suggestedPrice - 9000) / rec.suggestedPrice * 100,
        greaterThan(10),
      );
    });

    test('produk margin tipis mendapat saran kenaikan harga', () {
      final thin = _product(
        id: 'p1',
        name: 'Es Teh',
        price: 10000,
        cost: 9500,
      );
      final healthy = _product(
        id: 'p2',
        name: 'Kopi',
        price: 20000,
        cost: 8000,
      );

      final plan = DynamicPricing.build([thin, healthy], []);

      expect(plan.lowMargins, hasLength(1));
      final alert = plan.lowMargins.first;
      expect(alert.product.id, 'p1');
      expect(alert.marginPercent, lessThan(15));
      expect(alert.suggestedPrice, greaterThan(alert.currentPrice));
      expect(alert.message, contains('Margin hanya'));
    });

    test('harga jual di bawah modal diberi pesan khusus', () {
      final product = _product(
        id: 'p1',
        name: 'Produk Rugi',
        price: 8000,
        cost: 10000,
      );

      final plan = DynamicPricing.build([product], []);

      expect(plan.lowMargins, hasLength(1));
      final alert = plan.lowMargins.first;
      expect(alert.marginPercent, lessThan(0));
      expect(alert.message, contains('di bawah modal'));
      expect(alert.suggestedPrice, greaterThan(alert.costPrice));
    });

    test('produk tanpa harga modal tidak dianggap margin tipis', () {
      final product = _product(id: 'p1', name: 'Titipan', price: 5000);

      final plan = DynamicPricing.build([product], []);

      expect(plan.lowMargins, isEmpty);
    });

    test('produk yang baru laku dan margin sehat tidak disarankan apa pun', () {
      final product = _product(
        id: 'p1',
        name: 'Kopi Susu',
        price: 20000,
        cost: 8000,
      );
      final transactions = [
        _tx(
          id: 't1',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          items: [_item(product, 20000)],
        ),
      ];

      final plan = DynamicPricing.build([product], transactions);

      expect(plan.isEmpty, isTrue);
      expect(plan.recommendationCount, 0);
    });

    test('produk jasa tanpa stok tetap dianalisis, stok kosong dilewati', () {
      final service = Product(
        id: 'svc',
        outletId: 'outlet-1',
        name: 'Service HP',
        basePrice: 50000,
        costPrice: 20000,
        stock: 0,
        isService: true,
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      );
      final outOfStock = _product(
        id: 'empty',
        name: 'Kosong',
        price: 10000,
        cost: 4000,
        stock: 0,
      );

      final plan = DynamicPricing.build([service, outOfStock], []);

      expect(
        plan.discounts.map((r) => r.product.id),
        contains('svc'),
      );
      expect(
        plan.discounts.map((r) => r.product.id),
        isNot(contains('empty')),
      );
    });

    test('ringkasan plan melaporkan jumlah produk & transaksi', () {
      final product = _product(
        id: 'p1',
        name: 'Kopi',
        price: 20000,
        cost: 8000,
      );
      final transactions = [
        _tx(
          id: 't1',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          items: [_item(product, 20000)],
        ),
        _tx(
          id: 't2',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          items: [_item(product, 20000)],
        ),
      ];

      final plan = DynamicPricing.build([product], transactions);

      expect(plan.productCount, 1);
      expect(plan.transactionCount, 2);
      expect(plan.rankOf('tidak-ada'), 'C');
    });
  });
}
