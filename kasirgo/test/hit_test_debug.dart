import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/models/product.dart';
import 'package:kasirgo/widgets/pos/cart_panel.dart';
import 'package:kasirgo/widgets/pos/product_grid.dart';

void main() {
  testWidgets('where does CartPanel intercept hit tests?', (tester) async {
    Product? tapped;
    final p = Product(id: 'p1', outletId: 'o1', name: 'naga', basePrice: 20000, stock: 5);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 600,
          width: 360,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ProductGrid(
                      products: [p],
                      onProductTap: (prod) => tapped = prod,
                    ),
                  ),
                ],
              ),
              CartPanel(
                items: const [],
                discountAmount: 0,
                onCheckout: () {},
                onRemoveItem: (_) {},
                onUpdateQty: (_) {},
              ),
            ],
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    tester.takeException();

    final hitTestResult = tester.hitTestOnBinding(const Offset(100, 100));
    debugPrint('Hits at (100, 100):');
    for (final entry in hitTestResult.path) {
      final target = entry.target;
      debugPrint(' - ${target.runtimeType}');
    }

    await tester.tapAt(const Offset(100, 100));
    await tester.pump();
    debugPrint('tapped at (100, 100): ${tapped?.name}');
  });
}
