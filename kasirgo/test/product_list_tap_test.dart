import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/models/product.dart';
import 'package:kasirgo/screens/owner/product_list_screen.dart';

void main() {
  testWidgets('ProductListScreen card tap navigates or triggers', (tester) async {
    final products = [
      const Product(
        id: '30ddb9b8-8f02-44b9-b298-d64e429b7529',
        outletId: '973e4841-1dd3-4046-ad02-9cb3f9d51a4a',
        name: 'naga',
        basePrice: 20000,
        stock: 5,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsProvider.overrideWith((ref) => Future.value(products)),
        ],
        child: const MaterialApp(
          home: ProductListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('naga'), findsOneWidget);

    // Tap on naga card in list screen
    await tester.tap(find.text('naga'));
    await tester.pump();
  });
}
