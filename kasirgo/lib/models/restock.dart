class RestockOrder {
  final String id;
  final String outletId;
  final String? userId;
  final String? distributor;
  final String? trackingId;
  final double amount;
  final double commission;
  final String status; // draft, pending, confirmed, shipped, completed, cancelled
  final String? itemsNote;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const RestockOrder({
    required this.id,
    required this.outletId,
    this.userId,
    this.distributor,
    this.trackingId,
    this.amount = 0,
    this.commission = 0,
    this.status = 'draft',
    this.itemsNote,
    required this.createdAt,
    this.updatedAt,
  });

  factory RestockOrder.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) =>
        v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);
    return RestockOrder(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      userId: json['user_id']?.toString(),
      distributor: json['distributor'],
      trackingId: json['tracking_id'],
      amount: d(json['amount']),
      commission: d(json['commission']),
      status: json['status'] ?? 'draft',
      itemsNote: json['items_note']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt:
          json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'outlet_id': outletId,
      if (userId != null) 'user_id': userId,
      'distributor': distributor,
      'tracking_id': trackingId,
      'amount': amount,
      'commission': commission,
      'status': status,
      if (itemsNote != null) 'items_note': itemsNote,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'distributor': distributor,
      'tracking_id': trackingId,
      'amount': amount,
      'commission': commission,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory RestockOrder.fromMap(Map<String, dynamic> map) {
    return RestockOrder.fromJson(map);
  }

  RestockOrder copyWith({
    String? id,
    String? outletId,
    String? userId,
    String? distributor,
    String? trackingId,
    double? amount,
    double? commission,
    String? status,
    String? itemsNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RestockOrder(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      userId: userId ?? this.userId,
      distributor: distributor ?? this.distributor,
      trackingId: trackingId ?? this.trackingId,
      amount: amount ?? this.amount,
      commission: commission ?? this.commission,
      status: status ?? this.status,
      itemsNote: itemsNote ?? this.itemsNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
