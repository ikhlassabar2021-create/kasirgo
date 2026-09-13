class Product {
  final String id;
  final String outletId;
  final String name;
  final String? category;
  final String? barcode;
  final double? costPrice;
  final double basePrice;
  final int stock;
  final String? unit;
  final DateTime? expiredDate;
  final String? imageLocalPath;
  final String? thumbKey;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get price => basePrice;

  const Product({
    required this.id,
    required this.outletId,
    required this.name,
    this.category,
    this.barcode,
    this.costPrice,
    double? basePrice,
    double? price,
    this.stock = 0,
    this.unit,
    this.expiredDate,
    this.imageLocalPath,
    this.thumbKey,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  }) : basePrice = basePrice ?? price ?? 0.0;

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['base_price'] ?? json['price'];
    final priceVal = (rawPrice as num?)?.toDouble() ?? 0.0;
    return Product(
      id: (json['id'] ?? '').toString(),
      outletId: (json['outlet_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      category: json['category']?.toString(),
      barcode: json['barcode']?.toString(),
      costPrice: (json['cost_price'] as num?)?.toDouble(),
      basePrice: priceVal,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      unit: json['unit']?.toString(),
      expiredDate: json['expired_date'] != null
          ? DateTime.tryParse(json['expired_date'].toString())
          : null,
      imageLocalPath: json['image_local_path']?.toString(),
      thumbKey: json['thumb_key']?.toString(),
      isActive: json['is_active'] == null
          ? true
          : (json['is_active'] == true || json['is_active'] == 1),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final data = <String, dynamic>{
      'outlet_id': outletId,
      'name': name,
      'category': category,
      'barcode': barcode,
      'cost_price': costPrice,
      'base_price': basePrice,
      'stock': stock,
      'unit': unit,
      'expired_date': expiredDate?.toIso8601String().split('T').first,
      'image_local_path': imageLocalPath ?? '',
      'thumb_key': thumbKey,
      'is_active': isActive,
    };
    if (includeId && id.isNotEmpty) {
      data['id'] = id;
    }
    if (createdAt != null) {
      data['created_at'] = createdAt!.toIso8601String();
    }
    if (updatedAt != null) {
      data['updated_at'] = updatedAt!.toIso8601String();
    }
    return data;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'name': name,
      'category': category,
      'barcode': barcode,
      'cost_price': costPrice,
      'base_price': basePrice,
      'price': basePrice,
      'stock': stock,
      'unit': unit,
      'expired_date': expiredDate?.toIso8601String(),
      'image_local_path': imageLocalPath ?? '',
      'thumb_key': thumbKey,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['base_price'] ?? map['price'];
    final priceVal = (rawPrice as num?)?.toDouble() ?? 0.0;
    return Product(
      id: (map['id'] ?? '').toString(),
      outletId: (map['outlet_id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      category: map['category']?.toString(),
      barcode: map['barcode']?.toString(),
      costPrice: (map['cost_price'] as num?)?.toDouble(),
      basePrice: priceVal,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      unit: map['unit']?.toString(),
      expiredDate: map['expired_date'] != null
          ? DateTime.tryParse(map['expired_date'].toString())
          : null,
      imageLocalPath: map['image_local_path']?.toString(),
      thumbKey: map['thumb_key']?.toString(),
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Product copyWith({
    String? id,
    String? outletId,
    String? name,
    String? category,
    String? barcode,
    double? costPrice,
    double? basePrice,
    double? price,
    int? stock,
    String? unit,
    DateTime? expiredDate,
    String? imageLocalPath,
    String? thumbKey,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      name: name ?? this.name,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
      costPrice: costPrice ?? this.costPrice,
      basePrice: basePrice ?? price ?? this.basePrice,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      expiredDate: expiredDate ?? this.expiredDate,
      imageLocalPath: imageLocalPath ?? this.imageLocalPath,
      thumbKey: thumbKey ?? this.thumbKey,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
