import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../services/offline_transaction_service.dart';
import '../../services/supabase_service.dart';
import '../../services/growth_service.dart';
import '../../utils/ai_engine.dart';
import '../../utils/formatters.dart';
import '../../utils/receipt_generator.dart';
import '../../widgets/common/centennial_background.dart';
import '../owner/product_list_screen.dart';
import '../../widgets/pos/product_grid.dart';
import '../../models/shift.dart';
import '../../widgets/pos/cart_panel.dart';
import '../../widgets/pos/checkout_dialog.dart';

class PosScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const PosScreen({super.key, this.embedded = false});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  final List<TransactionItem> _cart = [];

  Shift? _openShift;
  String _searchQuery = '';
  String _selectedChannel = 'Toko Fisik';
  double _discountAmount = 0.0;
  bool _isLoading = false;
  Map<String, Map<String, double>> _channelPrices = {};
  Map<String, Map<String, dynamic>> _activeDiscounts = {};

  // ST15-3: bundling + cross-sell.
  final GrowthService _growth = GrowthService();
  final AIEngine _ai = AIEngine();
  List<Map<String, dynamic>> _bundles = [];
  List<Map<String, dynamic>> _productIndex = [];
  List<Map<String, dynamic>> _crossSellChips = [];

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
    _loadOpenShift();
    super.initState();
    _loadPricingAndDiscounts();
    _loadGrowthData();
  }

  /// ST15-3: muat paket bundling aktif + hitung peluang cross-sell.
  Future<void> _loadGrowthData() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    try {
      final bundles = await _growth.listBundles(outletId, onlyActive: true);
      final prods = await _growth.productsClient
          .from('products')
          .select('id, name, base_price, stock')
          .eq('outlet_id', outletId);
      if (mounted) {
        setState(() {
          _bundles = bundles;
          _productIndex = List<Map<String, dynamic>>.from(prods as List);
        });
      }
      await _computeCrossSell(outletId);
    } catch (_) {}
  }

  Future<void> _computeCrossSell(String outletId) async {
    try {
      final trx = await _growth.productsClient
          .from('transactions')
          .select('id')
          .eq('outlet_id', outletId)
          .eq('payment_status', 'paid')
          .order('created_at', ascending: false)
          .limit(200);
      final txIds = (trx as List).map((t) => t['id']).toList();
      if (txIds.isEmpty) return;
      final items = await _growth.productsClient
          .from('transaction_items')
          .select('transaction_id, product_id, product_name')
          .inFilter('transaction_id', txIds);
      final baskets = <String, Set<String>>{};
      final nameOf = <String, String>{};
      for (final it in items as List) {
        final txId = it['transaction_id'].toString();
        baskets.putIfAbsent(txId, () => <String>{});
        baskets[txId]!.add(it['product_id'].toString());
        if (it['product_name'] != null) {
          nameOf[it['product_id'].toString()] = it['product_name'].toString();
        }
      }
      final rules = _ai.crossSellRules(
        baskets.values.map((s) => s.toList()).toList(),
        minSupport: 1,
      );
      final chips = <Map<String, dynamic>>[];
      for (final r in rules) {
        final toId = r['consequent']?.toString() ?? '';
        final prod = _productIndex.firstWhere(
          (p) => p['id'] == toId,
          orElse: () => const {},
        );
        if (prod.isEmpty) continue;
        chips.add({
          'from_name': nameOf[r['antecedent']?.toString()] ?? 'produk ini',
          'product_id': toId,
          'product_name': prod['name'],
          'product': prod,
        });
      }
      if (mounted) setState(() => _crossSellChips = chips.take(6).toList());
    } catch (_) {}
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

  Future<void> _addToCart(Product product) async {
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

  Future<void> _loadOpenShift() async {
    final client = sb.Supabase.instance.client;
    final outletId = client.auth.currentUser != null
        ? (ref.read(currentUserProvider)?.outletId ?? '')
        : '';
    if (outletId.isEmpty) return;
    final shift = await SupabaseService().getOpenShift(outletId);
    if (mounted) setState(() => _openShift = shift);
  }

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
    final cartDiscount = _discountAmount;

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
        // Offline / gagal jaringan: simpan lokal, sync otomatis saat online.
        final savedOffline =
            await OfflineTransactionService().saveOfflineCheckout(tx);
        ref.invalidate(productsProvider);
        if (mounted) {
          setState(() {
            _cart.clear();
            _discountAmount = 0.0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(savedOffline
                  ? 'Disimpan offline. Terkirim otomatis saat online.'
                  : 'Gagal menyimpan transaksi.'),
              backgroundColor:
                  savedOffline ? AppTheme.warningColor : AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Catat pembayaran (split bill / tunggal) + tip - best effort.
      final shiftId = _openShift?.isOpen == true ? _openShift!.id : null;
      if (result.payments.isNotEmpty) {
        for (final p in result.payments) {
          await SupabaseService().addTransactionPayment(
            outletId: outletId,
            transactionId: created.id,
            method: p.method,
            amount: p.amount,
            userId: user?.id,
            shiftId: shiftId,
          );
        }
      } else {
        await SupabaseService().addTransactionPayment(
          outletId: outletId,
          transactionId: created.id,
          method: result.paymentMethod,
          amount: result.amount,
          userId: user?.id,
          shiftId: shiftId,
        );
      }
      if (result.tipAmount > 0) {
        await SupabaseService().addTip(
          outletId: outletId,
          amount: result.tipAmount,
          transactionId: created.id,
          userId: user?.id,
          shiftId: shiftId,
        );
      }

      ref.invalidate(productsProvider);

      if (mounted) {
        setState(() {
          _cart.clear();
          _discountAmount = 0.0;
        });

        final outletName = ref.read(currentUserProvider)?.name ?? 'KasirGo';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.change > 0
                  ? 'Transaksi sukses! Kembalian: Rp ${result.change.toStringAsFixed(0)}'
                  : 'Transaksi sukses!',
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 12),
            action: SnackBarAction(
              label: 'STRUK',
              textColor: Colors.white,
              onPressed: () {
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
                  discountAmount: cartDiscount,
                );
              },
            ),
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

    final body = CentennialBackground(
      child: productsAsync.when(
        loading: () => const _PosSkeleton(),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Gagal memuat produk: $err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ),
        data: (products) {
          final filtered = products.where((p) {
            final matchSearch = _searchQuery.isEmpty ||
                p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (p.barcode != null && p.barcode!.contains(_searchQuery));
            return matchSearch;
          }).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= 600;
              return Stack(
                children: [
                  if (isTablet)
                    Row(
                      children: [
                        Expanded(
                          flex: 65,
                          child: _buildCatalog(filtered, products, bottomPadding: 16),
                        ),
                        SizedBox(
                          width: constraints.maxWidth * 0.35,
                          child: _buildPersistentCart(products),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Expanded(child: _buildCatalog(filtered, products, bottomPadding: 220)),
                      ],
                    ),
                  if (!isTablet)
                    CartPanel(
                      items: _cart,
                      discountAmount: _discountAmount,
                      onCheckout: () => _handleCheckout(products),
                      onRemoveItem: _removeItem,
                      onUpdateQty: (entry) => _updateQty(entry, products),
                    ),
                  if (_isLoading) const _SyncingOverlay(),
                ],
              );
            },
          );
        },
      ),
    );

    if (widget.embedded) {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _buildChannelSelector(),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Kasir POS',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        actions: [
          _buildChannelSelector(),
          const SizedBox(width: 12),
        ],
      ),
      body: body,
    );
  }

  Widget _buildCatalog(List<Product> filtered, List<Product> products, {required double bottomPadding}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: TextField(                controller: _searchController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Cari produk / barcode...',
                  filled: true,
                  fillColor: AppTheme.surfaceColor.withValues(alpha: 0.7),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.accentColor, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_bundles.isNotEmpty || _crossSellChips.isNotEmpty)
          _buildGrowthStrip(),
        Expanded(
          child: ProductGrid(
            products: filtered,
            bottomPadding: bottomPadding,
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
    );
  }

  /// ST15-3: strip horizontal paket bundling + chip saran cross-sell.
  Widget _buildGrowthStrip() {
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
        children: [
          for (final b in _bundles)
            _GrowthChip(
              icon: Icons.inventory_2_rounded,
              label: b['name']?.toString() ?? 'Paket',
              sub: Formatters.currency(
                  (b['bundle_price'] as num?)?.toDouble() ?? 0),
              color: const Color(0xFF7C3AED),
              onTap: () => _addBundleToCart(b),
            ),
          for (final c in _crossSellChips)
            _GrowthChip(
              icon: Icons.auto_awesome_rounded,
              label: c['product_name']?.toString() ?? 'Saran',
              sub: 'Sering dibeli dgn ${c['from_name']}',
              color: AppTheme.accentColor,
              onTap: () => _addProductById(c['product_id']?.toString()),
            ),
        ],
      ),
    );
  }

  Future<void> _addBundleToCart(Map<String, dynamic> bundle) async {
    final items = (bundle['product_bundle_items'] as List?) ?? [];
    if (items.isEmpty) return;
    final bundlePrice = (bundle['bundle_price'] as num?)?.toDouble() ?? 0;
    final bundleName = bundle['name']?.toString() ?? 'Paket';
    setState(() {
      _cart.add(TransactionItem(
        productId: 'bundle:${bundle['id']}',
        productName: '$bundleName (Paket)',
        price: bundlePrice,
        quantity: 1,
        subtotal: bundlePrice,
      ));
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$bundleName ditambahkan sebagai 1 item paket'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _addProductById(String? productId) {
    if (productId == null) return;
    final data = _productIndex.firstWhere(
      (p) => p['id'] == productId,
      orElse: () => const {},
    );
    if (data.isEmpty) return;
    final product = Product(
      id: productId,
      outletId: data['outlet_id']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Produk',
      basePrice: (data['base_price'] as num?)?.toDouble() ?? 0,
      stock: ((data['stock'] as num?)?.toDouble() ?? 0).toInt(),
    );
    _addToCart(product);
  }

  Widget _buildPersistentCart(List<Product> products) {    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: CartContent(
            items: _cart,
            showDragHandle: false,
            discountAmount: _discountAmount,
            onCheckout: () => _handleCheckout(products),
            onRemoveItem: _removeItem,
            onUpdateQty: (entry) => _updateQty(entry, products),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedChannel,
          isDense: true,
          dropdownColor: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.accentColor),
          style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
          items: _channels
              .map((ch) => DropdownMenuItem(value: ch, child: Text(ch)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedChannel = val);
          },
        ),
      ),
    );
  }
}

class _SyncingOverlay extends StatelessWidget {
  const _SyncingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.black.withValues(alpha: 0.45),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.accentColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Memproses pembayaran...',
                      style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PosSkeleton extends StatelessWidget {
  const _PosSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.72,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 9,
      itemBuilder: (_, _) => const CentennialSkeleton(borderRadius: BorderRadius.all(Radius.circular(16))),
    );
  }
}

class _GrowthChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  const _GrowthChip({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: color),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
