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
  final String? userId;
  final String? ppobProductId;
  final String productName;
  final String customerRef;
  final double amount;
  final double costAmount;
  final double profit;
  final String status; // pending, success, failed
  final String paymentMethod; // cash, qris, saldo
  final String? providerRef;
  final String? note;
  final DateTime createdAt;

  const PpobTransaction({
    required this.id,
    required this.outletId,
    this.userId,
    this.ppobProductId,
    this.productName = '',
    this.customerRef = '',
    required this.amount,
    this.costAmount = 0,
    this.profit = 0,
    this.status = 'pending',
    this.paymentMethod = 'cash',
    this.providerRef,
    this.note,
    required this.createdAt,
  });

  factory PpobTransaction.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) =>
        v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);
    return PpobTransaction(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      userId: json['user_id']?.toString(),
      ppobProductId: json['ppob_product_id'],
      productName: json['product_name']?.toString() ?? '',
      customerRef: json['customer_ref']?.toString() ?? '',
      amount: d(json['amount']),
      costAmount: d(json['cost_amount']),
      profit: d(json['profit']),
      status: json['status'] ?? 'pending',
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      providerRef: json['provider_ref'],
      note: json['note']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'outlet_id': outletId,
      if (userId != null) 'user_id': userId,
      'ppob_product_id': ppobProductId,
      'product_name': productName,
      'customer_ref': customerRef,
      'amount': amount,
      'cost_amount': costAmount,
      'profit': profit,
      'status': status,
      'payment_method': paymentMethod,
      if (providerRef != null) 'provider_ref': providerRef,
      if (note != null) 'note': note,
    };
  }

  factory PpobTransaction.fromMap(Map<String, dynamic> map) {
    return PpobTransaction.fromJson(map);
  }

  PpobTransaction copyWith({
    String? id,
    String? outletId,
    String? userId,
    String? ppobProductId,
    String? productName,
    String? customerRef,
    double? amount,
    double? costAmount,
    double? profit,
    String? status,
    String? paymentMethod,
    String? providerRef,
    String? note,
    DateTime? createdAt,
  }) {
    return PpobTransaction(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      userId: userId ?? this.userId,
      ppobProductId: ppobProductId ?? this.ppobProductId,
      productName: productName ?? this.productName,
      customerRef: customerRef ?? this.customerRef,
      amount: amount ?? this.amount,
      costAmount: costAmount ?? this.costAmount,
      profit: profit ?? this.profit,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      providerRef: providerRef ?? this.providerRef,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
