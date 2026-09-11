import 'dart:math';
import '../models/product.dart';
import '../models/transaction.dart';

class AIEngine {
  List<double> predictSales(List<double> historicalSales, int periods) {
    if (historicalSales.isEmpty) return List.filled(periods, 0.0);
    if (historicalSales.length == 1) {
      return List.filled(periods, historicalSales.last);
    }

    final windowSize = min(7, historicalSales.length);
    final recent = historicalSales.sublist(historicalSales.length - windowSize);
    final avg = recent.reduce((a, b) => a + b) / recent.length;

    return List.filled(periods, (avg * 10).round() / 10);
  }

  List<Map<String, dynamic>> detectAnomalies(List<double> salesData) {
    if (salesData.length < 5) return [];

    final mean = salesData.reduce((a, b) => a + b) / salesData.length;
    final stdDev = sqrt(
      salesData.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) /
          salesData.length,
    );

    if (stdDev == 0) return [];

    final anomalies = <Map<String, dynamic>>[];
    for (var i = 0; i < salesData.length; i++) {
      final zScore = (salesData[i] - mean) / stdDev;
      if (zScore.abs() > 2.0) {
        anomalies.add({
          'index': i,
          'value': salesData[i],
          'zScore': zScore.toStringAsFixed(2),
          'type': zScore > 0 ? 'high' : 'low',
        });
      }
    }

    return anomalies;
  }

  Map<String, List<Product>> abcRanking(
    List<Product> products,
    List<Transaction> transactions,
  ) {
    final productSales = <String, double>{};

    for (final tx in transactions) {
      for (final item in tx.items) {
        productSales[item.productId] =
            (productSales[item.productId] ?? 0) + item.subtotal;
      }
    }

    final totalRevenue = productSales.values.fold(0.0, (a, b) => a + b);
    if (totalRevenue == 0) {
      return {'A': [], 'B': [], 'C': products};
    }

    final sorted = products.toList()
      ..sort((a, b) {
        final aValue = productSales[a.id] ?? 0;
        final bValue = productSales[b.id] ?? 0;
        return bValue.compareTo(aValue);
      });

    final rankA = <Product>[];
    final rankB = <Product>[];
    final rankC = <Product>[];

    double cumulative = 0;
    for (final product in sorted) {
      final value = productSales[product.id] ?? 0;
      cumulative += value;
      final percentage = (cumulative / totalRevenue) * 100;

      if (percentage <= 70) {
        rankA.add(product);
      } else if (percentage <= 90) {
        rankB.add(product);
      } else {
        rankC.add(product);
      }
    }

    return {'A': rankA, 'B': rankB, 'C': rankC};
  }

  List<Product> recommendRelated(
    Product target,
    List<Product> allProducts,
    List<Transaction> transactions,
  ) {
    final cooccurrences = <String, int>{};

    for (final tx in transactions) {
      final itemIds = tx.items.map((item) => item.productId).toSet();
      if (itemIds.contains(target.id)) {
        for (final id in itemIds) {
          if (id != target.id) {
            cooccurrences[id] = (cooccurrences[id] ?? 0) + 1;
          }
        }
      }
    }

    final sorted = cooccurrences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final recommendations = <Product>[];
    for (final entry in sorted.take(5)) {
      final product = allProducts.where((p) => p.id == entry.key).firstOrNull;
      if (product != null) {
        recommendations.add(product);
      }
    }

    return recommendations;
  }

  Map<String, double> calculateMargin(Product product) {
    final margin = product.price - (product.costPrice ?? 0);
    final marginPercent =
        product.costPrice != null && product.costPrice! > 0
            ? (margin / product.costPrice!) * 100
            : 0.0;

    return {
      'margin': margin,
      'marginPercent': marginPercent,
    };
  }

  List<Product> marginAlert(List<Product> products, {double threshold = 10}) {
    return products.where((product) {
      final margin = calculateMargin(product);
      return margin['marginPercent']! < threshold;
    }).toList();
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