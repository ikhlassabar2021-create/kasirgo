class ProductVariant {
  final String id;
  final String productId;
  final String name;
  final String? sku;
  final double priceDelta;
  final double stock;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.name,
    this.sku,
    this.priceDelta = 0,
    this.stock = 0,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] ?? '',
      productId: json['product_id'] ?? '',
      name: json['name'] ?? '',
      sku: json['sku'],
      priceDelta: (json['price_delta'] ?? 0).toDouble(),
      stock: (json['stock'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'product_id': productId,
      'name': name,
      'sku': sku,
      'price_delta': priceDelta,
      'stock': stock,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'name': name,
      'sku': sku,
      'price_delta': priceDelta,
      'stock': stock,
    };
  }

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] ?? '',
      productId: map['product_id'] ?? '',
      name: map['name'] ?? '',
      sku: map['sku'],
      priceDelta: (map['price_delta'] ?? 0).toDouble(),
      stock: (map['stock'] ?? 0).toDouble(),
    );
  }

  ProductVariant copyWith({
    String? id,
    String? productId,
    String? name,
    String? sku,
    double? priceDelta,
    double? stock,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      priceDelta: priceDelta ?? this.priceDelta,
      stock: stock ?? this.stock,
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
      delta: (json['delta'] ?? 0).toDouble(),
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
      delta: (map['delta'] ?? 0).toDouble(),
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
