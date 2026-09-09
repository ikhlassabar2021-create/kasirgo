import 'transaction_item.dart';

class Transaction {
  final String id;
  final String outletId;
  final String? userId;
  final String? customerId;
  final String channel;
  final String paymentMethod;
  final double totalAmount;
  final double totalDiscount;
  final double finalAmount;
  final String status;
  final DateTime? createdAt;
  final List<TransactionItem> items;
  final bool isSynced;
  final DateTime? lastModified;

  Transaction({required this.id, required this.outletId, this.userId, this.customerId, this.channel = 'offline', this.paymentMethod = 'cash', required this.totalAmount, this.totalDiscount = 0, required this.finalAmount, this.status = 'completed', this.createdAt, this.items = const [], this.isSynced = true, this.lastModified});

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? '', outletId: json['outlet_id'] ?? '', userId: json['user_id'],
      customerId: json['customer_id'], channel: json['channel'] ?? 'offline',
      paymentMethod: json['payment_method'] ?? 'cash',
      totalAmount: (json['total_amount'] ?? 0).toDouble(), totalDiscount: (json['total_discount'] ?? 0).toDouble(),
      finalAmount: (json['final_amount'] ?? 0).toDouble(), status: json['status'] ?? 'completed',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      items: json['transaction_items'] != null ? (json['transaction_items'] as List).map((e) => TransactionItem.fromJson(e)).toList() : [],
      isSynced: json['is_synced'] ?? true, lastModified: json['last_modified'] != null ? DateTime.parse(json['last_modified']) : null,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'outlet_id': outletId, 'user_id': userId, 'customer_id': customerId, 'channel': channel, 'payment_method': paymentMethod, 'total_amount': totalAmount, 'total_discount': totalDiscount, 'final_amount': finalAmount, 'status': status, 'is_synced': isSynced, 'last_modified': lastModified?.toIso8601String()};
  Map<String, dynamic> toMap() => toJson();
  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction.fromJson(map);
}