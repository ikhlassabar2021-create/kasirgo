/// ST17-1 (Phase 17 - Ekosistem Hyper-Local): model siklus pesanan online.
/// Order terpisah dari transaksi; transaksi dibuat saat order selesai
/// (complete_order). Lihat migrasi 2026-10-31-kasirgo-17a-hyperlocal.sql.
class OrderItem {
  final String id;
  final String orderId;
  final String? productId;
  final String nameSnapshot;
  final double priceSnapshot;
  final double qty;
  final double lineTotal;

  const OrderItem({
    this.id = '',
    this.orderId = '',
    this.productId,
    required this.nameSnapshot,
    required this.priceSnapshot,
    required this.qty,
    required this.lineTotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      productId: json['product_id']?.toString(),
      nameSnapshot: json['name_snapshot']?.toString() ?? '',
      priceSnapshot: _toDouble(json['price_snapshot']),
      qty: _toDouble(json['qty']),
      lineTotal: _toDouble(json['line_total']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'product_id': productId,
      'name_snapshot': nameSnapshot,
      'price_snapshot': priceSnapshot,
      'qty': qty,
      'line_total': lineTotal,
    };
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class Order {
  final String id;
  final String outletId;
  final String? buyerId;
  final String? code;

  /// baru | diproses | siap | selesai | dibatalkan
  final String status;

  /// belum_konfirmasi | divalidasi | ditolak
  final String paymentStatus;

  /// pickup | delivery
  final String fulfillment;

  final double subtotal;
  final double deliveryFee;
  final double total;
  final double? distanceKm;
  final String? note;
  final String? buyerName;
  final String? buyerPhone;
  final double? buyerLat;
  final double? buyerLng;
  final String? buyerAddress;
  final String? proofPath;
  final String? validatedBy;
  final DateTime? validatedAt;
  final String? transactionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.outletId,
    this.buyerId,
    this.code,
    this.status = 'baru',
    this.paymentStatus = 'belum_konfirmasi',
    this.fulfillment = 'pickup',
    this.subtotal = 0,
    this.deliveryFee = 0,
    this.total = 0,
    this.distanceKm,
    this.note,
    this.buyerName,
    this.buyerPhone,
    this.buyerLat,
    this.buyerLng,
    this.buyerAddress,
    this.proofPath,
    this.validatedBy,
    this.validatedAt,
    this.transactionId,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    List<OrderItem> items = [];
    if (json['order_items'] != null && json['order_items'] is List) {
      items = (json['order_items'] as List)
          .map((i) => OrderItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList();
    }
    return Order(
      id: json['id']?.toString() ?? '',
      outletId: json['outlet_id']?.toString() ?? '',
      buyerId: json['buyer_id']?.toString(),
      code: json['code']?.toString(),
      status: json['status']?.toString() ?? 'baru',
      paymentStatus: json['payment_status']?.toString() ?? 'belum_konfirmasi',
      fulfillment: json['fulfillment']?.toString() ?? 'pickup',
      subtotal: OrderItem._toDouble(json['subtotal']),
      deliveryFee: OrderItem._toDouble(json['delivery_fee']),
      total: OrderItem._toDouble(json['total']),
      distanceKm: json['distance_km'] == null
          ? null
          : OrderItem._toDouble(json['distance_km']),
      note: json['note']?.toString(),
      buyerName: json['buyer_name']?.toString(),
      buyerPhone: json['buyer_phone']?.toString(),
      buyerLat: json['buyer_lat'] == null
          ? null
          : OrderItem._toDouble(json['buyer_lat']),
      buyerLng: json['buyer_lng'] == null
          ? null
          : OrderItem._toDouble(json['buyer_lng']),
      buyerAddress: json['buyer_address']?.toString(),
      proofPath: json['proof_path']?.toString(),
      validatedBy: json['validated_by']?.toString(),
      validatedAt: _toDate(json['validated_at']),
      transactionId: json['transaction_id']?.toString(),
      createdAt: _toDate(json['created_at']),
      updatedAt: _toDate(json['updated_at']),
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'buyer_id': buyerId,
      'code': code,
      'status': status,
      'payment_status': paymentStatus,
      'fulfillment': fulfillment,
      'subtotal': subtotal,
      'delivery_fee': deliveryFee,
      'total': total,
      'distance_km': distanceKm,
      'note': note,
      'buyer_name': buyerName,
      'buyer_phone': buyerPhone,
      'buyer_lat': buyerLat,
      'buyer_lng': buyerLng,
      'buyer_address': buyerAddress,
      'proof_path': proofPath,
      'validated_by': validatedBy,
      'validated_at': validatedAt?.toIso8601String(),
      'transaction_id': transactionId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  String get statusLabel {
    switch (status) {
      case 'baru':
        return 'Baru';
      case 'diproses':
        return 'Diproses';
      case 'siap':
        return 'Siap';
      case 'selesai':
        return 'Selesai';
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  bool get isPaid => paymentStatus == 'divalidasi';
  bool get isDelivery => fulfillment == 'delivery';

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
