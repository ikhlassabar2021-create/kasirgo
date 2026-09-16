import 'dart:math';
import '../models/product.dart';
import '../models/transaction.dart';

class AIEngine {
  List<double> predictSales(List<Transaction> transactions, int days) {
    if (days <= 0) return [];
    if (transactions.isEmpty) return List.filled(days, 0.0);

    final dailyMap = <String, double>{};
    for (final tx in transactions) {
      final dateKey =
          '${tx.createdAt.year}-${tx.createdAt.month.toString().padLeft(2, '0')}-${tx.createdAt.day.toString().padLeft(2, '0')}';
      dailyMap[dateKey] = (dailyMap[dateKey] ?? 0.0) + tx.finalAmount;
    }

    final sortedKeys = dailyMap.keys.toList()..sort();
    final historicalSales = sortedKeys.map((k) => dailyMap[k]!).toList();

    if (historicalSales.isEmpty) return List.filled(days, 0.0);
    if (historicalSales.length == 1) {
      return List.filled(days, historicalSales.first);
    }

    int windowSize;
    if (historicalSales.length >= 30 && days >= 30) {
      windowSize = 30;
    } else if (historicalSales.length >= 14 && days >= 14) {
      windowSize = 14;
    } else {
      windowSize = min(7, historicalSales.length);
    }

    final recent = historicalSales.sublist(historicalSales.length - windowSize);
    final avg = recent.reduce((a, b) => a + b) / recent.length;
    final roundedAvg = (avg * 100).round() / 100;

    return List.filled(days, roundedAvg);
  }

  List<Map<String, dynamic>> detectAnomaly(List<Transaction> transactions) {
    if (transactions.isEmpty) return [];

    final dailyMap = <String, double>{};
    for (final tx in transactions) {
      final dateKey =
          '${tx.createdAt.year}-${tx.createdAt.month.toString().padLeft(2, '0')}-${tx.createdAt.day.toString().padLeft(2, '0')}';
      dailyMap[dateKey] = (dailyMap[dateKey] ?? 0.0) + tx.finalAmount;
    }

    final entries = dailyMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.length < 3) return [];

    final values = entries.map((e) => e.value).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) /
        values.length;
    final stdDev = sqrt(variance);

    if (stdDev == 0) return [];

    final anomalies = <Map<String, dynamic>>[];
    for (final entry in entries) {
      final zScore = (entry.value - mean) / stdDev;
      if (zScore.abs() > 2.0) {
        anomalies.add({
          'date': entry.key,
          'value': entry.value,
          'mean': (mean * 100).round() / 100,
          'stdDev': (stdDev * 100).round() / 100,
          'zScore': (zScore * 100).round() / 100,
          'type': zScore > 0 ? 'high' : 'low',
        });
      }
    }

    return anomalies;
  }

  List<String> recommendProducts(dynamic items, String productId) {
    if (productId.isEmpty) return [];

    final cooccurrence = <String, int>{};
    int targetCount = 0;

    if (items is List<Transaction>) {
      for (final tx in items) {
        final productIds = tx.items.map((i) => i.productId).toSet();
        if (productIds.contains(productId)) {
          targetCount++;
          for (final id in productIds) {
            if (id != productId) {
              cooccurrence[id] = (cooccurrence[id] ?? 0) + 1;
            }
          }
        }
      }
    } else if (items is List<List<String>>) {
      for (final basket in items) {
        final productIds = basket.toSet();
        if (productIds.contains(productId)) {
          targetCount++;
          for (final id in productIds) {
            if (id != productId) {
              cooccurrence[id] = (cooccurrence[id] ?? 0) + 1;
            }
          }
        }
      }
    }

    if (targetCount == 0 || cooccurrence.isEmpty) return [];

    final sorted = cooccurrence.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(5).map((e) => e.key).toList();
  }

  Map<String, List<Product>> abcRanking(
    List<Product> products,
    List<Transaction> transactions,
  ) {
    if (products.isEmpty) {
      return {'A': [], 'B': [], 'C': []};
    }

    final productSales = <String, double>{};
    for (final tx in transactions) {
      for (final item in tx.items) {
        productSales[item.productId] =
            (productSales[item.productId] ?? 0.0) + item.subtotal;
      }
    }

    final totalRevenue = productSales.values.fold(0.0, (a, b) => a + b);
    if (totalRevenue <= 0) {
      return {'A': [], 'B': [], 'C': List<Product>.from(products)};
    }

    final sorted = List<Product>.from(products)
      ..sort((a, b) {
        final revA = productSales[a.id] ?? 0.0;
        final revB = productSales[b.id] ?? 0.0;
        return revB.compareTo(revA);
      });

    final rankA = <Product>[];
    final rankB = <Product>[];
    final rankC = <Product>[];

    double cumulativeRevenue = 0.0;
    for (final product in sorted) {
      final rev = productSales[product.id] ?? 0.0;
      cumulativeRevenue += rev;
      final percentage = (cumulativeRevenue / totalRevenue) * 100;

      if (percentage <= 80) {
        rankA.add(product);
      } else if (percentage <= 95) {
        rankB.add(product);
      } else {
        rankC.add(product);
      }
    }

    return {'A': rankA, 'B': rankB, 'C': rankC};
  }

  Map<String, dynamic> checkMargin(Product product, {double minMarginPercent = 15.0}) {
    final sellingPrice = product.basePrice;
    final costPrice = product.costPrice ?? 0.0;
    final margin = sellingPrice - costPrice;
    final marginPercent = sellingPrice > 0 ? (margin / sellingPrice) * 100 : 0.0;
    final markupPercent = costPrice > 0 ? (margin / costPrice) * 100 : 0.0;

    return {
      'sellingPrice': sellingPrice,
      'costPrice': costPrice,
      'margin': (margin * 100).round() / 100,
      'marginPercent': (marginPercent * 10).round() / 10,
      'markupPercent': (markupPercent * 10).round() / 10,
      'isLowMargin': marginPercent < minMarginPercent,
    };
  }

  List<Map<String, dynamic>> suggestFlashSale(
    List<Product> products,
    List<Transaction> transactions, {
    int daysThreshold = 30,
  }) {
    final now = DateTime.now();
    final lastSaleDateMap = <String, DateTime>{};

    for (final tx in transactions) {
      for (final item in tx.items) {
        final existing = lastSaleDateMap[item.productId];
        if (existing == null || tx.createdAt.isAfter(existing)) {
          lastSaleDateMap[item.productId] = tx.createdAt;
        }
      }
    }

    final suggestions = <Map<String, dynamic>>[];

    for (final product in products) {
      if (product.stock <= 0) continue;

      final lastSold = lastSaleDateMap[product.id];
      final referenceDate = lastSold ?? product.updatedAt ?? product.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final daysInactive = now.difference(referenceDate).inDays;

      if (daysInactive >= daysThreshold) {
        int suggestedDiscount = 20;
        if (daysInactive >= 60) {
          suggestedDiscount = 30;
        } else if (daysInactive >= 45) {
          suggestedDiscount = 25;
        }

        final discountedPrice = product.price * (1 - (suggestedDiscount / 100));

        suggestions.add({
          'product': product,
          'productId': product.id,
          'productName': product.name,
          'stock': product.stock,
          'currentPrice': product.price,
          'suggestedDiscount': suggestedDiscount,
          'suggestedPrice': discountedPrice,
          'daysInactive': daysInactive,
          'reason': lastSold == null
              ? 'Belum pernah terjual sejak ditambahkan ($daysInactive hari)'
              : 'Tidak ada transaksi selama $daysInactive hari',
        });
      }
    }

    suggestions.sort((a, b) => (b['daysInactive'] as int).compareTo(a['daysInactive'] as int));
    return suggestions;
  }

  Map<String, dynamic> calculateMargin(Product product) => checkMargin(product);

  List<Map<String, dynamic>> detectAnomalies(List<double> salesData) {
    if (salesData.length < 3) return [];
    final mean = salesData.reduce((a, b) => a + b) / salesData.length;
    final variance =
        salesData.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) /
        salesData.length;
    final stdDev = sqrt(variance);
    if (stdDev == 0) return [];

    final anomalies = <Map<String, dynamic>>[];
    for (var i = 0; i < salesData.length; i++) {
      final zScore = (salesData[i] - mean) / stdDev;
      if (zScore.abs() > 2.0) {
        anomalies.add({
          'index': i,
          'value': salesData[i],
          'zScore': (zScore * 100).round() / 100,
          'type': zScore > 0 ? 'high' : 'low',
        });
      }
    }
    return anomalies;
  }

  Map<String, List<int>> bestTimeToSell(List<Transaction> transactions) {
    final hourlyCounts = <int, int>{};
    for (final tx in transactions) {
      final hour = tx.createdAt.hour;
      hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + 1;
    }
    final sorted = hourlyCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {
      'bestHours': sorted.take(4).map((e) => e.key).toList(),
      'hourlyData': sorted.map((e) => e.value).toList(),
    };
  }
}
