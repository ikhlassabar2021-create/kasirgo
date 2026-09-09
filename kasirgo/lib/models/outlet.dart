class Outlet {
  final String id;
  final String ownerId;
  final String name;
  final String type;
  final String? address;
  final String? phone;
  final String subscriptionTier;
  final DateTime? subscriptionExpiry;
  final DateTime? createdAt;

  Outlet({required this.id, required this.ownerId, required this.name, this.type = 'warung', this.address, this.phone, this.subscriptionTier = 'free', this.subscriptionExpiry, this.createdAt});

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      id: json['id'] ?? '',
      ownerId: json['owner_id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'warung',
      address: json['address'],
      phone: json['phone'],
      subscriptionTier: json['subscription_tier'] ?? 'free',
      subscriptionExpiry: json['subscription_expiry'] != null ? DateTime.parse(json['subscription_expiry']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'owner_id': ownerId, 'name': name, 'type': type, 'address': address, 'phone': phone, 'subscription_tier': subscriptionTier};
  Map<String, dynamic> toMap() => toJson();
  factory Outlet.fromMap(Map<String, dynamic> map) => Outlet.fromJson(map);
}