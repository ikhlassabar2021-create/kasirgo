/// ST17-1 (Phase 17 - Ekosistem Hyper-Local): model lokasi live & antrean jasa.
class OutletLocation {
  final String id;
  final String outletId;
  final double latitude;
  final double longitude;
  final DateTime? updatedAt;

  const OutletLocation({
    required this.id,
    required this.outletId,
    required this.latitude,
    required this.longitude,
    this.updatedAt,
  });

  factory OutletLocation.fromJson(Map<String, dynamic> json) {
    return OutletLocation(
      id: json['id']?.toString() ?? '',
      outletId: json['outlet_id']?.toString() ?? '',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'outlet_id': outletId,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class ServiceQueueEntry {
  final String id;
  final String outletId;
  final String? buyerId;
  final int number;

  /// menunggu | dipanggil | selesai | batal
  final String status;
  final DateTime? createdAt;

  const ServiceQueueEntry({
    required this.id,
    required this.outletId,
    this.buyerId,
    required this.number,
    this.status = 'menunggu',
    this.createdAt,
  });

  factory ServiceQueueEntry.fromJson(Map<String, dynamic> json) {
    return ServiceQueueEntry(
      id: json['id']?.toString() ?? '',
      outletId: json['outlet_id']?.toString() ?? '',
      buyerId: json['buyer_id']?.toString(),
      number: (json['number'] is num)
          ? (json['number'] as num).toInt()
          : int.tryParse(json['number']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? 'menunggu',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'outlet_id': outletId,
      'buyer_id': buyerId,
      'number': number,
      'status': status,
    };
  }
}

/// Hasil RPC `nearby_outlets` (data publik outlet terdekat).
class NearbyOutlet {
  final String id;
  final String name;
  final String? type;
  final String? address;
  final String? phone;
  final bool isOpen;
  final bool isMobile;
  final double? latitude;
  final double? longitude;
  final double distanceKm;
  final int queueCount;
  final bool hasDelivery;

  const NearbyOutlet({
    required this.id,
    required this.name,
    this.type,
    this.address,
    this.phone,
    this.isOpen = false,
    this.isMobile = false,
    this.latitude,
    this.longitude,
    this.distanceKm = 0,
    this.queueCount = 0,
    this.hasDelivery = false,
  });

  factory NearbyOutlet.fromJson(Map<String, dynamic> json) {
    return NearbyOutlet(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString(),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      isOpen: json['is_open'] == true,
      isMobile: json['is_mobile'] == true,
      latitude: json['latitude'] == null
          ? null
          : OutletLocation._toDouble(json['latitude']),
      longitude: json['longitude'] == null
          ? null
          : OutletLocation._toDouble(json['longitude']),
      distanceKm: OutletLocation._toDouble(json['distance_km']),
      queueCount: (json['queue_count'] is num)
          ? (json['queue_count'] as num).toInt()
          : 0,
      hasDelivery: json['has_delivery'] == true,
    );
  }

  String get distanceLabel {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}
