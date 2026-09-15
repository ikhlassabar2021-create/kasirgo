import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/models/product.dart';
import 'package:kasirgo/screens/owner/pos_screen.dart';
import 'package:kasirgo/screens/owner/product_list_screen.dart';

void main() {
  testWidgets('Full PosScreen renders and allows adding product to cart', (tester) async {
    final products = [
      const Product(
        id: '30ddb9b8-8f02-44b9-b298-d64e429b7529',
        outletId: '973e4841-1dd3-4046-ad02-9cb3f9d51a4a',
        name: 'naga',
        basePrice: 20000,
        stock: 5,
        imageLocalPath: 'blob:https://8080-efbfe193ef269dd3.monkeycode-ai.live/7cdf8451-4bbc-407c-a912-cd602e4486c4',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsProvider.overrideWith((ref) => Future.value(products)),
        ],
        child: const MaterialApp(
          home: PosScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Check if naga is displayed
    expect(find.text('naga'), findsOneWidget);
    expect(find.text('Rp 20000'), findsOneWidget);
    expect(find.text('Stok: 5'), findsOneWidget);

    // Initial cart is 0
    expect(find.text('Keranjang (0)'), findsOneWidget);

    // Tap on naga
    await tester.tap(find.text('naga'));
    await tester.pumpAndSettle();

    // Cart should now have 1 item!
    expect(find.text('Keranjang (1)'), findsOneWidget);
    expect(find.text('Rp 20000'), findsNWidgets(2)); // in grid and in cart total
  });
}
