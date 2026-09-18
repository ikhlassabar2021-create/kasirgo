class PpobProduct {
  final String id;
  final String sku;
  final String name;
  final String? category;
  final double? costPrice;
  final double? sellPrice;

  const PpobProduct({
    required this.id,
    required this.sku,
    required this.name,
    this.category,
    this.costPrice,
    this.sellPrice,
  });

  factory PpobProduct.fromJson(Map<String, dynamic> json) {
    return PpobProduct(
      id: json['id'] ?? '',
      sku: json['sku'] ?? '',
      name: json['name'] ?? '',
      category: json['category'],
      costPrice: json['cost_price'] != null
          ? (json['cost_price'] as num).toDouble()
          : null,
      sellPrice: json['sell_price'] != null
          ? (json['sell_price'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'sku': sku,
      'name': name,
      'category': category,
      'cost_price': costPrice,
      'sell_price': sellPrice,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sku': sku,
      'name': name,
      'category': category,
      'cost_price': costPrice,
      'sell_price': sellPrice,
    };
  }

  factory PpobProduct.fromMap(Map<String, dynamic> map) {
    return PpobProduct(
      id: map['id'] ?? '',
      sku: map['sku'] ?? '',
      name: map['name'] ?? '',
      category: map['category'],
      costPrice: map['cost_price'] != null
          ? (map['cost_price'] as num).toDouble()
          : null,
      sellPrice: map['sell_price'] != null
          ? (map['sell_price'] as num).toDouble()
          : null,
    );
  }

  PpobProduct copyWith({
    String? id,
    String? sku,
    String? name,
    String? category,
    double? costPrice,
    double? sellPrice,
  }) {
    return PpobProduct(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      category: category ?? this.category,
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
    );
  }
}

class PpobTransaction {
  final String id;
  final String outletId;
  final String? ppobProductId;
  final String? customerRef;
  final double amount;
  final String status; // pending, success, failed
  final String? providerRef;
  final DateTime createdAt;

  const PpobTransaction({
    required this.id,
    required this.outletId,
    this.ppobProductId,
    this.customerRef,
    required this.amount,
    this.status = 'pending',
    this.providerRef,
    required this.createdAt,
  });

  factory PpobTransaction.fromJson(Map<String, dynamic> json) {
    return PpobTransaction(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      ppobProductId: json['ppob_product_id'],
      customerRef: json['customer_ref'],
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      providerRef: json['provider_ref'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'outlet_id': outletId,
      'ppob_product_id': ppobProductId,
      'customer_ref': customerRef,
      'amount': amount,
      'status': status,
      'provider_ref': providerRef,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'ppob_product_id': ppobProductId,
      'customer_ref': customerRef,
      'amount': amount,
      'status': status,
      'provider_ref': providerRef,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PpobTransaction.fromMap(Map<String, dynamic> map) {
    return PpobTransaction(
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      ppobProductId: map['ppob_product_id'],
      customerRef: map['customer_ref'],
      amount: (map['amount'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      providerRef: map['provider_ref'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  PpobTransaction copyWith({
    String? id,
    String? outletId,
    String? ppobProductId,
    String? customerRef,
    double? amount,
    String? status,
    String? providerRef,
    DateTime? createdAt,
  }) {
    return PpobTransaction(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      ppobProductId: ppobProductId ?? this.ppobProductId,
      customerRef: customerRef ?? this.customerRef,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      providerRef: providerRef ?? this.providerRef,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
