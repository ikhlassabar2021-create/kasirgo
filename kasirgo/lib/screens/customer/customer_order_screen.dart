import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

class CustomerOrderScreen extends StatefulWidget {
  final String outletId;
  final String tableNumber;

  const CustomerOrderScreen({
    super.key,
    required this.outletId,
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
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final data = await _service.getProducts(widget.outletId);
    setState(() {
      _products = data.where((p) => p.isActive && p.stock > 0).toList();
      _isLoading = false;
    });
  }

  double get _totalPrice {
    double total = 0;
    _cart.forEach((productId, qty) {
      final product = _products.firstWhere((p) => p.id == productId, orElse: () => _products.first);
      total += product.price * qty;
    });
    return total;
  }

  int get _totalItems => _cart.values.fold(0, (a, b) => a + b);

  List<String> get _categories {
    final cats = _products.map((p) => p.category).where((c) => c != null && c.isNotEmpty).cast<String>().toSet().toList();
    return ['Semua', ...cats];
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
              setState(() => _cart.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pesanan Meja ${widget.tableNumber} berhasil dikirim! Silakan tunggu di meja.'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
            child: const Text('Kirim Pesanan'),
          ),
        ],
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
              'Menu Pesanan',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary),
            ),
            Text(
              'Meja ${widget.tableNumber}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12, color: AppTheme.primaryColor),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                if (_categories.length > 1)
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final cat = _categories[idx];
                        final isSel = _selectedCategory == cat;
                        return InkWell(
                          onTap: () => setState(() => _selectedCategory = cat),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? AppTheme.primaryColor : AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSel ? AppTheme.primaryColor : AppTheme.borderColor),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: isSel ? Colors.white : AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada produk tersedia',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            final qty = _cart[product.id] ?? 0;

                            return Card(
                              color: AppTheme.surfaceColor,
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: AppTheme.borderColor),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.borderColor),
                                      ),
                                      child: const Icon(Icons.restaurant_rounded, color: AppTheme.primaryColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            Formatters.currency(product.price),
                                            style: GoogleFonts.inter(
                                              color: AppTheme.primaryColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (qty == 0)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryColor,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        ),
                                        onPressed: () {
                                          setState(() => _cart[product.id] = 1);
                                        },
                                        child: const Text('+ Tambah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      )
                                    else
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, color: AppTheme.errorColor, size: 22),
                                            onPressed: () {
                                              setState(() {
                                                if (qty <= 1) {
                                                  _cart.remove(product.id);
                                                } else {
                                                  _cart[product.id] = qty - 1;
                                                }
                                              });
                                            },
                                          ),
                                          Text(
                                            '$qty',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 22),
                                            onPressed: () {
                                              if (qty < product.stock) {
                                                setState(() => _cart[product.id] = qty + 1);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_cart.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceColor,
                      border: Border(top: BorderSide(color: AppTheme.borderColor)),
                    ),
                    child: SafeArea(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$_totalItems Item Dipilih',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              Text(
                                Formatters.currency(_totalPrice),
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            ),
                            onPressed: _submitOrder,
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              'Pesan Sekarang',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
