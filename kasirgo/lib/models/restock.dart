class RestockOrder {
  final String id;
  final String outletId;
  final String? distributor;
  final String? trackingId;
  final double amount;
  final String status; // draft, pending, confirmed, shipped, completed, cancelled
  final DateTime createdAt;

  const RestockOrder({
    required this.id,
    required this.outletId,
    this.distributor,
    this.trackingId,
    this.amount = 0,
    this.status = 'draft',
    required this.createdAt,
  });

  factory RestockOrder.fromJson(Map<String, dynamic> json) {
    return RestockOrder(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      distributor: json['distributor'],
      trackingId: json['tracking_id'],
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'draft',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'outlet_id': outletId,
      'distributor': distributor,
      'tracking_id': trackingId,
      'amount': amount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'distributor': distributor,
      'tracking_id': trackingId,
      'amount': amount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory RestockOrder.fromMap(Map<String, dynamic> map) {
    return RestockOrder(
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      distributor: map['distributor'],
      trackingId: map['tracking_id'],
      amount: (map['amount'] ?? 0).toDouble(),
      status: map['status'] ?? 'draft',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  RestockOrder copyWith({
    String? id,
    String? outletId,
    String? distributor,
    String? trackingId,
    double? amount,
    String? status,
    DateTime? createdAt,
  }) {
    return RestockOrder(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      distributor: distributor ?? this.distributor,
      trackingId: trackingId ?? this.trackingId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
