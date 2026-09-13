class Product {
  final String id;
  final String outletId;
  final String name;
  final String? category;
  final double price;
  final double? costPrice;
  final int stock;
  final String? unit;
  final String? barcode;
  final String? imageLocalPath;
  final String? thumbKey;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Product({
    required this.id,
    required this.outletId,
    required this.name,
    this.category,
    required this.price,
    this.costPrice,
    this.stock = 0,
    this.unit,
    this.barcode,
    this.imageLocalPath,
    this.thumbKey,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] ?? '').toString(),
      outletId: (json['outlet_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      category: json['category']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (json['cost_price'] as num?)?.toDouble(),
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      unit: json['unit']?.toString(),
      barcode: json['barcode']?.toString(),
      imageLocalPath: json['image_local_path']?.toString(),
      thumbKey: json['thumb_key']?.toString(),
      isActive: json['is_active'] == null ? true : (json['is_active'] == true || json['is_active'] == 1),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final data = <String, dynamic>{
      'outlet_id': outletId,
      'name': name,
      'category': category,
      'price': price,
      'cost_price': costPrice,
      'stock': stock,
      'unit': unit,
      'barcode': barcode,
      'image_local_path': imageLocalPath,
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
      'price': price,
      'cost_price': costPrice,
      'stock': stock,
      'unit': unit,
      'barcode': barcode,
      'image_local_path': imageLocalPath,
      'thumb_key': thumbKey,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: (map['id'] ?? '').toString(),
      outletId: (map['outlet_id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      category: map['category']?.toString(),
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['cost_price'] as num?)?.toDouble(),
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      unit: map['unit']?.toString(),
      barcode: map['barcode']?.toString(),
      imageLocalPath: map['image_local_path']?.toString(),
      thumbKey: map['thumb_key']?.toString(),
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Product copyWith({
    String? id,
    String? outletId,
    String? name,
    String? category,
    double? price,
    double? costPrice,
    int? stock,
    String? unit,
    String? barcode,
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
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      barcode: barcode ?? this.barcode,
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
