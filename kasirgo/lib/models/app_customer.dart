/// ST17-1 (Phase 17 - Ekosistem Hyper-Local): identitas Pembeli.
/// Dibuat otomatis via anonymous auth + RPC submit_order.
class AppCustomer {
  final String id;
  final String? authUid;
  final String? phone;
  final String? name;
  final String? deviceUuid;
  final DateTime? createdAt;
  final DateTime? lastSeen;

  const AppCustomer({
    required this.id,
    this.authUid,
    this.phone,
    this.name,
    this.deviceUuid,
    this.createdAt,
    this.lastSeen,
  });

  factory AppCustomer.fromJson(Map<String, dynamic> json) {
    return AppCustomer(
      id: json['id']?.toString() ?? '',
      authUid: json['auth_uid']?.toString(),
      phone: json['phone']?.toString(),
      name: json['name']?.toString(),
      deviceUuid: json['device_uuid']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_uid': authUid,
      'phone': phone,
      'name': name,
      'device_uuid': deviceUuid,
      'created_at': createdAt?.toIso8601String(),
      'last_seen': lastSeen?.toIso8601String(),
    };
  }

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name! : 'Pembeli';
}
