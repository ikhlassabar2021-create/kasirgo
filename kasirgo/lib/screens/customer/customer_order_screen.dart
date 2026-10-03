import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../models/transaction.dart';
import '../../services/supabase_service.dart';
import '../../services/ad_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/ads/sponsor_ad_slot.dart';
import '../../widgets/pos/cart_panel.dart';

class CustomerOrderScreen extends StatefulWidget {
  final String outletId;
  final String outletName;
  final String tableNumber;

  const CustomerOrderScreen({
    super.key,
    required this.outletId,
    this.outletName = '',
    required this.tableNumber,
  });

  @override
  State<CustomerOrderScreen> createState() => _CustomerOrderScreenState();
}

class _CustomerOrderScreenState extends State<CustomerOrderScreen> {
  final _service = SupabaseService();
  final _searchController = TextEditingController();
  List<Product> _products = [];
  final List<TransactionItem> _cart = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _selectedCategory = 'Semua';
  String _searchQuery = '';
  String? _error;
  bool _adConsent = false;
  List<Map<String, dynamic>> _orderStatuses = [];
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadAdConsent();
    _refreshOrderStatus();
    // Status pesanan diperbarui otomatis (kasir konfirmasi bayar / dapur
    // memproses). Polling ringan tiap 8 detik, aman utk web & APK.
    _statusTimer = Timer.periodic(
        const Duration(seconds: 8), (_) => _refreshOrderStatus());
  }

  Future<void> _refreshOrderStatus() async {
    if (widget.outletId.isEmpty) return;
    final data = await _service.getPublicOrderStatus(
        widget.outletId, widget.tableNumber);
    if (!mounted || _orderStatuses.toString() == data.toString()) return;
    setState(() => _orderStatuses = data);
  }

  Future<void> _loadAdConsent() async {
    final consent = await AdService().getConsent();
    if (mounted) setState(() => _adConsent = consent == true);
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final data = await _service.getPublicMenu(widget.outletId);
    if (!mounted) return;
    setState(() {
      _products = data.where((p) => p.isActive).toList();
      _isLoading = false;
      if (_products.isEmpty) {
        _error = 'Menu belum tersedia. Minta kasir mengaktifkan produk.';
      }
    });
  }

  Product? _productById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  int _qtyOf(String productId) {
    final index = _cart.indexWhere((item) => item.productId == productId);
    return index < 0 ? 0 : _cart[index].quantity;
  }

  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + item.subtotal);
  int get _totalItems => _cart.fold(0, (sum, item) => sum + item.quantity);

  List<String> get _categories {
    final cats = _products
        .map((p) => p.category)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    return ['Semua', ...cats];
  }

  List<Product> get _filtered {
    final query = _searchQuery.trim().toLowerCase();
    return _products.where((p) {
      final matchCat =
          _selectedCategory == 'Semua' || p.category == _selectedCategory;
      final matchQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          (p.barcode != null && p.barcode!.toLowerCase().contains(query));
      return matchCat && matchQuery;
    }).toList();
  }

  void _add(Product product) {
    if (product.stock <= 0) return;
    final index = _cart.indexWhere((item) => item.productId == product.id);
    final current = index < 0 ? 0 : _cart[index].quantity;
    if (current >= product.stock) {
      _notify('Stok ${product.name} tersisa ${product.stock}',
          AppTheme.warningColor);
      return;
    }
    setState(() {
      if (index < 0) {
        _cart.add(TransactionItem(
          productId: product.id,
          productName: product.name,
          price: product.price,
          quantity: 1,
          subtotal: product.price,
        ));
      } else {
        final qty = current + 1;
        _cart[index] = _cart[index].copyWith(
          quantity: qty,
          subtotal: product.price * qty,
        );
      }
    });
  }

  void _remove(Product product) {
    final index = _cart.indexWhere((item) => item.productId == product.id);
    if (index < 0) return;
    setState(() {
      if (_cart[index].quantity <= 1) {
        _cart.removeAt(index);
      } else {
        final qty = _cart[index].quantity - 1;
        _cart[index] = _cart[index].copyWith(
          quantity: qty,
          subtotal: _cart[index].price * qty,
        );
      }
    });
  }

  void _updateQty(MapEntry<String, int> entry) {
    final index = _cart.indexWhere((item) => item.productId == entry.key);
    if (index < 0) return;
    final product = _productById(entry.key);
    final maxStock = product?.stock ?? 9999;
    final target = entry.value.clamp(1, maxStock).toInt();
    setState(() {
      _cart[index] = _cart[index].copyWith(
        quantity: target,
        subtotal: _cart[index].price * target,
      );
    });
  }

  void _removeItem(int index) {
    setState(() => _cart.removeAt(index));
  }

  Future<void> _openCheckout() async {
    if (_cart.isEmpty || _isSubmitting) return;

    final result = await showDialog<CustomerCheckoutResult>(
      context: context,
      builder: (_) => CustomerCheckoutDialog(
        outletId: widget.outletId,
        total: _subtotal,
        itemCount: _totalItems,
        tableNumber: widget.tableNumber,
      ),
    );
    if (result == null) return;
    await _sendOrder(result.paymentMethod);
  }

  Future<void> _sendOrder(String paymentMethod) async {
    setState(() => _isSubmitting = true);

    final total = _subtotal;
    final itemCount = _totalItems;
    final txId = await _service.placeDineInOrder(
      outletId: widget.outletId,
      tableNumber: widget.tableNumber,
      items: List.from(_cart),
      paymentMethod: paymentMethod,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (txId == null) {
      _notify('Gagal mengirim pesanan. Periksa koneksi lalu coba lagi.',
          AppTheme.errorColor);
      return;
    }

    setState(() => _cart.clear());
    await _showSuccess(total, itemCount, txId, paymentMethod);
    _refreshOrderStatus();
  }

  Future<void> _showSuccess(
    double total,
    int itemCount,
    String txId,
    String paymentMethod,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppTheme.successColor, size: 46),
              ),
              const SizedBox(height: 16),
              Text(
                'Pesanan Terkirim!',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pesanan Meja ${widget.tableNumber} sudah diteruskan ke kasir/dapur. Silakan menunggu di meja.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    _SuccessRow(label: 'Jumlah item', value: '$itemCount item'),
                    const SizedBox(height: 8),
                    _SuccessRow(
                      label: 'Metode pembayaran',
                      value: paymentMethod == 'cash'
                          ? 'Tunai di Kasir'
                          : 'QRIS (konfirmasi kasir)',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppTheme.borderColor),
                    ),
                    _SuccessRow(
                      label: 'Total',
                      value: Formatters.currency(total),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pesanan Anda sudah kami terima. Terima kasih!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppTheme.borderColor),
                    ),
                    _SuccessRow(
                      label: 'Total',
                      value: Formatters.currency(total),
                      emphasize: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: AppTheme.touchTargetLarge,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Pesan Lagi',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _notify(String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.outletName.isNotEmpty
                  ? widget.outletName
                  : 'Menu Pesanan',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.textPrimary),
            ),
            Text(
              'Meja ${widget.tableNumber}',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppTheme.primaryColor),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Stack(
            children: [
              Positioned.fill(child: _buildBody()),
              if (_isSubmitting) const _SendingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    if (_error != null) return _buildErrorState();

    return LayoutBuilder(
      builder: (context, constraints) {
        final banner = _buildOrderStatusBanner();
        final isWide = constraints.maxWidth >= 760;
        if (isWide) {
          return Column(
            children: [
              banner,
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                        flex: 65,
                        child: _buildCatalog(constraints.maxWidth * 0.35)),
                    SizedBox(
                      width: constraints.maxWidth * 0.35,
                      child: _buildPersistentCart(),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            banner,
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child:
                        _buildCatalog(constraints.maxWidth, bottomPadding: 240),
                  ),
                  if (_cart.isNotEmpty)
                    CartPanel(
                      items: _cart,
                      onCheckout: _openCheckout,
                      onRemoveItem: _removeItem,
                      onUpdateQty: _updateQty,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Banner status pesanan terakhir meja ini (polling otomatis).
  Widget _buildOrderStatusBanner() {
    if (_orderStatuses.isEmpty) return const SizedBox.shrink();

    final unpaid = _orderStatuses
        .where((o) => (o['payment_status'] ?? '') == 'unpaid')
        .toList();
    final active = _orderStatuses
        .where((o) =>
            o['payment_status'] != 'unpaid' &&
            (o['order_status'] ?? 'baru') != 'selesai')
        .toList();
    final tx = unpaid.isNotEmpty
        ? unpaid.first
        : (active.isNotEmpty ? active.last : null);
    if (tx == null) return const SizedBox.shrink();

    final payStatus = tx['payment_status']?.toString() ?? 'unpaid';
    final method = tx['payment_method']?.toString() ?? 'cash';
    final kitchen = tx['order_status']?.toString() ?? 'baru';

    String title;
    String subtitle;
    IconData icon;
    Color color;
    if (payStatus == 'unpaid') {
      if (method == 'qris') {
        title = 'Menunggu Konfirmasi QRIS';
        subtitle =
            'Pesanan sudah masuk ke kasir. Setelah pembayaran QRIS dikonfirmasi kasir, pesanan langsung diproses dapur.';
        icon = Icons.qr_code_2_rounded;
        color = AppTheme.warningColor;
      } else {
        title = 'Silakan Bayar di Kasir';
        subtitle =
            'Pesanan sudah masuk ke kasir. Setelah kasir menerima pembayaran tunai, pesanan langsung diproses dapur.';
        icon = Icons.payments_rounded;
        color = AppTheme.warningColor;
      }
    } else if (kitchen == 'baru') {
      title = 'Pesanan Diterima';
      subtitle = 'Kasir sudah konfirmasi. Pesanan masuk antrean dapur.';
      icon = Icons.receipt_long_rounded;
      color = AppTheme.primaryColor;
    } else if (kitchen == 'diproses') {
      title = 'Sedang Diproses';
      subtitle = 'Koki sedang menyiapkan pesanan kamu.';
      icon = Icons.soup_kitchen_rounded;
      color = AppTheme.warningColor;
    } else if (kitchen == 'siap') {
      title = 'Pesanan Siap!';
      subtitle = 'Selamat menikmati.';
      icon = Icons.emoji_food_beverage_rounded;
      color = AppTheme.successColor;
    } else {
      title = 'Pesanan Selesai';
      subtitle = 'Terima kasih telah berkunjung.';
      icon = Icons.check_circle_rounded;
      color = AppTheme.successColor;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_meals_rounded,
                size: 52, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Muat ulang'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalog(double availableWidth, {double bottomPadding = 16}) {
    final filtered = _filtered;
    return Column(
      children: [
        SponsorAdSlot(
          outletId: widget.outletId,
          consentGiven: _adConsent,
          compact: availableWidth < 760,
          onConsentChanged: (v) => setState(() => _adConsent = v),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Cari produk...',
              filled: true,
              fillColor: AppTheme.surfaceColor,
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: AppTheme.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: AppTheme.primaryColor, width: 1.5),
              ),
            ),
          ),
        ),
        if (_categories.length > 1)
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final cat = _categories[idx];
                final isSel = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSel,
                  showCheckmark: false,
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.surfaceColor,
                  side: BorderSide(
                      color:
                          isSel ? AppTheme.primaryColor : AppTheme.borderColor),
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  ),
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada produk ditemukan',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final cols = w >= 1000
                        ? 5
                        : w >= 760
                            ? 4
                            : w >= 520
                                ? 3
                                : 2;
                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(12, 6, 12, bottomPadding),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        childAspectRatio: 0.82,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          _buildProductCard(filtered[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPersistentCart() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: CartContent(
            items: _cart,
            showDragHandle: false,
            onCheckout: _openCheckout,
            onRemoveItem: _removeItem,
            onUpdateQty: _updateQty,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final qty = _qtyOf(product.id);
    final inCart = qty > 0;
    final isOut = product.stock <= 0;

    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isOut ? null : () => _add(product),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: inCart ? AppTheme.primaryColor : AppTheme.borderColor,
              width: inCart ? 1.6 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  width: double.infinity,
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          product.name.isNotEmpty
                              ? product.name[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOut
                                ? AppTheme.errorColor
                                : product.stock <= 10
                                    ? AppTheme.warningColor
                                    : AppTheme.successColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOut
                                ? 'HABIS'
                                : '${product.stock} ${product.unit ?? 'pcs'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        Formatters.currency(product.price),
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (isOut)
                        const SizedBox(height: 34)
                      else if (!inCart)
                        SizedBox(
                          height: 34,
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9)),
                            ),
                            onPressed: () => _add(product),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Tambah',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        )
                      else
                        SizedBox(
                          height: 34,
                          child: Row(
                            children: [
                              _qtyBtn(
                                  Icons.remove_rounded, () => _remove(product)),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '$qty',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.textPrimary),
                                  ),
                                ),
                              ),
                              _qtyBtn(Icons.add_rounded, () => _add(product)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9),
          border:
              Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 18, color: AppTheme.primaryColor),
      ),
    );
  }
}

class CustomerCheckoutResult {
  final String paymentMethod;
  const CustomerCheckoutResult(this.paymentMethod);
}

class CustomerCheckoutDialog extends StatefulWidget {
  final String outletId;
  final double total;
  final int itemCount;
  final String tableNumber;

  const CustomerCheckoutDialog({
    super.key,
    required this.outletId,
    required this.total,
    required this.itemCount,
    required this.tableNumber,
  });

  @override
  State<CustomerCheckoutDialog> createState() => _CustomerCheckoutDialogState();
}

class _CustomerCheckoutDialogState extends State<CustomerCheckoutDialog> {
  final _service = SupabaseService();
  String _paymentMethod = 'cash';
  bool _loadingPayment = true;
  Map<String, dynamic>? _pay;

  @override
  void initState() {
    super.initState();
    _loadPaymentInfo();
  }

  Future<void> _loadPaymentInfo() async {
    final data = await _service.getPublicOutletPayment(widget.outletId);
    if (!mounted) return;
    final hasQris =
        data != null && (data['nmid']?.toString().trim().isNotEmpty ?? false);
    setState(() {
      _pay = data;
      _loadingPayment = false;
      _paymentMethod = hasQris ? 'qris' : 'cash';
    });
  }

  String _str(String key) => _pay?[key]?.toString().trim() ?? '';

  String get _merchantName {
    final v = _str('merchant_name');
    return v.isNotEmpty ? v : 'Toko';
  }

  bool get _hasAnyPaymentInfo =>
      _loadingPayment ? false : _str('nmid').isNotEmpty;

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$label disalin'),
        duration: const Duration(milliseconds: 1200),
        backgroundColor: AppTheme.successColor,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                    decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: AppTheme.borderColor)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded,
                              color: AppTheme.accentColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bayar di Meja',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Tanpa antre di kasir',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: AppTheme.textSecondary),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTotalCard(),
                          const SizedBox(height: 18),
                          if (_loadingPayment)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: AppTheme.primaryColor),
                                ),
                              ),
                            )
                          else ...[
                            Text(
                              'Pilih Cara Bayar',
                              style: GoogleFonts.inter(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildPaymentOption(
                                'qris', 'QRIS (scan di meja)', Icons.qr_code_2_rounded),
                            _buildPaymentOption('cash',
                                'Tunai (bayar di kasir)', Icons.payments_rounded),
                            const SizedBox(height: 12),
                            if (_paymentMethod == 'qris')
                              _buildQrisInfo()
                            else
                              _buildCashInfo(),
                          ],
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: AppTheme.touchTargetLarge,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _loadingPayment
                                  ? null
                                  : () => Navigator.of(context)
                                      .pop(CustomerCheckoutResult(_paymentMethod)),
                              icon: const Icon(Icons.send_rounded, size: 20),
                              label: Text(
                                'Kirim Pesanan',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQrisInfo() {
    final nmid = _str('nmid');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded,
                  color: AppTheme.primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Scan QRIS di meja',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Scan stiker QRIS $_merchantName yang tersedia di meja, lalu masukkan nominal berikut:',
            style: GoogleFonts.inter(
                color: AppTheme.textSecondary, fontSize: 11.5, height: 1.35),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Nominal',
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary, fontSize: 12)),
              Text(
                Formatters.currency(widget.total),
                style: GoogleFonts.inter(
                  color: AppTheme.primaryColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (nmid.isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow('NMID', nmid, copyable: false),
          ],
          const SizedBox(height: 8),
          Text(
            'Setelah scan & bayar, tunjukkan bukti ke kasir. Pesanan diproses '
            'setelah kasir mengonfirmasi pembayaran.',
            style: GoogleFonts.inter(
                color: AppTheme.textSecondary, fontSize: 11.5, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildCashInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppTheme.warningColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _hasAnyPaymentInfo
                  ? 'Pesanan dikirim ke kasir. Bayar tunai di kasir, lalu kasir '
                      'mengonfirmasi agar pesanan diproses dapur.'
                  : 'Pesanan dikirim ke kasir. Anda dapat bayar langsung ke kasir.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {required bool copyable}) {
    return Row(
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: GoogleFonts.inter(
                color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (copyable)
          InkWell(
            onTap: () => _copy(value, label),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded,
                  size: 16, color: AppTheme.primaryColor),
            ),
          ),
      ],
    );
  }

  Widget _buildTotalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.30),
            AppTheme.secondaryColor.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'MEJA ${widget.tableNumber}',
                style: GoogleFonts.inter(
                  color: AppTheme.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.itemCount} item',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'TOTAL TAGIHAN',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.currency(widget.total),
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, String label, IconData icon) {
    final isSelected = _paymentMethod == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                : AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 22,
                  color: isSelected
                      ? AppTheme.accentColor
                      : AppTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isSelected
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded,
                    size: 20, color: AppTheme.accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _SuccessRow(
      {required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
              color: AppTheme.textSecondary, fontSize: 12.5),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              color: emphasize
                  ? AppTheme.primaryColor
                  : AppTheme.textPrimary,
              fontSize: emphasize ? 16 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SendingOverlay extends StatelessWidget {
  const _SendingOverlay();

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
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppTheme.accentColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: AppTheme.accentColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Mengirim pesanan...',
                      style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
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
