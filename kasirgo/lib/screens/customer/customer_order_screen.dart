import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../models/transaction.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

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
  List<Product> _products = [];
  final Map<String, int> _cart = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _selectedCategory = 'Semua';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
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

  double get _totalPrice {
    double total = 0;
    _cart.forEach((productId, qty) {
      final product = _productById(productId);
      if (product != null) total += product.price * qty;
    });
    return total;
  }

  int get _totalItems => _cart.values.fold(0, (a, b) => a + b);

  List<String> get _categories {
    final cats = _products
        .map((p) => p.category)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    return ['Semua', ...cats];
  }

  void _add(Product product) {
    final qty = _cart[product.id] ?? 0;
    if (qty >= product.stock) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Stok ${product.name} tersisa ${product.stock}'),
            duration: const Duration(milliseconds: 900),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      return;
    }
    setState(() => _cart[product.id] = qty + 1);
  }

  void _remove(Product product) {
    final qty = _cart[product.id] ?? 0;
    setState(() {
      if (qty <= 1) {
        _cart.remove(product.id);
      } else {
        _cart[product.id] = qty - 1;
      }
    });
  }

  void _submitOrder() {
    if (_cart.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: Text(
          'Konfirmasi Pesanan',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        content: Text(
          'Kirim pesanan Meja ${widget.tableNumber} ($_totalItems item) senilai ${Formatters.currency(_totalPrice)} ke kasir/dapur?',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _sendOrder();
            },
            child: const Text('Kirim Pesanan'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendOrder() async {
    setState(() => _isSubmitting = true);

    final items = <TransactionItem>[];
    _cart.forEach((id, qty) {
      final product = _productById(id);
      if (product == null) return;
      items.add(TransactionItem(
        productId: product.id,
        productName: product.name,
        price: product.price,
        quantity: qty,
        subtotal: product.price * qty,
      ));
    });

    if (items.isEmpty) {
      setState(() => _isSubmitting = false);
      return;
    }

    final txId = await _service.placeDineInOrder(
      outletId: widget.outletId,
      tableNumber: widget.tableNumber,
      items: items,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (txId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengirim pesanan. Pastikan koneksi internet, lalu coba lagi.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _cart.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pesanan Meja ${widget.tableNumber} berhasil dikirim! Silakan tunggu di meja.'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedCategory == 'Semua'
        ? _products
        : _products.where((p) => p.category == _selectedCategory).toList();

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
              widget.outletName.isNotEmpty ? widget.outletName : 'Menu Pesanan',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary),
            ),
            Text(
              'Meja ${widget.tableNumber}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.primaryColor),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : _buildContent(filtered),
        ),
      ),
      bottomNavigationBar: _cart.isEmpty ? null : _buildCartBar(),
    );
  }

  Widget _buildContent(List<Product> filtered) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_meals_rounded, size: 52, color: AppTheme.textSecondary),
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

    return Column(
      children: [
        if (_categories.length > 1)
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  side: BorderSide(color: isSel ? AppTheme.primaryColor : AppTheme.borderColor),
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
                    'Tidak ada produk di kategori ini',
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
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        childAspectRatio: 0.82,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _buildProductCard(filtered[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    final qty = _cart[product.id] ?? 0;
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
                          product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
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
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOut
                                ? AppTheme.errorColor
                                : product.stock <= 10
                                    ? AppTheme.warningColor
                                    : AppTheme.successColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOut ? 'HABIS' : '${product.stock} ${product.unit ?? 'pcs'}',
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                            ),
                            onPressed: () => _add(product),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        )
                      else
                        SizedBox(
                          height: 34,
                          child: Row(
                            children: [
                              _qtyBtn(Icons.remove_rounded, () => _remove(product)),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '$qty',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
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
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 18, color: AppTheme.primaryColor),
      ),
    );
  }

  Widget _buildCartBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(top: BorderSide(color: AppTheme.borderColor)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.shopping_cart_rounded, color: AppTheme.primaryColor, size: 22),
                  if (_totalItems > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_totalItems',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_totalItems item dipilih',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  Text(
                    Formatters.currency(_totalPrice),
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              onPressed: _isSubmitting ? null : _submitOrder,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSubmitting ? 'Mengirim...' : 'Pesan',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
