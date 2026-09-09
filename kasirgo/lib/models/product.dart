class Product {
  final String id;
  final String outletId;
  final String name;
  final String category;
  final String? barcode;
  final double costPrice;
  final double basePrice;
  final double stock;
  final String unit;
  final DateTime? expiredDate;
  final String? imageUrl;
  final double minStockAlert;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isSynced;
  final DateTime? lastModified;

  Product({required this.id, required this.outletId, required this.name, this.category = 'Umum', this.barcode, this.costPrice = 0, required this.basePrice, this.stock = 0, this.unit = 'pcs', this.expiredDate, this.imageUrl, this.minStockAlert = 5, this.createdAt, this.updatedAt, this.isSynced = true, this.lastModified});

  Product copyWith({String? id, String? outletId, String? name, String? category, String? barcode, double? costPrice, double? basePrice, double? stock, String? unit, DateTime? expiredDate, String? imageUrl, double? minStockAlert, DateTime? createdAt, DateTime? updatedAt, bool? isSynced, DateTime? lastModified}) {
    return Product(
      id: id ?? this.id, outletId: outletId ?? this.outletId, name: name ?? this.name, category: category ?? this.category,
      barcode: barcode ?? this.barcode, costPrice: costPrice ?? this.costPrice, basePrice: basePrice ?? this.basePrice,
      stock: stock ?? this.stock, unit: unit ?? this.unit, expiredDate: expiredDate ?? this.expiredDate,
      imageUrl: imageUrl ?? this.imageUrl, minStockAlert: minStockAlert ?? this.minStockAlert,
      createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced, lastModified: lastModified ?? this.lastModified,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '', outletId: json['outlet_id'] ?? '', name: json['name'] ?? '',
      category: json['category'] ?? 'Umum', barcode: json['barcode'],
      costPrice: (json['cost_price'] ?? 0).toDouble(), basePrice: (json['base_price'] ?? 0).toDouble(),
      stock: (json['stock'] ?? 0).toDouble(), unit: json['unit'] ?? 'pcs',
      expiredDate: json['expired_date'] != null ? DateTime.parse(json['expired_date']) : null,
      imageUrl: json['image_url'], minStockAlert: (json['min_stock_alert'] ?? 5).toDouble(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      isSynced: json['is_synced'] ?? true, lastModified: json['last_modified'] != null ? DateTime.parse(json['last_modified']) : null,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'outlet_id': outletId, 'name': name, 'category': category, 'barcode': barcode, 'cost_price': costPrice, 'base_price': basePrice, 'stock': stock, 'unit': unit, 'expired_date': expiredDate?.toIso8601String(), 'image_url': imageUrl, 'min_stock_alert': minStockAlert, 'is_synced': isSynced, 'last_modified': lastModified?.toIso8601String()};
  Map<String, dynamic> toMap() => toJson();
  factory Product.fromMap(Map<String, dynamic> map) => Product.fromJson(map);
}