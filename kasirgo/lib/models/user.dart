class AppUser {
  final String id;
  final String email;
  final String? businessName;
  final String? businessType;
  final String? role; // owner, admin, cashier
  final String? outletId;
  final DateTime? createdAt;

  AppUser({required this.id, required this.email, this.businessName, this.businessType, this.role, this.outletId, this.createdAt});

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      businessName: json['business_name'] ?? json['user_metadata']?['business_name'],
      businessType: json['business_type'] ?? json['user_metadata']?['business_type'],
      role: json['role'],
      outletId: json['outlet_id'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'business_name': businessName, 'business_type': businessType, 'role': role, 'outlet_id': outletId};

  Map<String, dynamic> toMap() => toJson();
  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser.fromJson(map);
}