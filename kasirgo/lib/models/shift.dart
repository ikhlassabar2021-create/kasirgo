class Shift {
  final String id;
  final String outletId;
  final String? userId;
  final String shift; // pagi, siang, malam
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingCash;
  final double? closingCash;

  const Shift({
    required this.id,
    required this.outletId,
    this.userId,
    this.shift = 'pagi',
    required this.openedAt,
    this.closedAt,
    this.openingCash = 0,
    this.closingCash,
  });

  bool get isOpen => closedAt == null;

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      userId: json['user_id'],
      shift: json['shift'] ?? 'pagi',
      openedAt: json['opened_at'] != null
          ? DateTime.parse(json['opened_at'])
          : DateTime.now(),
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'])
          : null,
      openingCash: (json['opening_cash'] ?? 0).toDouble(),
      closingCash: json['closing_cash'] != null
          ? (json['closing_cash'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'outlet_id': outletId,
      'user_id': userId,
      'shift': shift,
      'opened_at': openedAt.toIso8601String(),
      if (closedAt != null) 'closed_at': closedAt!.toIso8601String(),
      'opening_cash': openingCash,
      if (closingCash != null) 'closing_cash': closingCash,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'user_id': userId,
      'shift': shift,
      'opened_at': openedAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'opening_cash': openingCash,
      'closing_cash': closingCash,
    };
  }

  factory Shift.fromMap(Map<String, dynamic> map) {
    return Shift(
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      userId: map['user_id'],
      shift: map['shift'] ?? 'pagi',
      openedAt: map['opened_at'] != null
          ? DateTime.parse(map['opened_at'])
          : DateTime.now(),
      closedAt: map['closed_at'] != null
          ? DateTime.parse(map['closed_at'])
          : null,
      openingCash: (map['opening_cash'] ?? 0).toDouble(),
      closingCash: map['closing_cash'] != null
          ? (map['closing_cash'] as num).toDouble()
          : null,
    );
  }

  Shift copyWith({
    String? id,
    String? outletId,
    String? userId,
    String? shift,
    DateTime? openedAt,
    DateTime? closedAt,
    double? openingCash,
    double? closingCash,
  }) {
    return Shift(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      userId: userId ?? this.userId,
      shift: shift ?? this.shift,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      openingCash: openingCash ?? this.openingCash,
      closingCash: closingCash ?? this.closingCash,
    );
  }
}
