class Shift {
  final String id;
  final String outletId;
  final String userId;
  final String status; // open | closed
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingCash;
  final double? closingCash;
  final double? expectedCash;
  final double? difference;
  final double? totalCash;
  final double? totalQris;
  final double? totalTransfer;
  final double totalTip;
  final String? note;

  const Shift({
    required this.id,
    required this.outletId,
    required this.userId,
    this.status = 'open',
    required this.openedAt,
    this.closedAt,
    this.openingCash = 0,
    this.closingCash,
    this.expectedCash,
    this.difference,
    this.totalCash,
    this.totalQris,
    this.totalTransfer,
    this.totalTip = 0,
    this.note,
  });

  bool get isOpen => status == 'open';

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: (json['id'] ?? '').toString(),
      outletId: (json['outlet_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      status: json['status'] ?? 'open',
      openedAt: json['opened_at'] != null
          ? DateTime.parse(json['opened_at'])
          : DateTime.now(),
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'])
          : null,
      openingCash: _d(json['opening_cash']),
      closingCash: json['closing_cash'] == null
          ? null
          : _d(json['closing_cash']),
      expectedCash: json['expected_cash'] == null
          ? null
          : _d(json['expected_cash']),
      difference:
          json['difference'] == null ? null : _d(json['difference']),
      totalCash: json['total_cash'] == null ? null : _d(json['total_cash']),
      totalQris: json['total_qris'] == null ? null : _d(json['total_qris']),
      totalTransfer: json['total_transfer'] == null
          ? null
          : _d(json['total_transfer']),
      totalTip: _d(json['total_tip']),
      note: json['note']?.toString(),
    );
  }

  static double _d(dynamic v) =>
      v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'outlet_id': outletId,
      'user_id': userId,
      'status': status,
      'opened_at': openedAt.toIso8601String(),
      if (closedAt != null) 'closed_at': closedAt!.toIso8601String(),
      'opening_cash': openingCash,
      if (closingCash != null) 'closing_cash': closingCash,
      if (expectedCash != null) 'expected_cash': expectedCash,
      if (difference != null) 'difference': difference,
      if (totalCash != null) 'total_cash': totalCash,
      if (totalQris != null) 'total_qris': totalQris,
      if (totalTransfer != null) 'total_transfer': totalTransfer,
      'total_tip': totalTip,
      if (note != null) 'note': note,
    };
  }

  Shift copyWith({
    String? id,
    String? outletId,
    String? userId,
    String? status,
    DateTime? openedAt,
    DateTime? closedAt,
    double? openingCash,
    double? closingCash,
    double? expectedCash,
    double? difference,
    double? totalCash,
    double? totalQris,
    double? totalTransfer,
    double? totalTip,
    String? note,
  }) {
    return Shift(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      openingCash: openingCash ?? this.openingCash,
      closingCash: closingCash ?? this.closingCash,
      expectedCash: expectedCash ?? this.expectedCash,
      difference: difference ?? this.difference,
      totalCash: totalCash ?? this.totalCash,
      totalQris: totalQris ?? this.totalQris,
      totalTransfer: totalTransfer ?? this.totalTransfer,
      totalTip: totalTip ?? this.totalTip,
      note: note ?? this.note,
    );
  }
}
