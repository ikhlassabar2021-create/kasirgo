import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/models/product.dart';
import 'package:kasirgo/models/transaction.dart';

void main() {
  group('ST5 POS Cart & Transaction Item Calculation Tests', () {
    test('TransactionItem calculates correct subtotal with quantity updates', () {
      final item = TransactionItem(
        productId: 'prod-1',
        productName: 'Teh Botol 250ml',
        price: 4500,
        quantity: 2,
        subtotal: 9000,
      );

      expect(item.subtotal, 9000);

      final updated = item.copyWith(
        quantity: 5,
        subtotal: item.price * 5,
      );

      expect(updated.quantity, 5);
      expect(updated.subtotal, 22500);
    });

    test('Cart total and discount calculation works correctly', () {
      final cart = [
        TransactionItem(
          productId: 'prod-1',
          productName: 'Indomie Goreng',
          price: 3500,
          quantity: 3,
          subtotal: 10500,
        ),
        TransactionItem(
          productId: 'prod-2',
          productName: 'Kopi Sachet',
          price: 2500,
          quantity: 4,
          subtotal: 10000,
        ),
      ];

      final subtotal = cart.fold(0.0, (sum, i) => sum + i.subtotal);
      expect(subtotal, 20500);

      const discount = 5000.0;
      final finalAmount = (subtotal - discount).clamp(0.0, double.infinity);
      expect(finalAmount, 15500);

      // Discount exceeds total clamp to 0
      const largeDiscount = 30000.0;
      final clampedAmount = (subtotal - largeDiscount).clamp(0.0, double.infinity);
      expect(clampedAmount, 0.0);
    });

    test('Stock boundary check logic restricts excessive cart quantity', () {
      final product = Product(
        id: 'p-1',
        outletId: 'o-1',
        name: 'Minyak 1L',
        price: 18000,
        stock: 5,
      );

      int currentCartQty = 4;
      bool canAddOneMore = currentCartQty < product.stock;
      expect(canAddOneMore, isTrue);

      currentCartQty = 5;
      bool canAddBeyond = currentCartQty < product.stock;
      expect(canAddBeyond, isFalse);
    });

    test('Transaction object formats items and notes properly for POS channel', () {
      final tx = Transaction(
        id: 'tx-123',
        outletId: 'outlet-1',
        cashierId: 'cashier-1',
        items: [
          TransactionItem(
            productId: 'p-1',
            productName: 'Indomie Goreng',
            price: 3500,
            quantity: 2,
            subtotal: 7000,
          ),
        ],
        totalAmount: 7000,
        discountAmount: 1000,
        finalAmount: 6000,
        paymentMethod: 'Tunai',
        paymentStatus: 'paid',
        notes: 'Channel: Tokopedia | Meja 3',
        createdAt: DateTime.now(),
      );

      expect(tx.finalAmount, 6000);
      expect(tx.notes, contains('Channel: Tokopedia'));
      expect(tx.items.length, 1);

      final json = tx.toJson();
      expect(json['total_amount'], 7000);
      expect(json['final_amount'], 6000);
      expect(json['payment_method'], 'Tunai');
    });
  });
}
