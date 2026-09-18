import 'dart:convert';

class TransactionItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final double subtotal;
  final String? variantId;
  final String? note;

  const TransactionItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.subtotal,
    this.variantId,
    this.note,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      variantId: json['variant_id']?.toString(),
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'subtotal': subtotal,
      if (variantId != null) 'variant_id': variantId,
      if (note != null) 'note': note,
    };
  }

  TransactionItem copyWith({
    String? productId,
    String? productName,
    double? price,
    int? quantity,
    double? subtotal,
    String? variantId,
    String? note,
  }) {
    return TransactionItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
      variantId: variantId ?? this.variantId,
      note: note ?? this.note,
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
  final String channel;
  final DateTime createdAt;
  final String? gatewayRef;
  final String settlementStatus;
  final double tipAmount;
  final String? shiftId;
  final String? debtId;
  final String syncStatus;
  final String? eventId;
  final String? deviceId;

  const Transaction({
    required this.id,
    required this.outletId,
    this.cashierId,
    this.customerId,
    this.items = const [],
    required this.totalAmount,
    this.discountAmount,
    this.taxAmount,
    required this.finalAmount,
    required this.paymentMethod,
    this.paymentStatus,
    this.notes,
    this.isSynced = false,
    this.channel = 'offline',
    required this.createdAt,
    this.gatewayRef,
    this.settlementStatus = 'n/a',
    this.tipAmount = 0,
    this.shiftId,
    this.debtId,
    this.syncStatus = 'synced',
    this.eventId,
    this.deviceId,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    List<TransactionItem> items = [];
    if (json['transaction_items'] != null && json['transaction_items'] is List) {
      items = (json['transaction_items'] as List)
          .map((i) => TransactionItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } else if (json['items'] != null && json['items'] is List) {
      items = (json['items'] as List)
          .map((i) => TransactionItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    return Transaction(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      cashierId: json['user_id'] ?? json['cashier_id'],
      customerId: json['customer_id'],
      items: items,
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      discountAmount: json['total_discount'] != null
          ? (json['total_discount'] as num).toDouble()
          : json['discount_amount']?.toDouble(),
      taxAmount: json['tax_amount']?.toDouble(),
      finalAmount: (json['final_amount'] ?? 0).toDouble(),
      paymentMethod: json['payment_method'] ?? 'Tunai',
      paymentStatus: json['payment_status'] ?? json['status'],
      notes: json['notes'],
      isSynced: json['is_synced'] == true || json['is_synced'] == 1,
      channel: json['channel']?.toString() ?? 'offline',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      gatewayRef: json['gateway_ref']?.toString(),
      settlementStatus: json['settlement_status']?.toString() ?? 'n/a',
      tipAmount: (json['tip_amount'] ?? 0).toDouble(),
      shiftId: json['shift_id']?.toString(),
      debtId: json['debt_id']?.toString(),
      syncStatus: json['sync_status']?.toString() ?? 'synced',
      eventId: json['event_id']?.toString(),
      deviceId: json['device_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'outlet_id': outletId,
      'user_id': cashierId,
      'customer_id': customerId,
      'channel': channel,
      'payment_method': paymentMethod,
      'total_amount': totalAmount,
      'total_discount': discountAmount ?? 0,
      'final_amount': finalAmount,
      'status': paymentStatus == 'voided' ? 'voided' : 'completed',
      'created_at': createdAt.toIso8601String(),
      'gateway_ref': gatewayRef,
      'settlement_status': settlementStatus,
      'tip_amount': tipAmount,
      'shift_id': shiftId,
      'debt_id': debtId,
      'sync_status': syncStatus,
      'event_id': eventId,
      'device_id': deviceId,
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
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
      'channel': channel,
      'created_at': createdAt.toIso8601String(),
      'gateway_ref': gatewayRef,
      'settlement_status': settlementStatus,
      'tip_amount': tipAmount,
      'shift_id': shiftId,
      'debt_id': debtId,
      'sync_status': syncStatus,
      'event_id': eventId,
      'device_id': deviceId,
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
      } else if (map['items'] is List) {
        items = (map['items'] as List)
            .map((i) => TransactionItem.fromJson(i as Map<String, dynamic>))
            .toList();
      }
    }

    return Transaction(
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      cashierId: map['cashier_id'] ?? map['user_id'],
      customerId: map['customer_id'],
      items: items,
      totalAmount: (map['total_amount'] ?? 0).toDouble(),
      discountAmount: map['discount_amount']?.toDouble() ??
          (map['total_discount'] != null
              ? (map['total_discount'] as num).toDouble()
              : null),
      taxAmount: map['tax_amount']?.toDouble(),
      finalAmount: (map['final_amount'] ?? 0).toDouble(),
      paymentMethod: map['payment_method'] ?? 'Tunai',
      paymentStatus: map['payment_status'] ?? map['status'],
      notes: map['notes'],
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
      channel: map['channel']?.toString() ?? 'offline',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      gatewayRef: map['gateway_ref']?.toString(),
      settlementStatus: map['settlement_status']?.toString() ?? 'n/a',
      tipAmount: (map['tip_amount'] ?? 0).toDouble(),
      shiftId: map['shift_id']?.toString(),
      debtId: map['debt_id']?.toString(),
      syncStatus: map['sync_status']?.toString() ?? 'synced',
      eventId: map['event_id']?.toString(),
      deviceId: map['device_id']?.toString(),
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
    String? channel,
    DateTime? createdAt,
    String? gatewayRef,
    String? settlementStatus,
    double? tipAmount,
    String? shiftId,
    String? debtId,
    String? syncStatus,
    String? eventId,
    String? deviceId,
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
      channel: channel ?? this.channel,
      createdAt: createdAt ?? this.createdAt,
      gatewayRef: gatewayRef ?? this.gatewayRef,
      settlementStatus: settlementStatus ?? this.settlementStatus,
      tipAmount: tipAmount ?? this.tipAmount,
      shiftId: shiftId ?? this.shiftId,
      debtId: debtId ?? this.debtId,
      syncStatus: syncStatus ?? this.syncStatus,
      eventId: eventId ?? this.eventId,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
