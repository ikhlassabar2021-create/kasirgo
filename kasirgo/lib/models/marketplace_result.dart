import 'outlet_location.dart';
import 'product.dart';

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

/// Hasil RPC `search_marketplace` (Phase 17E): satu produk publik di satu outlet.
class MarketplaceResult {
  final String outletId;
  final String outletName;
  final String? outletType;
  final String productId;
  final String productName;
  final String? category;
  final double price;
  final int stock;
  final String? unit;
  final double? distanceKm;
  final bool hasDelivery;
  final bool isOpen;
  final bool isService;

  const MarketplaceResult({
    required this.outletId,
    required this.outletName,
    this.outletType,
    required this.productId,
    required this.productName,
    this.category,
    this.price = 0,
    this.stock = 0,
    this.unit,
    this.distanceKm,
    this.hasDelivery = false,
    this.isOpen = false,
    this.isService = false,
  });

  factory MarketplaceResult.fromJson(Map<String, dynamic> json) {
    return MarketplaceResult(
      outletId: json['outlet_id']?.toString() ?? '',
      outletName: json['outlet_name']?.toString() ?? '',
      outletType: json['outlet_type']?.toString(),
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      category: json['category']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      unit: json['unit']?.toString(),
      distanceKm: json['distance_km'] == null
          ? null
          : _toDouble(json['distance_km']),
      hasDelivery: json['has_delivery'] == true,
      isOpen: json['is_open'] == true,
      isService: json['is_service'] == true,
    );
  }

  String get distanceLabel {
    final d = distanceKm;
    if (d == null) return 'Jarak tidak diketahui';
    if (d < 1) return '${(d * 1000).round()} m';
    return '${d.toStringAsFixed(1)} km';
  }

  /// Ubah ke [Product] agar bisa masuk keranjang (satu toko per transaksi).
  Product toProduct() => Product(
        id: productId,
        outletId: outletId,
        name: productName,
        category: category,
        basePrice: price,
        stock: stock,
        unit: unit,
        isPublished: true,
        isService: isService,
      );

  /// Ubah ke [NearbyOutlet] agar bisa membuka katalog outlet terkait.
  NearbyOutlet toOutlet() => NearbyOutlet(
        id: outletId,
        name: outletName,
        isOpen: isOpen,
        distanceKm: distanceKm ?? 0,
        hasDelivery: hasDelivery,
      );
}
