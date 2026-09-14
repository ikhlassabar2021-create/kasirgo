import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/pos/product_grid.dart';
import '../../widgets/pos/cart_panel.dart';
import '../../widgets/pos/checkout_dialog.dart';
import 'product_list_screen.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  final List<TransactionItem> _cart = [];
  String _searchQuery = '';
  String? _selectedCategory;
  String _selectedChannel = 'Toko Fisik';
  double _discountAmount = 0.0;

  final _channels = [
    'Toko Fisik',
    'WhatsApp',
    'Tokopedia',
    'Shopee',
    'TikTok Shop',
    'GoFood',
    'GrabFood',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + item.subtotal);

  void _addToCart(Product product) {
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok "${product.name}" habis'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      final existingIndex = _cart.indexWhere((item) => item.productId == product.id);
      if (existingIndex >= 0) {
        final existing = _cart[existingIndex];
        if (existing.quantity >= product.stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maksimal stok tercapai (${product.stock} ${product.unit ?? "pcs"})'),
              backgroundColor: AppTheme.warningColor,
              duration: const Duration(seconds: 1),
            ),
          );
          return;
        }
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

  void _updateQty(MapEntry<String, int> entry, List<Product> allProducts) {
    setState(() {
      final index = _cart.indexWhere((item) => item.productId == entry.key);
      if (index >= 0) {
        final product = allProducts.firstWhere(
          (p) => p.id == entry.key,
          orElse: () => Product(id: '', outletId: '', name: '', price: 0),
        );

        int newQty = entry.value;
        if (product.id.isNotEmpty && newQty > product.stock) {
          newQty = product.stock;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stok hanya tersedia ${product.stock}'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }

        if (newQty <= 0) {
          _cart.removeAt(index);
        } else {
          _cart[index] = _cart[index].copyWith(
            quantity: newQty,
            subtotal: _cart[index].price * newQty,
          );
        }
      }
    });
  }

  void _openBarcodeScanner(List<Product> products) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          height: 400,
          child: Column(
            children: [
              AppBar(
                title: const Text('Scan Barcode Produk', style: TextStyle(fontSize: 16)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        final code = barcode.rawValue ?? barcode.displayValue;
                        if (code != null && code.isNotEmpty) {
                          Navigator.pop(dialogCtx);
                          _onBarcodeScanned(code, products);
                          break;
                        }
                      }
                    },
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Arahkan kamera ke barcode produk',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onBarcodeScanned(String code, List<Product> products) {
    final matched = products.where(
      (p) => p.barcode != null && p.barcode!.trim() == code.trim(),
    ).toList();

    if (matched.isNotEmpty) {
      _addToCart(matched.first);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${matched.first.name} dimasukkan ke keranjang'),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      setState(() {
        _searchController.text = code;
        _searchQuery = code.toLowerCase();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode "$code" tidak cocok dengan produk terdaftar'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showCheckout() {
    if (_cart.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => CheckoutDialog(
        items: _cart,
        totalAmount: _subtotal,
        discountAmount: _discountAmount,
        onConfirm: ({
          required String paymentMethod,
          required String? notes,
          required double finalAmount,
          required String? customerId,
        }) async {
          final user = ref.read(currentUserProvider);
          final outletId = user?.outletId;
          if (outletId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Outlet ID tidak valid'), backgroundColor: AppTheme.errorColor),
            );
            return;
          }

          final fullNotes = 'Channel: $_selectedChannel${notes != null && notes.isNotEmpty ? " | $notes" : ""}';
          final tx = Transaction(
            id: '',
            outletId: outletId,
            cashierId: user?.id,
            customerId: customerId,
            items: List.from(_cart),
            totalAmount: _subtotal,
            discountAmount: _discountAmount > 0 ? _discountAmount : null,
            finalAmount: finalAmount,
            paymentMethod: paymentMethod,
            paymentStatus: 'paid',
            notes: fullNotes,
            isSynced: true,
            createdAt: DateTime.now(),
          );

          final result = await SupabaseService().createTransaction(tx);
          if (mounted) {
            if (result != null) {
              setState(() {
                _cart.clear();
                _discountAmount = 0.0;
              });
              ref.invalidate(productsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaksi POS berhasil disimpan!'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gagal menyimpan transaksi ke database'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir / POS'),
        actions: [
          // Channel selector
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedChannel,
                dropdownColor: AppTheme.surfaceColor,
                icon: const Icon(Icons.arrow_drop_down, color: AppTheme.accentColor, size: 20),
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                items: _channels.map((ch) {
                  return DropdownMenuItem(value: ch, child: Text(ch));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedChannel = val);
                },
              ),
            ),
          ),
        ],
      ),
      body: productsAsync.when(
        data: (allProducts) {
          var filtered = allProducts;
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            filtered = filtered.where((p) {
              final nameMatch = p.name.toLowerCase().contains(query);
              final barcodeMatch = p.barcode != null && p.barcode!.toLowerCase().contains(query);
              return nameMatch || barcodeMatch;
            }).toList();
          }

          if (_selectedCategory != null) {
            filtered = filtered.where((p) => p.category == _selectedCategory).toList();
          }

          final categories = allProducts
              .map((p) => p.category)
              .whereType<String>()
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList();

          return Column(
            children: [
              // Search & Barcode Scan Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Cari nama produk / barcode...',
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
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => _openBarcodeScanner(allProducts),
                      tooltip: 'Scan Barcode',
                      icon: const Icon(Icons.qr_code_scanner),
                    ),
                  ],
                ),
              ),

              // Category Filter Chips
              if (categories.isNotEmpty)
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: categories.length + 1,
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
                      final cat = categories[index - 1];
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

              const SizedBox(height: 6),

              // Product Grid
              Expanded(
                child: ProductGrid(
                  products: filtered,
                  onTap: _addToCart,
                ),
              ),

              // Cart Panel
              CartPanel(
                items: _cart,
                discountAmount: _discountAmount,
                onUpdateDiscount: (disc) => setState(() => _discountAmount = disc),
                onCheckout: _showCheckout,
                onRemoveItem: _removeItem,
                onUpdateQty: (entry) => _updateQty(entry, allProducts),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text('Gagal memuat produk: $err', style: const TextStyle(color: AppTheme.errorColor)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(productsProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          final routes = ['/owner', '/owner/products', '/owner/pos', '/owner/reports', '/owner/settings'];
          if (index != 2) context.pushReplacement(routes[index]);
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
