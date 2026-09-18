class Tip {
  final String id;
  final String outletId;
  final String? transactionId;
  final String? userId;
  final double amount;
  final DateTime createdAt;

  const Tip({
    required this.id,
    required this.outletId,
    this.transactionId,
    this.userId,
    required this.amount,
    required this.createdAt,
  });

  factory Tip.fromJson(Map<String, dynamic> json) {
    return Tip(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      transactionId: json['transaction_id'],
      userId: json['user_id'],
      amount: (json['amount'] ?? 0).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'outlet_id': outletId,
      'transaction_id': transactionId,
      'user_id': userId,
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'transaction_id': transactionId,
      'user_id': userId,
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Tip.fromMap(Map<String, dynamic> map) {
    return Tip(
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      transactionId: map['transaction_id'],
      userId: map['user_id'],
      amount: (map['amount'] ?? 0).toDouble(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Tip copyWith({
    String? id,
    String? outletId,
    String? transactionId,
    String? userId,
    double? amount,
    DateTime? createdAt,
  }) {
    return Tip(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      transactionId: transactionId ?? this.transactionId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
