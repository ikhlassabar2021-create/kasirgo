class Outlet {
  final String id;
  final String ownerId;
  final String businessName;
  final String? businessType;
  final String? address;
  final String? phone;
  final String? subscriptionTier;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Outlet({
    required this.id,
    required this.ownerId,
    required this.businessName,
    this.businessType,
    this.address,
    this.phone,
    this.subscriptionTier,
    this.createdAt,
    this.updatedAt,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      id: json['id'] ?? '',
      ownerId: json['owner_id'] ?? '',
      businessName: json['business_name'] ?? '',
      businessType: json['business_type'],
      address: json['address'],
      phone: json['phone'],
      subscriptionTier: json['subscription_tier'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'business_name': businessName,
      'business_type': businessType,
      'address': address,
      'phone': phone,
      'subscription_tier': subscriptionTier,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'business_name': businessName,
      'business_type': businessType,
      'address': address,
      'phone': phone,
      'subscription_tier': subscriptionTier,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Outlet.fromMap(Map<String, dynamic> map) {
    return Outlet(
      id: map['id'] ?? '',
      ownerId: map['owner_id'] ?? '',
      businessName: map['business_name'] ?? '',
      businessType: map['business_type'],
      address: map['address'],
      phone: map['phone'],
      subscriptionTier: map['subscription_tier'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }

  Outlet copyWith({
    String? id,
    String? ownerId,
    String? businessName,
    String? businessType,
    String? address,
    String? phone,
    String? subscriptionTier,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Outlet(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      businessName: businessName ?? this.businessName,
      businessType: businessType ?? this.businessType,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}