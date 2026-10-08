import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/common/centennial_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../models/transaction.dart';
import '../../models/tip.dart';
import '../../providers/auth_provider.dart';
import '../../services/offline_transaction_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/receipt_generator.dart';
import '../owner/product_list_screen.dart';
import '../../widgets/pos/product_grid.dart';
import '../../widgets/pos/cart_panel.dart';
import '../../widgets/pos/checkout_dialog.dart';
import '../../widgets/pos/checkout_success_dialog.dart';
import '../../widgets/common/logout_button.dart';
import 'incoming_orders_screen.dart';

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
  int _incomingCount = 0;
  sb.RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initOrders());
  }

  Future<void> _initOrders() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null) return;
    await _refreshIncomingCount();
    _ordersChannel = sb.Supabase.instance.client
        .channel('cashier-dinein-$outletId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'outlet_id',
            value: outletId,
          ),
          callback: (payload) {
            final ch = payload.newRecord['channel']?.toString();
            if (ch != null && ch.isNotEmpty && ch != 'dine_in') return;
            _refreshIncomingCount(announce: true);
          },
        )
        .subscribe();
  }

  Future<void> _refreshIncomingCount({bool announce = false}) async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null) return;
    final list = await SupabaseService().getDineInOrders(outletId, limit: 40);
    if (!mounted) return;
    final next = list.where((t) => t.orderStatus != 'selesai').length;
    final increased = next > _incomingCount;
    setState(() {
      _incomingCount = next;
    });
    if (increased && announce && mounted) {
      final latest = list.firstWhere(
        (t) => t.orderStatus != 'selesai',
        orElse: () => list.first,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pesanan masuk: ${latest.notes ?? "Dine-in"}'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Lihat',
            textColor: Colors.white,
            onPressed: _openIncomingOrders,
          ),
        ),
      );
    }
  }

  void _openIncomingOrders() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IncomingOrdersScreen()),
    );
    _refreshIncomingCount();
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
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
          subtotal: product.price * newQty,
        );
      } else {
        newQty = 1;
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

  double get _total => _cart.fold(0.0, (sum, item) => sum + item.subtotal);

  Future<void> _handleCheckout(List<Product> products) async {
    if (_cart.isEmpty) return;

    final result = await showDialog<CheckoutResult>(
      context: context,
      builder: (ctx) => CheckoutDialog(
        items: List.from(_cart),
        totalAmount: _total,
        outletId: ref.read(currentUserProvider)?.outletId,
      ),
    );

    if (result == null) return;
    final cartSnapshot = List<TransactionItem>.from(_cart);

    setState(() => _isLoading = true);

    try {
      final client = sb.Supabase.instance.client;
      final user = client.auth.currentUser;
      final outletId = products.isNotEmpty ? products.first.outletId : null;
      if (outletId == null) {
        throw Exception('Outlet ID tidak ditemukan');
      }

      final tx = Transaction(
        id: '',
        outletId: outletId,
        cashierId: user?.id,
        items: List.from(_cart),
        totalAmount: _total,
        finalAmount: result.amount,
        paymentMethod: result.paymentMethod,
        paymentStatus: 'paid',
        notes: result.notes,
        isSynced: true,
        channel: 'offline',
        createdAt: DateTime.now(),
      );

      final created = await SupabaseService().createTransaction(tx);
      if (created == null) {
        // Offline / gagal jaringan: simpan lokal, sync otomatis saat online.
        final savedOffline =
            await OfflineTransactionService().saveOfflineCheckout(tx);
        ref.invalidate(productsProvider);
        if (mounted) {
          setState(() => _cart.clear());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(savedOffline
                  ? 'Disimpan offline. Terkirim otomatis saat online.'
                  : 'Gagal menyimpan transaksi.'),
              backgroundColor: savedOffline
                  ? AppTheme.warningColor
                  : AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (result.tipAmount > 0) {
        try {
          await SupabaseService().recordTip(
            Tip(
              id: '',
              outletId: outletId,
              transactionId: created.id.isNotEmpty ? created.id : null,
              userId: user?.id,
              amount: result.tipAmount,
              createdAt: DateTime.now(),
            ),
          );
        } catch (_) {}
      }

      ref.invalidate(productsProvider);

      if (mounted) {
        setState(() {
          _cart.clear();
        });

        final outletName = ref.read(currentUserProvider)?.name ?? 'KasirGo';
        final changeMsg = result.change > 0
            ? 'Kembalian: Rp ${result.change.toStringAsFixed(0)}'
            : '';
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => CheckoutSuccessDialog(
            message: changeMsg,
            onReceipt: () {
              ReceiptGenerator.shareTransactionReceipt(
                outletId: outletId,
                storeName: outletName,
                items: cartSnapshot,
                txId: created.id,
                createdAt: DateTime.now(),
                paymentMethod: result.paymentMethod,
                totalAmount: cartSnapshot.fold<double>(
                    0, (s, i) => s + i.price * i.quantity),
                finalAmount: result.amount,
              );
            },
            onFinish: () => Navigator.of(context).pop(),
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
        title: const Text('Kasir POS'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Pesanan Masuk',
                icon: const Icon(Icons.receipt_long_rounded,
                    color: AppTheme.primaryColor),
                onPressed: _openIncomingOrders,
              ),
              if (_incomingCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$_incomingCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
          const LogoutButton(),
        ],
      ),
      body: CentennialBackground(
        child: productsAsync.when(
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
                  if (_incomingCount > 0)
                    InkWell(
                      onTap: _openIncomingOrders,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.10),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(color: AppTheme.errorColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active_rounded,
                                color: AppTheme.errorColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$_incomingCount pesanan pelanggan masuk - ketuk untuk lihat',
                                style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.errorColor),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppTheme.errorColor),
                          ],
                        ),
                      ),
                    ),
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
      ),
    );
  }
}
