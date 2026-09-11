class User {
  final String id;
  final String email;
  final String? name;
  final String role;
  final String? outletId;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.email,
    this.name,
    required this.role,
    this.outletId,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'],
      role: json['role'] ?? 'cashier',
      outletId: json['outlet_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'outlet_id': outletId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'outlet_id': outletId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'],
      role: map['role'] ?? 'cashier',
      outletId: map['outlet_id'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? outletId,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      outletId: outletId ?? this.outletId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}