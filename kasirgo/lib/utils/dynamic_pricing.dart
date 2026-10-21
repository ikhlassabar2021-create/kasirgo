import '../models/product.dart';
import '../models/transaction.dart';
import 'ai_engine.dart';

/// Satu saran diskon untuk produk yang perputarannya lambat.
class PriceRecommendation {
  final Product product;
  final String rank;
  final int discountPercent;
  final double currentPrice;
  final double suggestedPrice;
  final int daysInactive;
  final String reason;

  const PriceRecommendation({
    required this.product,
    required this.rank,
    required this.discountPercent,
    required this.currentPrice,
    required this.suggestedPrice,
    required this.daysInactive,
    required this.reason,
  });

  double get saving => currentPrice - suggestedPrice;
}

/// Satu peringatan harga jual terlalu tipis dibanding modal (HPP).
class MarginAlert {
  final Product product;
  final String rank;
  final double currentPrice;
  final double costPrice;
  final double marginPercent;
  final double suggestedPrice;
  final String message;

  const MarginAlert({
    required this.product,
    required this.rank,
    required this.currentPrice,
    required this.costPrice,
    required this.marginPercent,
    required this.suggestedPrice,
    required this.message,
  });
}

/// Hasil analisis Dynamic Pricing untuk satu outlet.
class DynamicPricingPlan {
  final List<PriceRecommendation> discounts;
  final List<MarginAlert> lowMargins;
  final Map<String, String> ranks;
  final int productCount;
  final int transactionCount;

  const DynamicPricingPlan({
    required this.discounts,
    required this.lowMargins,
    required this.ranks,
    required this.productCount,
    required this.transactionCount,
  });

  bool get isEmpty => discounts.isEmpty && lowMargins.isEmpty;

  int get recommendationCount => discounts.length + lowMargins.length;

  String rankOf(String productId) => ranks[productId] ?? 'C';
}

/// Aturan rekomendasi harga otomatis (Dynamic Pricing - Bos Virtual #4).
///
/// Murni komputasi lokal tanpa jaringan supaya bisa diuji unit test:
/// - produk lambat laku (>= [daysThreshold] hari tanpa transaksi) -> saran diskon
///   (20/25/30% mengikuti lama tidak laku, sama dengan `AiEngine.suggestFlashSale`);
/// - kelas A (penyumbang omzet terbesar) diskonnya dibatasi supaya tidak
///   menggerus laba produk terlaris;
/// - harga tidak boleh jatuh di bawah modal + margin minimum;
/// - produk dengan margin di bawah [minMarginPercent] -> saran kenaikan harga.
class DynamicPricing {
  static const double defaultMinMarginPercent = 15.0;
  static const int defaultInactiveDays = 30;
  static const int _roundTo = 500;
  static const int _minDiscountPercent = 5;

  static DynamicPricingPlan build(
    List<Product> products,
    List<Transaction> transactions, {
    double minMarginPercent = defaultMinMarginPercent,
    int daysThreshold = defaultInactiveDays,
  }) {
    final engine = AIEngine();
    final abc = engine.abcRanking(products, transactions);
    final ranks = <String, String>{};
    for (final entry in abc.entries) {
      for (final product in entry.value) {
        ranks[product.id] = entry.key;
      }
    }

    final recommendations = <PriceRecommendation>[];
    for (final raw in engine.suggestFlashSale(
      products,
      transactions,
      daysThreshold: daysThreshold,
    )) {
      final product = raw['product'] as Product;
      final rank = ranks[product.id] ?? 'C';
      final currentPrice = (raw['currentPrice'] as num?)?.toDouble() ?? product.price;
      if (currentPrice <= 0) continue;

      var percent = (raw['suggestedDiscount'] as num?)?.toInt() ?? 20;
      if (rank == 'A') percent = percent.clamp(10, 15);
      if (rank == 'B') percent = percent.clamp(10, 25);

      final floorPrice = _floorPrice(product, minMarginPercent);
      var price = _roundPrice(currentPrice * (1 - percent / 100));
      if (price < floorPrice) price = _roundPrice(floorPrice);
      if (price >= currentPrice) continue;

      final actualPercent = ((1 - price / currentPrice) * 100).round();
      if (actualPercent < _minDiscountPercent) continue;

      recommendations.add(
        PriceRecommendation(
          product: product,
          rank: rank,
          discountPercent: actualPercent,
          currentPrice: currentPrice,
          suggestedPrice: price,
          daysInactive: (raw['daysInactive'] as num?)?.toInt() ?? daysThreshold,
          reason: raw['reason']?.toString() ?? '',
        ),
      );
    }

    recommendations.sort(
      (a, b) => b.daysInactive.compareTo(a.daysInactive),
    );

    final lowMargins = <MarginAlert>[];
    for (final product in products) {
      final cost = product.costPrice ?? 0;
      if (cost <= 0 || product.price <= 0) continue;

      final margin = engine.checkMargin(
        product,
        minMarginPercent: minMarginPercent,
      );
      final marginPercent = (margin['marginPercent'] as num?)?.toDouble() ?? 0;
      if (marginPercent >= minMarginPercent) continue;

      final target = _roundPrice(cost / (1 - minMarginPercent / 100));
      final message = marginPercent < 0
          ? 'Harga jual di bawah modal. Naikkan minimal ke ${_rupiah(target)}.'
          : 'Margin hanya ${_trim(marginPercent)}%. Naikkan harga ke ${_rupiah(target)}.';

      lowMargins.add(
        MarginAlert(
          product: product,
          rank: ranks[product.id] ?? 'C',
          currentPrice: product.price,
          costPrice: cost,
          marginPercent: marginPercent,
          suggestedPrice: target,
          message: message,
        ),
      );
    }

    lowMargins.sort((a, b) => a.marginPercent.compareTo(b.marginPercent));

    return DynamicPricingPlan(
      discounts: recommendations,
      lowMargins: lowMargins,
      ranks: ranks,
      productCount: products.length,
      transactionCount: transactions.length,
    );
  }

  /// Harga terendah yang masih menahan margin minimum di atas modal.
  static double _floorPrice(Product product, double minMarginPercent) {
    final cost = product.costPrice ?? 0;
    if (cost <= 0) return 0;
    return _roundPrice(cost / (1 - minMarginPercent / 100));
  }

  static double _roundPrice(double value) {
    if (value <= 0) return 0;
    return (value / _roundTo).round() * _roundTo.toDouble();
  }

  static String _trim(double value) {
    final fixed = value.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  static String _rupiah(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return 'Rp $buffer';
  }
}
