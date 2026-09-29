class ProductVariant {
  final String id;
  final String outletId;
  final String productId;
  final String name;
  final String? sku;
  final String? barcode;
  final double priceDelta;
  final double stock;
  final bool isActive;

  const ProductVariant({
    required this.id,
    this.outletId = '',
    required this.productId,
    required this.name,
    this.sku,
    this.barcode,
    this.priceDelta = 0,
    this.stock = 0,
    this.isActive = true,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      productId: json['product_id'] ?? '',
      name: json['name'] ?? '',
      sku: json['sku']?.toString(),
      barcode: json['barcode']?.toString(),
      priceDelta: (json['price_delta'] ?? 0).toDouble(),
      stock: (json['stock'] ?? 0).toDouble(),
      isActive: json['is_active'] == null || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      if (outletId.isNotEmpty) 'outlet_id': outletId,
      'product_id': productId,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'price_delta': priceDelta,
      'stock': stock,
      'is_active': isActive,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'product_id': productId,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'price_delta': priceDelta,
      'stock': stock,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      productId: map['product_id'] ?? '',
      name: map['name'] ?? '',
      sku: map['sku']?.toString(),
      barcode: map['barcode']?.toString(),
      priceDelta: (map['price_delta'] ?? 0).toDouble(),
      stock: (map['stock'] ?? 0).toDouble(),
      isActive: map['is_active'] == null || map['is_active'] == 1 || map['is_active'] == true,
    );
  }

  ProductVariant copyWith({
    String? id,
    String? outletId,
    String? productId,
    String? name,
    String? sku,
    String? barcode,
    double? priceDelta,
    double? stock,
    bool? isActive,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      priceDelta: priceDelta ?? this.priceDelta,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
    );
  }
}

class StockLog {
  final String id;
  final String outletId;
  final String? productId;
  final String? variantId;
  final double delta;
  final String reason;
  final String? refId;
  final String? deviceId;
  final String? eventId;
  final DateTime createdAt;

  const StockLog({
    required this.id,
    required this.outletId,
    this.productId,
    this.variantId,
    required this.delta,
    required this.reason,
    this.refId,
    this.deviceId,
    this.eventId,
    required this.createdAt,
  });

  factory StockLog.fromJson(Map<String, dynamic> json) {
    return StockLog(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      productId: json['product_id'],
      variantId: json['variant_id'],
      delta: (json['delta'] ?? json['change'] ?? 0).toDouble(),
      reason: json['reason'] ?? '',
      refId: json['ref_id'],
      deviceId: json['device_id'],
      eventId: json['event_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'outlet_id': outletId,
      'product_id': productId,
      'variant_id': variantId,
      'delta': delta,
      'change': delta,
      'reason': reason,
      'ref_id': refId,
      'device_id': deviceId,
      'event_id': eventId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'product_id': productId,
      'variant_id': variantId,
      'delta': delta,
      'change': delta,
      'reason': reason,
      'ref_id': refId,
      'device_id': deviceId,
      'event_id': eventId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory StockLog.fromMap(Map<String, dynamic> map) {
    return StockLog(
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      productId: map['product_id'],
      variantId: map['variant_id'],
      delta: (map['delta'] ?? map['change'] ?? 0).toDouble(),
      reason: map['reason'] ?? '',
      refId: map['ref_id'],
      deviceId: map['device_id'],
      eventId: map['event_id'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  StockLog copyWith({
    String? id,
    String? outletId,
    String? productId,
    String? variantId,
    double? delta,
    String? reason,
    String? refId,
    String? deviceId,
    String? eventId,
    DateTime? createdAt,
  }) {
    return StockLog(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      delta: delta ?? this.delta,
      reason: reason ?? this.reason,
      refId: refId ?? this.refId,
      deviceId: deviceId ?? this.deviceId,
      eventId: eventId ?? this.eventId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
