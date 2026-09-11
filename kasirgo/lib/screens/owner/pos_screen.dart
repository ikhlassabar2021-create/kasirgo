import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../models/transaction.dart';
import '../../widgets/pos/product_grid.dart';
import '../../widgets/pos/cart_panel.dart';
import '../../widgets/pos/checkout_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchController = TextEditingController();
  final List<TransactionItem> _cart = [];
  String _searchQuery = '';
  String? _selectedCategory;

  final List<Product> _products = [
    Product(id: '1', outletId: '1', name: 'Indomie Goreng', category: 'Makanan', price: 3500, stock: 50, unit: 'pcs'),
    Product(id: '2', outletId: '1', name: 'Teh Botol 250ml', category: 'Minuman', price: 4500, stock: 30, unit: 'pcs'),
    Product(id: '3', outletId: '1', name: 'Beras 1kg', category: 'Sembako', price: 12000, stock: 20, unit: 'kg'),
    Product(id: '4', outletId: '1', name: 'Minyak Goreng 1L', category: 'Sembako', price: 18000, stock: 15, unit: 'pcs'),
    Product(id: '5', outletId: '1', name: 'Gula Pasir 1kg', category: 'Sembako', price: 14000, stock: 25, unit: 'kg'),
    Product(id: '6', outletId: '1', name: 'Kopi Sachet', category: 'Minuman', price: 2500, stock: 100, unit: 'pcs'),
    Product(id: '7', outletId: '1', name: 'Rokok Sampoerna', category: 'Rokok', price: 28000, stock: 40, unit: 'pcs'),
    Product(id: '8', outletId: '1', name: 'Sabun Mandi', category: 'Kebersihan', price: 5000, stock: 60, unit: 'pcs'),
    Product(id: '9', outletId: '1', name: 'Telur 1 butir', category: 'Sembako', price: 2500, stock: 100, unit: 'pcs'),
    Product(id: '10', outletId: '1', name: 'Aqua 600ml', category: 'Minuman', price: 3000, stock: 80, unit: 'pcs'),
  ];

  List<Product> get _filteredProducts {
    var filtered = _products;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }

    return filtered;
  }

  List<String> get _productCategories => _products.map((p) => p.category!).toSet().toList();

  double get _total => _cart.fold(0, (sum, item) => sum + item.subtotal);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addToCart(Product product) {
    setState(() {
      final existingIndex = _cart.indexWhere((item) => item.productId == product.id);
      if (existingIndex >= 0) {
        final existing = _cart[existingIndex];
        _cart[existingIndex] = existing.copyWith(
          quantity: existing.quantity + 1,
          subtotal: existing.price * (existing.quantity + 1),
        );
      } else {
        _cart.add(TransactionItem(
          productId: product.id,
          productName: product.name,
          price: product.price,
          quantity: 1,
          subtotal: product.price,
        ));
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _cart.removeAt(index));
  }

  void _updateQty(MapEntry<String, int> entry) {
    setState(() {
      final index = _cart.indexWhere((item) => item.productId == entry.key);
      if (index >= 0) {
        _cart[index] = _cart[index].copyWith(
          quantity: entry.value,
          subtotal: _cart[index].price * entry.value,
        );
      }
    });
  }

  void _showCheckout() {
    showDialog(
      context: context,
      builder: (context) => CheckoutDialog(
        items: _cart,
        totalAmount: _total,
        onConfirm: ({required paymentMethod, notes, required finalAmount, customerId}) {
          setState(() => _cart.clear());
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(
              content: Text('Transaksi berhasil'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir / POS'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Cari produk...',
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _productCategories.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isAll = _selectedCategory == null;
                  return FilterChip(
                    label: const Text('Semua'),
                    selected: isAll,
                    onSelected: (_) => setState(() => _selectedCategory = null),
                    selectedColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(
                      color: isAll ? Colors.white : AppTheme.textPrimary,
                      fontSize: 12,
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }
                final cat = _productCategories[index - 1];
                final isSelected = _selectedCategory == cat;
                return FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  selectedColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                    fontSize: 12,
                  ),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          Expanded(
            child: ProductGrid(
              products: _filteredProducts,
              onTap: _addToCart,
            ),
          ),
          CartPanel(
            items: _cart,
            onCheckout: _showCheckout,
            onRemoveItem: _removeItem,
            onUpdateQty: _updateQty,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          final routes = ['/owner', '/owner/products', '/owner/pos', '/owner/reports', '/owner/settings'];
          if (index != 2) Navigator.pushReplacementNamed(context, routes[index]);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Produk'),
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Kasir'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Laporan'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Atur'),
        ],
      ),
    );
  }
}