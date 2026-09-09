import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CashierHomeScreen extends ConsumerStatefulWidget {
  const CashierHomeScreen({super.key});

  @override
  ConsumerState<CashierHomeScreen> createState() => _CashierHomeScreenState();
}

class _CashierHomeScreenState extends ConsumerState<CashierHomeScreen> {
  final List<Map<String, dynamic>> _products = [
    {'name': 'Kopi Arabica', 'price': 45000},
    {'name': 'Mie Instan', 'price': 3500},
    {'name': 'Sabun Mandi', 'price': 15000},
    {'name': 'Beras 5kg', 'price': 65000},
    {'name': 'Teh Celup', 'price': 12000},
    {'name': 'Gula 1kg', 'price': 16000},
    {'name': 'Minyak 2L', 'price': 38000},
    {'name': 'Snack Coklat', 'price': 8000},
    {'name': 'Roti Tawar', 'price': 18000},
    {'name': 'Susu UHT', 'price': 7000},
    {'name': 'Telur 1kg', 'price': 28000},
    {'name': 'Shampoo', 'price': 22000},
    {'name': 'Pasta Gigi', 'price': 12000},
    {'name': 'Tisu Gulung', 'price': 9000},
    {'name': 'Saus Sambal', 'price': 10000},
    {'name': 'Kecap Manis', 'price': 14000},
  ];

  final Map<String, Map<String, dynamic>> _cart = {};

  double get _subtotal {
    return _cart.values.fold(0, (sum, item) {
      return sum + ((item['price'] as int) * (item['qty'] as int));
    }).toDouble();
  }

  double get _total => _subtotal;

  void _addToCart(Map<String, dynamic> product) {
    final key = product['name'] as String;
    setState(() {
      if (_cart.containsKey(key)) {
        _cart[key]!['qty'] = (_cart[key]!['qty'] as int) + 1;
      } else {
        _cart[key] = {
          'name': product['name'],
          'price': product['price'],
          'qty': 1,
        };
      }
    });
  }

  void _incrementQty(String key) {
    setState(() => _cart[key]!['qty'] = (_cart[key]!['qty'] as int) + 1);
  }

  void _decrementQty(String key) {
    setState(() {
      if ((_cart[key]!['qty'] as int) > 1) {
        _cart[key]!['qty'] = (_cart[key]!['qty'] as int) - 1;
      } else {
        _cart.remove(key);
      }
    });
  }

  void _clearCart() {
    setState(() => _cart.clear());
  }

  void _handleCheckout() {
    if (_cart.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: Text(
          'Konfirmasi Pembayaran',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total: Rp ${_total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF06B6D4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_cart.length} item',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _clearCart();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pembayaran berhasil!'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
            ),
            child: const Text('Bayar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Kasir',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF4F46E5).withOpacity(0.3),
              child: Text(
                'K',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4F46E5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return GestureDetector(
                      onTap: () => _addToCart(product),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5)
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.inventory_2,
                                color: Color(0xFF4F46E5),
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product['name'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rp ${(product['price'] as int).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF06B6D4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                height: 4,
                color: const Color(0xFF4F46E5).withOpacity(0.3),
              ),
              Container(
                height: MediaQuery.of(context).size.height * 0.33,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Keranjang',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (_cart.isNotEmpty)
                            TextButton(
                              onPressed: _clearCart,
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _cart.isEmpty
                          ? Center(
                              child: Text(
                                'Keranjang kosong',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: _cart.length,
                              itemBuilder: (context, index) {
                                final key =
                                    _cart.keys.elementAt(index);
                                final item = _cart[key]!;
                                final itemTotal =
                                    (item['price'] as int) *
                                        (item['qty'] as int);
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            Text(
                                              item['name'],
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              'Rp ${itemTotal.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: const Color(
                                                    0xFF06B6D4),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _cartButton(
                                        Icons.remove,
                                        () => _decrementQty(key),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets
                                            .symmetric(horizontal: 12),
                                        child: Text(
                                          '${item['qty']}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      _cartButton(
                                        Icons.add,
                                        () => _incrementQty(key),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                                Text(
                                  'Rp ${_total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF06B6D4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 48,
                            width: 140,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4F46E5),
                                    Color(0xFF7C3AED),
                                  ],
                                ),
                              ),
                              child: ElevatedButton(
                                onPressed: _cart.isEmpty
                                    ? null
                                    : _handleCheckout,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Bayar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cartButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}