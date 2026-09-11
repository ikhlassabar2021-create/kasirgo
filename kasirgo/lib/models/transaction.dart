import 'dart:convert';

class TransactionItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final double subtotal;

  const TransactionItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  TransactionItem copyWith({
    String? productId,
    String? productName,
    double? price,
    int? quantity,
    double? subtotal,
  }) {
    return TransactionItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
    );
  }
}

class Transaction {
  final String id;
  final String outletId;
  final String? cashierId;
  final String? customerId;
  final List<TransactionItem> items;
  final double totalAmount;
  final double? discountAmount;
  final double? taxAmount;
  final double finalAmount;
  final String paymentMethod;
  final String? paymentStatus;
  final String? notes;
  final bool isSynced;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.outletId,
    this.cashierId,
    this.customerId,
    required this.items,
    required this.totalAmount,
    this.discountAmount,
    this.taxAmount,
    required this.finalAmount,
    required this.paymentMethod,
    this.paymentStatus,
    this.notes,
    this.isSynced = false,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    List<TransactionItem> items = [];
    if (json['items'] != null) {
      if (json['items'] is String) {
        final decoded = jsonDecode(json['items'] as String);
        items = (decoded as List)
            .map((i) => TransactionItem.fromJson(i as Map<String, dynamic>))
            .toList();
      } else if (json['items'] is List) {
        items = (json['items'] as List)
            .map((i) => TransactionItem.fromJson(i as Map<String, dynamic>))
            .toList();
      }
    }

    return Transaction(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      cashierId: json['cashier_id'],
      customerId: json['customer_id'],
      items: items,
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      discountAmount: json['discount_amount']?.toDouble(),
      taxAmount: json['tax_amount']?.toDouble(),
      finalAmount: (json['final_amount'] ?? 0).toDouble(),
      paymentMethod: json['payment_method'] ?? 'Tunai',
      paymentStatus: json['payment_status'],
      notes: json['notes'],
      isSynced: json['is_synced'] == true || json['is_synced'] == 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'cashier_id': cashierId,
      'customer_id': customerId,
      'items': jsonEncode(items.map((i) => i.toJson()).toList()),
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'final_amount': finalAmount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'notes': notes,
      'is_synced': isSynced,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'cashier_id': cashierId,
      'customer_id': customerId,
      'items': jsonEncode(items.map((i) => i.toJson()).toList()),
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'final_amount': finalAmount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'notes': notes,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    List<TransactionItem> items = [];
    if (map['items'] != null) {
      if (map['items'] is String) {
        final decoded = jsonDecode(map['items'] as String);
        items = (decoded as List)
            .map((i) => TransactionItem.fromJson(i as Map<String, dynamic>))
            .toList();
      }
    }

    return Transaction(
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      cashierId: map['cashier_id'],
      customerId: map['customer_id'],
      items: items,
      totalAmount: (map['total_amount'] ?? 0).toDouble(),
      discountAmount: map['discount_amount']?.toDouble(),
      taxAmount: map['tax_amount']?.toDouble(),
      finalAmount: (map['final_amount'] ?? 0).toDouble(),
      paymentMethod: map['payment_method'] ?? 'Tunai',
      paymentStatus: map['payment_status'],
      notes: map['notes'],
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Transaction copyWith({
    String? id,
    String? outletId,
    String? cashierId,
    String? customerId,
    List<TransactionItem>? items,
    double? totalAmount,
    double? discountAmount,
    double? taxAmount,
    double? finalAmount,
    String? paymentMethod,
    String? paymentStatus,
    String? notes,
    bool? isSynced,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      cashierId: cashierId ?? this.cashierId,
      customerId: customerId ?? this.customerId,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      finalAmount: finalAmount ?? this.finalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      notes: notes ?? this.notes,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}