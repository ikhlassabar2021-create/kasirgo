import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/models/product.dart';
import 'package:kasirgo/models/transaction.dart';
import 'package:kasirgo/widgets/pos/cart_panel.dart';
import 'package:kasirgo/widgets/pos/product_grid.dart';

Product _p({String id = 'p1', int stock = 5}) => Product(
      id: id,
      outletId: 'o1',
      name: 'naga',
      basePrice: 20000,
      stock: stock,
    );

void main() {
  testWidgets('ProductGrid tile tap fires', (tester) async {
    Product? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: ProductGrid(
            products: [_p()],
            onProductTap: (p) => tapped = p,
          ),
        ),
      ),
    ));

    await tester.tap(find.text('naga'));
    await tester.pump();
    expect(tapped?.id, 'p1');
  });

  testWidgets('ProductGrid tap works with CartPanel in Stack', (tester) async {
    Product? tapped;
    final items = <TransactionItem>[];
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
                      products: [_p()],
                      onProductTap: (p) => tapped = p,
                    ),
                  ),
                ],
              ),
              CartPanel(
                items: items,
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
    await tester.tap(find.text('naga'), warnIfMissed: false);
    await tester.pump();
    expect(tapped?.id, 'p1', reason: 'tap must pass through CartPanel');
  });

  testWidgets('out of stock tile is not tappable', (tester) async {
    Product? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: ProductGrid(
            products: [_p(stock: 0)],
            onProductTap: (p) => tapped = p,
          ),
        ),
      ),
    ));

    await tester.tap(find.text('naga'));
    await tester.pump();
    expect(tapped, isNull);
  });

  testWidgets('product scrolled above cart panel is tappable', (tester) async {
    String? tappedId;
    final products = List.generate(12, (i) => _p(id: 'p$i'));
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
                      products: products,
                      onProductTap: (p) => tappedId = p.id,
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

    // Scroll up by 200px so bottom items come up into visible area
    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    // Tap at y=250 (safely above the cart panel at y > 408)
    await tester.tapAt(const Offset(100, 250));
    await tester.pump();
    expect(tappedId, isNotNull,
        reason: 'product above cart sheet must be tappable');
  });
}
