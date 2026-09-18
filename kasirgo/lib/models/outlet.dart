class Outlet {
  final String id;
  final String ownerId;
  final String businessName;
  final String? businessType;
  final String? outletType;
  final String? address;
  final String? phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Outlet({
    required this.id,
    required this.ownerId,
    required this.businessName,
    this.businessType,
    this.outletType,
    this.address,
    this.phone,
    this.createdAt,
    this.updatedAt,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      id: json['id'] ?? '',
      ownerId: json['owner_id'] ?? '',
      businessName: json['business_name'] ?? '',
      businessType: json['business_type'],
      outletType: json['outlet_type'] ?? json['type'],
      address: json['address'],
      phone: json['phone'],
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
      'outlet_type': outletType,
      'address': address,
      'phone': phone,
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
      'outlet_type': outletType,
      'address': address,
      'phone': phone,
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
      outletType: map['outlet_type'] ?? map['type'],
      address: map['address'],
      phone: map['phone'],
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
    String? outletType,
    String? address,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Outlet(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      businessName: businessName ?? this.businessName,
      businessType: businessType ?? this.businessType,
      outletType: outletType ?? this.outletType,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
