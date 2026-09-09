class Customer {
  final String id;
  final String outletId;
  final String name;
  final String? phoneWa;
  final double totalSpent;
  final int loyaltyPoints;
  final DateTime? createdAt;

  Customer({required this.id, required this.outletId, required this.name, this.phoneWa, this.totalSpent = 0, this.loyaltyPoints = 0, this.createdAt});

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '', outletId: json['outlet_id'] ?? '', name: json['name'] ?? '',
      phoneWa: json['phone_wa'], totalSpent: (json['total_spent'] ?? 0).toDouble(),
      loyaltyPoints: json['loyalty_points'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'outlet_id': outletId, 'name': name, 'phone_wa': phoneWa, 'total_spent': totalSpent, 'loyalty_points': loyaltyPoints};
  Map<String, dynamic> toMap() => toJson();
  factory Customer.fromMap(Map<String, dynamic> map) => Customer.fromJson(map);
}