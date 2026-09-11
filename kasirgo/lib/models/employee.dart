class Employee {
  final String id;
  final String outletId;
  final String userId;
  final String name;
  final String role;
  final String? phone;
  final String? email;
  final String? pin;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Employee({
    required this.id,
    required this.outletId,
    required this.userId,
    required this.name,
    required this.role,
    this.phone,
    this.email,
    this.pin,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'cashier',
      phone: json['phone'],
      email: json['email'],
      pin: json['pin'],
      isActive: json['is_active'] ?? true,
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
      'outlet_id': outletId,
      'user_id': userId,
      'name': name,
      'role': role,
      'phone': phone,
      'email': email,
      'pin': pin,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'user_id': userId,
      'name': name,
      'role': role,
      'phone': phone,
      'email': email,
      'pin': pin,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      userId: map['user_id'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'cashier',
      phone: map['phone'],
      email: map['email'],
      pin: map['pin'],
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }

  Employee copyWith({
    String? id,
    String? outletId,
    String? userId,
    String? name,
    String? role,
    String? phone,
    String? email,
    String? pin,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Employee(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      pin: pin ?? this.pin,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}