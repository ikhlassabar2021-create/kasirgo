class Recipe {
  final String id;
  final String outletId;
  final String productId;
  final double yieldQty;
  final List<RecipeItem> items;

  const Recipe({
    required this.id,
    required this.outletId,
    required this.productId,
    this.yieldQty = 1,
    this.items = const [],
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    List<RecipeItem> items = [];
    if (json['recipe_items'] != null && json['recipe_items'] is List) {
      items = (json['recipe_items'] as List)
          .map((i) => RecipeItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } else if (json['items'] != null && json['items'] is List) {
      items = (json['items'] as List)
          .map((i) => RecipeItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    return Recipe(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      productId: json['product_id'] ?? '',
      yieldQty: (json['yield_qty'] ?? 1).toDouble(),
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'outlet_id': outletId,
      'product_id': productId,
      'yield_qty': yieldQty,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'product_id': productId,
      'yield_qty': yieldQty,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      productId: map['product_id'] ?? '',
      yieldQty: (map['yield_qty'] ?? 1).toDouble(),
    );
  }

  Recipe copyWith({
    String? id,
    String? outletId,
    String? productId,
    double? yieldQty,
    List<RecipeItem>? items,
  }) {
    return Recipe(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      productId: productId ?? this.productId,
      yieldQty: yieldQty ?? this.yieldQty,
      items: items ?? this.items,
    );
  }
}

class RecipeItem {
  final String id;
  final String recipeId;
  final String? ingredientProductId;
  final double qty;

  const RecipeItem({
    required this.id,
    required this.recipeId,
    this.ingredientProductId,
    required this.qty,
  });

  factory RecipeItem.fromJson(Map<String, dynamic> json) {
    return RecipeItem(
      id: json['id'] ?? '',
      recipeId: json['recipe_id'] ?? '',
      ingredientProductId: json['ingredient_product_id']?.toString(),
      qty: (json['qty'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'recipe_id': recipeId,
      'ingredient_product_id': ingredientProductId,
      'qty': qty,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipe_id': recipeId,
      'ingredient_product_id': ingredientProductId,
      'qty': qty,
    };
  }

  factory RecipeItem.fromMap(Map<String, dynamic> map) {
    return RecipeItem(
      id: map['id'] ?? '',
      recipeId: map['recipe_id'] ?? '',
      ingredientProductId: map['ingredient_product_id']?.toString(),
      qty: (map['qty'] ?? 0).toDouble(),
    );
  }

  RecipeItem copyWith({
    String? id,
    String? recipeId,
    String? ingredientProductId,
    double? qty,
  }) {
    return RecipeItem(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      ingredientProductId: ingredientProductId ?? this.ingredientProductId,
      qty: qty ?? this.qty,
    );
  }
}
