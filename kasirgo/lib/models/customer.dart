class Customer {
  final String id;
  final String outletId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final int? totalTransactions;
  final double? totalSpent;
  final DateTime? lastVisit;
  final DateTime? createdAt;

  const Customer({
    required this.id,
    required this.outletId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.totalTransactions,
    this.totalSpent,
    this.lastVisit,
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      totalTransactions: json['total_transactions'],
      totalSpent: json['total_spent']?.toDouble(),
      lastVisit: json['last_visit'] != null
          ? DateTime.parse(json['last_visit'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'total_transactions': totalTransactions,
      'total_spent': totalSpent,
      'last_visit': lastVisit?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'total_transactions': totalTransactions,
      'total_spent': totalSpent,
      'last_visit': lastVisit?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      totalTransactions: map['total_transactions'],
      totalSpent: map['total_spent']?.toDouble(),
      lastVisit: map['last_visit'] != null
          ? DateTime.parse(map['last_visit'])
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }

  Customer copyWith({
    String? id,
    String? outletId,
    String? name,
    String? phone,
    String? email,
    String? address,
    int? totalTransactions,
    double? totalSpent,
    DateTime? lastVisit,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalSpent: totalSpent ?? this.totalSpent,
      lastVisit: lastVisit ?? this.lastVisit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}