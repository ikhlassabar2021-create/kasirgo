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
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'],
      price: (json['price'] ?? 0).toDouble(),
      costPrice: json['cost_price']?.toDouble(),
      stock: json['stock'] ?? 0,
      unit: json['unit'],
      barcode: json['barcode'],
      imageLocalPath: json['image_local_path'],
      thumbKey: json['thumb_key'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
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
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
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
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'],
      price: (map['price'] ?? 0).toDouble(),
      costPrice: map['cost_price']?.toDouble(),
      stock: map['stock'] ?? 0,
      unit: map['unit'],
      barcode: map['barcode'],
      imageLocalPath: map['image_local_path'],
      thumbKey: map['thumb_key'],
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
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
}