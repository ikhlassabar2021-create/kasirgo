import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/models/product.dart';
import 'package:kasirgo/utils/subscription_gate.dart';
import 'package:kasirgo/utils/ai_engine.dart';

void main() {
  group('Phase 5 Subscription Gate Logic Tests', () {
    test('Tier checking helper methods', () {
      expect(SubscriptionGate.isFree('free'), isTrue);
      expect(SubscriptionGate.isFree(null), isTrue);
      expect(SubscriptionGate.isFree('basic_25'), isFalse);
      expect(SubscriptionGate.isFree('pro_50'), isFalse);

      expect(SubscriptionGate.isBasic('basic_25'), isTrue);
      expect(SubscriptionGate.isBasic('free'), isFalse);

      expect(SubscriptionGate.isPro('pro_50'), isTrue);
      expect(SubscriptionGate.isPro('basic_25'), isFalse);
      expect(SubscriptionGate.isPro('free'), isFalse);
    });

    test('Tier product limits logic', () async {
      // Under freeMaxProducts (500)
      final canCreateUnder = await SubscriptionGate.canCreateProduct(
        outletId: 'out-1',
        currentProductCount: 499,
        currentTier: 'free',
      );
      expect(canCreateUnder, isTrue);

      // Reached freeMaxProducts (500)
      final canCreateMax = await SubscriptionGate.canCreateProduct(
        outletId: 'out-1',
        currentProductCount: 500,
        currentTier: 'free',
      );
      expect(canCreateMax, isFalse);

      // Paid tier unlimited
      final canCreatePaid = await SubscriptionGate.canCreateProduct(
        outletId: 'out-1',
        currentProductCount: 1500,
        currentTier: 'basic_25',
      );
      expect(canCreatePaid, isTrue);
    });
  });

  group('Phase 5 AI Engine Flash Sale & Dead Stock Tests', () {
    test('suggestFlashSale calculates dead stock discount correctly', () {
      final now = DateTime.now();
      final deadProduct = Product(
        id: 'p1',
        outletId: 'o1',
        name: 'Kopi Bubuk Lama',
        price: 20000,
        costPrice: 10000,
        stock: 50,
        createdAt: now.subtract(const Duration(days: 65)),
        updatedAt: now.subtract(const Duration(days: 65)),
      );

      final ai = AIEngine();
      final suggestions = ai.suggestFlashSale([deadProduct], []);
      expect(suggestions.isNotEmpty, isTrue);
      expect(suggestions.first['suggestedDiscount'], 30);
      expect((suggestions.first['reason'] as String).contains('hari'), isTrue);
    });
  });
}
