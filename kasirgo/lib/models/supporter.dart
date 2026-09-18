class Supporter {
  final String id;
  final String outletId;
  final String tier; // pendukung, pro, setia
  final DateTime startDate;
  final DateTime? endDate;
  final double amount;
  final String status; // active, expired, cancelled

  const Supporter({
    required this.id,
    required this.outletId,
    required this.tier,
    required this.startDate,
    this.endDate,
    this.amount = 0,
    this.status = 'active',
  });

  factory Supporter.fromJson(Map<String, dynamic> json) {
    return Supporter(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      tier: json['tier'] ?? 'pendukung',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : null,
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'outlet_id': outletId,
      'tier': tier,
      'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate!.toIso8601String(),
      'amount': amount,
      'status': status,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'tier': tier,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'amount': amount,
      'status': status,
    };
  }

  factory Supporter.fromMap(Map<String, dynamic> map) {
    return Supporter(
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      tier: map['tier'] ?? 'pendukung',
      startDate: map['start_date'] != null
          ? DateTime.parse(map['start_date'])
          : DateTime.now(),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'])
          : null,
      amount: (map['amount'] ?? 0).toDouble(),
      status: map['status'] ?? 'active',
    );
  }

  Supporter copyWith({
    String? id,
    String? outletId,
    String? tier,
    DateTime? startDate,
    DateTime? endDate,
    double? amount,
    String? status,
  }) {
    return Supporter(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      tier: tier ?? this.tier,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      amount: amount ?? this.amount,
      status: status ?? this.status,
    );
  }
}

class SupporterBenefit {
  final String id;
  final String outletId;
  final String benefitKey;
  final bool enabled;

  const SupporterBenefit({
    required this.id,
    required this.outletId,
    required this.benefitKey,
    this.enabled = true,
  });

  factory SupporterBenefit.fromJson(Map<String, dynamic> json) {
    return SupporterBenefit(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      benefitKey: json['benefit_key'] ?? '',
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'outlet_id': outletId,
      'benefit_key': benefitKey,
      'enabled': enabled,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'benefit_key': benefitKey,
      'enabled': enabled ? 1 : 0,
    };
  }

  factory SupporterBenefit.fromMap(Map<String, dynamic> map) {
    return SupporterBenefit(
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      benefitKey: map['benefit_key'] ?? '',
      enabled: map['enabled'] == 1 || map['enabled'] == true,
    );
  }

  SupporterBenefit copyWith({
    String? id,
    String? outletId,
    String? benefitKey,
    bool? enabled,
  }) {
    return SupporterBenefit(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      benefitKey: benefitKey ?? this.benefitKey,
      enabled: enabled ?? this.enabled,
    );
  }
}
