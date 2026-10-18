/// ST17-5 (Phase 17 - Ekosistem Hyper-Local): model keranjang Pembeli.
///
/// Aturan produk: SATU toko per transaksi. Bila pembeli menambah produk dari
/// outlet berbeda, keranjang lama diganti (lihat `CartNotifier.add`).
class CartItem {
  final String productId;
  final String name;
  final double price;
  final String? unit;
  final int stock;
  final int qty;

  const CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.unit,
    this.stock = 0,
    this.qty = 1,
  });

  double get lineTotal => price * qty;

  CartItem copyWith({int? qty}) {
    return CartItem(
      productId: productId,
      name: name,
      price: price,
      unit: unit,
      stock: stock,
      qty: qty ?? this.qty,
    );
  }

  /// Payload item untuk `OrderService.submitOrder` (ST17-6).
  Map<String, dynamic> toOrderItem() {
    return {
      'product_id': productId,
      'name': name,
      'price': price,
      'qty': qty,
    };
  }
}

class Cart {
  final String outletId;
  final String outletName;
  final List<CartItem> items;

  /// Outlet tujuan menerima pengantaran (dari `nearby_outlets.has_delivery`).
  /// Disimpan di keranjang agar opsi "Diantar" tetap ada walau outlet yang
  /// dipilih sudah tidak aktif di layar.
  final bool hasDelivery;

  const Cart({
    required this.outletId,
    required this.outletName,
    required this.items,
    this.hasDelivery = false,
  });

  static const Cart empty = Cart(
    outletId: '',
    outletName: '',
    items: <CartItem>[],
    hasDelivery: false,
  );

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  int get itemCount => items.fold(0, (sum, e) => sum + e.qty);

  double get subtotal => items.fold(0.0, (sum, e) => sum + e.lineTotal);

  int qtyOf(String productId) {
    for (final e in items) {
      if (e.productId == productId) return e.qty;
    }
    return 0;
  }
}
