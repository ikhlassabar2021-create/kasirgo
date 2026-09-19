import 'package:flutter/material.dart';
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

  void _submitOrder() {
    if (_cart.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Konfirmasi Pesanan'),
        content: Text('Kirim pesanan untuk ${widget.tableNumber} senilai ${Formatters.currency(_totalPrice)} ke kasir/dapur?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _cart.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pesanan untuk ${widget.tableNumber} berhasil dikirim! Silakan tunggu di meja.'),
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Menu Order (${widget.tableNumber})'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      final qty = _cart[product.id] ?? 0;

                      return Card(
                        color: AppTheme.surfaceColor,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.fastfood, color: AppTheme.accentColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      Formatters.currency(product.price),
                                      style: const TextStyle(color: AppTheme.accentColor, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              if (qty == 0)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  onPressed: () {
                                    setState(() => _cart[product.id] = 1);
                                  },
                                  child: const Text('+ Tambah'),
                                )
                              else
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
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
                                    Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: AppTheme.successColor),
                                      onPressed: () {
                                        setState(() => _cart[product.id] = qty + 1);
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
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      border: Border(top: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.5))),
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
                                '${_cart.values.fold(0, (a, b) => a + b)} Item Dipilih',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              Text(
                                Formatters.currency(_totalPrice),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentColor,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            icon: const Icon(Icons.send),
                            label: const Text('Kirim Order', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _submitOrder,
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
