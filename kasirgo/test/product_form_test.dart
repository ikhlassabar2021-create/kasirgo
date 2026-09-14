import 'package:flutter_test/flutter_test.dart';
import 'package:barcode/barcode.dart' as bc;
import 'package:kasirgo/models/product.dart';
import 'package:kasirgo/config/constants.dart';

void main() {
  group('ST4 Product Form & Barcode Unit Tests', () {
    test('Barcode code128 generates valid barcode data', () {
      const sampleBarcode = '899123456789';
      final barcodeObj = bc.Barcode.code128();

      expect(barcodeObj.isValid(sampleBarcode), isTrue);

      final elements = barcodeObj.make(
        sampleBarcode,
        width: 200,
        height: 60,
        drawText: false,
      );

      expect(elements, isNotEmpty);
      final bars = elements.whereType<bc.BarcodeBar>();
      expect(bars.any((b) => b.black), isTrue);
    });

    test('Product model serialization handles all ST4 form fields', () {
      final now = DateTime.now();
      final product = Product(
        id: 'prod-test-1',
        outletId: 'outlet-test-1',
        name: 'Kopi Susu Gula Aren',
        category: 'Minuman',
        barcode: '899876543210',
        costPrice: 8000,
        basePrice: 15000,
        stock: 25,
        unit: 'cup',
        expiredDate: now,
        imageLocalPath: '/data/user/0/com.example.kasirgo/app_flutter/prod_123.jpg',
        thumbKey: null,
        isActive: true,
      );

      expect(product.name, 'Kopi Susu Gula Aren');
      expect(product.price, 15000);
      expect(product.costPrice, 8000);
      expect(product.stock, 25);
      expect(product.barcode, '899876543210');
      expect(product.unit, 'cup');
      expect(product.imageLocalPath, isNotNull);

      final json = product.toJson();
      expect(json['name'], 'Kopi Susu Gula Aren');
      expect(json['base_price'], 15000);
      expect(json['barcode'], '899876543210');

      final fromJson = Product.fromJson(json);
      expect(fromJson.name, product.name);
      expect(fromJson.basePrice, product.basePrice);
      expect(fromJson.barcode, product.barcode);
    });

    test('Free tier limit constant is configured to 500', () {
      expect(AppConstants.freeTierMaxProducts, 500);
      expect(AppConstants.freeTierMaxTransactions, 500);
    });
  });
}
