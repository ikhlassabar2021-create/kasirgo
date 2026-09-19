import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../models/transaction.dart';
import '../../services/supabase_service.dart';
import '../owner/product_list_screen.dart';
import '../../widgets/pos/product_grid.dart';
import '../../widgets/pos/cart_panel.dart';
import '../../widgets/pos/checkout_dialog.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  final List<TransactionItem> _cart = [];
  String _searchQuery = '';
  String _selectedChannel = 'Toko Fisik';
  double _discountAmount = 0.0;
  bool _isLoading = false;
  Map<String, Map<String, double>> _channelPrices = {};
  Map<String, Map<String, dynamic>> _activeDiscounts = {};

  final List<String> _channels = [
    'Toko Fisik',
    'WhatsApp',
    'Tokopedia',
    'Shopee',
    'GrabFood',
    'GoFood',
  ];

  @override
  void initState() {
    super.initState();
    _loadPricingAndDiscounts();
  }

  Future<void> _loadPricingAndDiscounts() async {
    try {
      final client = sb.Supabase.instance.client;
      final pricesRes = await client.from('product_prices').select('product_id, channel, price');
      final discountsRes = await client.from('product_discounts').select(
        'product_id, discount_percent, discount_amount, start_date, end_date, is_flash_sale'
      );

      final newChannelPrices = <String, Map<String, double>>{};
      for (final row in pricesRes as List) {
        final pId = row['product_id'] as String;
        final ch = row['channel'] as String;
        final pr = (row['price'] as num).toDouble();
        newChannelPrices.putIfAbsent(pId, () => {})[ch] = pr;
      }

      final now = DateTime.now();
      final newDiscounts = <String, Map<String, dynamic>>{};
      for (final row in discountsRes as List) {
        final pId = row['product_id'] as String;
        final start = row['start_date'] != null ? DateTime.tryParse(row['start_date']) : null;
        final end = row['end_date'] != null ? DateTime.tryParse(row['end_date']) : null;

        final isStarted = start == null || now.isAfter(start);
        final isNotExpired = end == null || now.isBefore(end);

        if (isStarted && isNotExpired) {
          newDiscounts[pId] = row as Map<String, dynamic>;
        }
      }

      if (mounted) {
        setState(() {
          _channelPrices = newChannelPrices;
          _activeDiscounts = newDiscounts;
        });
      }
    } catch (_) {}
  }

  String _normalizeChannel(String displayChannel) {
    switch (displayChannel) {
      case 'Toko Fisik':
        return 'offline';
      case 'WhatsApp':
        return 'whatsapp';
      case 'Tokopedia':
        return 'tokopedia';
      case 'Shopee':
        return 'shopee';
      case 'GrabFood':
        return 'grabfood';
      case 'GoFood':
        return 'gofood';
      default:
        return displayChannel.toLowerCase();
    }
  }

  double _getProductBasePrice(Product product) {
    final normChannel = _normalizeChannel(_selectedChannel);
    if (normChannel != 'offline') {
      final chPrice = _channelPrices[product.id]?[normChannel];
      if (chPrice != null && chPrice > 0) return chPrice;
    }
    return product.price;
  }

  double _getProductEffectivePrice(Product product) {
    final basePrice = _getProductBasePrice(product);
    final disc = _activeDiscounts[product.id];
    if (disc == null) return basePrice;

    final pct = (disc['discount_percent'] as num?)?.toDouble() ?? 0.0;
    final amt = (disc['discount_amount'] as num?)?.toDouble() ?? 0.0;

    if (pct > 0) {
      return (basePrice * (1 - (pct / 100))).clamp(0, double.infinity);
    } else if (amt > 0) {
      return (basePrice - amt).clamp(0, double.infinity);
    }
    return basePrice;
  }

  String? _getDiscountBadge(Product product) {
    final disc = _activeDiscounts[product.id];
    if (disc == null) return null;

    final isFlash = disc['is_flash_sale'] as bool? ?? false;
    final pct = (disc['discount_percent'] as num?)?.toDouble() ?? 0.0;
    final amt = (disc['discount_amount'] as num?)?.toDouble() ?? 0.0;

    if (isFlash) return 'FLASH SALE';
    if (pct > 0) return '-${pct.toStringAsFixed(0)}%';
    if (amt > 0) return '-Rp${(amt / 1000).toStringAsFixed(0)}k';
    return null;
  }

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

    final effectivePrice = _getProductEffectivePrice(product);

    int newQty = 1;
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
        newQty = currentQty + 1;
        _cart[index] = _cart[index].copyWith(
          quantity: newQty,
          subtotal: effectivePrice * newQty,
        );
      } else {
        newQty = 1;
        _cart.add(
          TransactionItem(
            productId: product.id,
            productName: product.name,
            price: effectivePrice,
            quantity: 1,
            subtotal: effectivePrice,
          ),
        );
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} masuk keranjang ($newQty)'),
        duration: const Duration(milliseconds: 700),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + item.subtotal);
  double get _total => (_subtotal - _discountAmount).clamp(0.0, double.infinity);

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
      final client = sb.Supabase.instance.client;
      final user = client.auth.currentUser;
      final outletId = products.isNotEmpty ? products.first.outletId : null;
      if (outletId == null) {
        throw Exception('Outlet ID tidak ditemukan');
      }

      final channel = _selectedChannel == 'Toko Fisik'
          ? 'offline'
          : _selectedChannel.toLowerCase();
      final tx = Transaction(
        id: '',
        outletId: outletId,
        cashierId: user?.id,
        items: List.from(_cart),
        totalAmount: _subtotal,
        discountAmount: _discountAmount > 0 ? _discountAmount : null,
        finalAmount: result.amount,
        paymentMethod: result.paymentMethod,
        paymentStatus: 'paid',
        notes: result.notes,
        isSynced: true,
        channel: channel,
        createdAt: DateTime.now(),
      );

      final created = await SupabaseService().createTransaction(tx);
      if (created == null) {
        throw Exception('Gagal menyimpan transaksi');
      }

      ref.invalidate(productsProvider);

      if (mounted) {
        setState(() {
          _cart.clear();
          _discountAmount = 0.0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.change > 0
                  ? 'Transaksi sukses! Kembalian: Rp ${result.change.toStringAsFixed(0)}'
                  : 'Transaksi sukses!',
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
        title: const Text('Kasir POS (Owner)'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedChannel,
              dropdownColor: AppTheme.surfaceColor,
              icon: const Icon(Icons.arrow_drop_down, color: AppTheme.accentColor),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
              items: _channels.map((ch) {
                return DropdownMenuItem(
                  value: ch,
                  child: Text(ch),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedChannel = val);
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
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
                      cartQuantities: {
                        for (final item in _cart) item.productId: item.quantity,
                      },
                      customPrices: {
                        for (final p in filtered) p.id: _getProductEffectivePrice(p),
                      },
                      originalPrices: {
                        for (final p in filtered) p.id: _getProductBasePrice(p),
                      },
                      discountBadges: {
                        for (final p in filtered)
                          if (_getDiscountBadge(p) != null) p.id: _getDiscountBadge(p)!,
                      },
                    ),
                  ),
                ],
              ),
              CartPanel(
                items: _cart,
                discountAmount: _discountAmount,
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
