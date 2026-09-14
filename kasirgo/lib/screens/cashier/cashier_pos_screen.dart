import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../models/transaction.dart';
import '../../services/supabase_service.dart';
import '../owner/product_list_screen.dart';
import '../../widgets/pos/product_grid.dart';
import '../../widgets/pos/cart_panel.dart';
import '../../widgets/pos/checkout_dialog.dart';

class CashierPosScreen extends ConsumerStatefulWidget {
  const CashierPosScreen({super.key});

  @override
  ConsumerState<CashierPosScreen> createState() => _CashierPosScreenState();
}

class _CashierPosScreenState extends ConsumerState<CashierPosScreen> {
  final _searchController = TextEditingController();
  final List<TransactionItem> _cart = [];
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addToCart(Product product) {
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stok produk habis'), backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    setState(() {
      final index = _cart.indexWhere((item) => item.productId == product.id);
      if (index >= 0) {
        final currentQty = _cart[index].quantity;
        if (currentQty >= product.stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Maksimal stok tercapai (${product.stock})'), backgroundColor: AppTheme.errorColor),
          );
          return;
        }
        _cart[index] = _cart[index].copyWith(
          quantity: currentQty + 1,
          subtotal: product.price * (currentQty + 1),
        );
      } else {
        _cart.add(
          TransactionItem(
            productId: product.id,
            productName: product.name,
            price: product.price,
            quantity: 1,
            subtotal: product.price,
          ),
        );
      }
    });
  }

  void _updateQty(MapEntry<String, int> entry, List<Product> products) {
    setState(() {
      final index = _cart.indexWhere((item) => item.productId == entry.key);
      if (index >= 0) {
        final productIndex = products.indexWhere((p) => p.id == entry.key);
        final maxStock = productIndex >= 0 ? products[productIndex].stock : 9999;
        final targetQty = entry.value.clamp(1, maxStock);
        _cart[index] = _cart[index].copyWith(
          quantity: targetQty,
          subtotal: _cart[index].price * targetQty,
        );
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  double get _total => _cart.fold(0.0, (sum, item) => sum + item.subtotal);

  Future<void> _handleCheckout(List<Product> products) async {
    if (_cart.isEmpty) return;

    final result = await showDialog<CheckoutResult>(
      context: context,
      builder: (ctx) => CheckoutDialog(
        items: List.from(_cart),
        totalAmount: _total,
      ),
    );

    if (result == null) return;

    setState(() => _isLoading = true);

    try {
      final user = SupabaseService().currentUser;
      final outletId = user?.id != null ? await SupabaseService().getOutletIdForUser(user!.id) : null;
      if (outletId == null) {
        throw Exception('Outlet ID tidak ditemukan');
      }

      final notes = 'Channel: Toko Fisik (Kasir)${result.notes != null ? ' | ${result.notes}' : ''}';
      final tx = Transaction(
        id: '',
        outletId: outletId,
        cashierId: user?.id,
        items: List.from(_cart),
        totalAmount: _total,
        finalAmount: result.amount,
        paymentMethod: result.paymentMethod,
        paymentStatus: 'paid',
        notes: notes,
        isSynced: true,
        createdAt: DateTime.now(),
      );

      final created = await SupabaseService().createTransaction(tx);
      if (created == null) {
        throw Exception('Gagal menyimpan transaksi');
      }

      for (final item in _cart) {
        final prodIdx = products.indexWhere((p) => p.id == item.productId);
        if (prodIdx >= 0) {
          final prod = products[prodIdx];
          final newStock = (prod.stock - item.quantity).clamp(0, 999999);
          await SupabaseService().updateProduct(prod.copyWith(stock: newStock));
        }
      }

      ref.invalidate(productsProvider);

      if (mounted) {
        setState(() {
          _cart.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.change > 0
                  ? 'Transaksi berhasil! Kembalian: Rp ${result.change.toStringAsFixed(0)}'
                  : 'Transaksi berhasil!',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir POS'),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Gagal memuat produk: $err', style: const TextStyle(color: AppTheme.errorColor)),
        ),
        data: (products) {
          final filtered = products.where((p) {
            final matchSearch = _searchQuery.isEmpty ||
                p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (p.barcode != null && p.barcode!.contains(_searchQuery));
            return matchSearch;
          }).toList();

          return Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Cari produk / barcode...',
                        prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ProductGrid(
                      products: filtered,
                      onProductTap: _addToCart,
                    ),
                  ),
                ],
              ),
              CartPanel(
                items: _cart,
                onCheckout: () => _handleCheckout(products),
                onRemoveItem: _removeItem,
                onUpdateQty: (entry) => _updateQty(entry, products),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black45,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}
