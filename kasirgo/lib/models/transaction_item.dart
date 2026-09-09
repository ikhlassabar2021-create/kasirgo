class TransactionItem {
  final String id;
  final String transactionId;
  final String? productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double subtotal;

  TransactionItem({required this.id, required this.transactionId, this.productId, required this.productName, required this.quantity, required this.unitPrice, this.discount = 0, required this.subtotal});

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] ?? '', transactionId: json['transaction_id'] ?? '', productId: json['product_id'],
      productName: json['product_name'] ?? '', quantity: (json['quantity'] ?? 0).toDouble(),
      unitPrice: (json['unit_price'] ?? 0).toDouble(), discount: (json['discount'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'transaction_id': transactionId, 'product_id': productId, 'product_name': productName, 'quantity': quantity, 'unit_price': unitPrice, 'discount': discount, 'subtotal': subtotal};
  Map<String, dynamic> toMap() => toJson();
  factory TransactionItem.fromMap(Map<String, dynamic> map) => TransactionItem.fromJson(map);
}