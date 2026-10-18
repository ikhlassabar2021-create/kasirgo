import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart.dart';

/// ST17-5 (Phase 17 - Ekosistem Hyper-Local): keranjang Pembeli (in-memory).
///
/// Satu toko per transaksi: menambah produk dari outlet lain akan mengganti
/// isi keranjang. `add` mengembalikan `true` bila keranjang diganti.
class CartNotifier extends StateNotifier<Cart> {
  CartNotifier() : super(Cart.empty);

  bool add({
    required String outletId,
    required String outletName,
    required CartItem item,
    bool hasDelivery = false,
  }) {
    var replaced = false;
    if (state.outletId.isNotEmpty && state.outletId != outletId) {
      state = Cart(
        outletId: outletId,
        outletName: outletName,
        items: [item],
        hasDelivery: hasDelivery,
      );
      return true;
    }

    final items = List<CartItem>.from(state.items);
    final idx = items.indexWhere((e) => e.productId == item.productId);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(qty: items[idx].qty + item.qty);
    } else {
      items.add(item);
    }
    state = Cart(
      outletId: outletId,
      outletName: outletName,
      items: items,
      hasDelivery: hasDelivery || state.hasDelivery,
    );
    return replaced;
  }

  void setQty(String productId, int qty) {
    if (qty <= 0) {
      remove(productId);
      return;
    }
    final items = List<CartItem>.from(state.items);
    final idx = items.indexWhere((e) => e.productId == productId);
    if (idx < 0) return;
    items[idx] = items[idx].copyWith(qty: qty);
    state = Cart(
      outletId: state.outletId,
      outletName: state.outletName,
      items: items,
      hasDelivery: state.hasDelivery,
    );
  }

  void increment(String productId) {
    setQty(productId, state.qtyOf(productId) + 1);
  }

  void decrement(String productId) {
    setQty(productId, state.qtyOf(productId) - 1);
  }

  void remove(String productId) {
    final items =
        state.items.where((e) => e.productId != productId).toList();
    if (items.isEmpty) {
      state = Cart.empty;
      return;
    }
    state = Cart(
      outletId: state.outletId,
      outletName: state.outletName,
      items: items,
      hasDelivery: state.hasDelivery,
    );
  }

  void clear() => state = Cart.empty;
}

final cartProvider =
    StateNotifierProvider<CartNotifier, Cart>((ref) => CartNotifier());
