import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerMenuScreen extends ConsumerStatefulWidget {
  const CustomerMenuScreen({super.key});

  @override
  ConsumerState<CustomerMenuScreen> createState() =>
      _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends ConsumerState<CustomerMenuScreen> {
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Makanan', 'icon': Icons.restaurant},
    {'name': 'Minuman', 'icon': Icons.local_drink},
    {'name': 'Snack', 'icon': Icons.cookie},
    {'name': 'Lainnya', 'icon': Icons.more_horiz},
  ];

  final List<Map<String, dynamic>> _menuItems = [
    {
      'name': 'Nasi Goreng',
      'price': 25000,
      'desc': 'Nasi goreng spesial',
      'category': 'Makanan',
    },
    {
      'name': 'Mie Goreng',
      'price': 20000,
      'desc': 'Mie goreng telur',
      'category': 'Makanan',
    },
    {
      'name': 'Ayam Goreng',
      'price': 28000,
      'desc': 'Ayam goreng krispi',
      'category': 'Makanan',
    },
    {
      'name': 'Es Teh Manis',
      'price': 5000,
      'desc': 'Teh manis dingin',
      'category': 'Minuman',
    },
    {
      'name': 'Kopi Hitam',
      'price': 12000,
      'desc': 'Kopi tubruk panas',
      'category': 'Minuman',
    },
    {
      'name': 'Jus Alpukat',
      'price': 15000,
      'desc': 'Jus alpukat susu',
      'category': 'Minuman',
    },
    {
      'name': 'Kentang Goreng',
      'price': 18000,
      'desc': 'French fries',
      'category': 'Snack',
    },
    {
      'name': 'Tahu Crispy',
      'price': 12000,
      'desc': 'Tahu goreng tepung',
      'category': 'Snack',
    },
    {
      'name': 'Air Mineral',
      'price': 4000,
      'desc': 'Botol 600ml',
      'category': 'Lainnya',
    },
  ];

  String _selectedCategory = 'Makanan';

  final Map<String, int> _order = {};

  int get _orderTotal {
    return _order.entries.fold(0, (sum, entry) {
      final item = _menuItems.firstWhere(
        (m) => m['name'] == entry.key,
        orElse: () => {'price': 0},
      );
      return sum + ((item['price'] as int) * entry.value);
    });
  }

  int get _orderCount => _order.values.fold(0, (a, b) => a + b);

  List<Map<String, dynamic>> get _filteredItems {
    return _menuItems
        .where((m) => m['category'] == _selectedCategory)
        .toList();
  }

  void _addToOrder(String name) {
    setState(() {
      _order[name] = (_order[name] ?? 0) + 1;
    });
  }

  void _removeFromOrder(String name) {
    setState(() {
      if ((_order[name] ?? 0) > 1) {
        _order[name] = _order[name]! - 1;
      } else {
        _order.remove(name);
      }
    });
  }

  void _showQrDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Scan untuk Pesan',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 180,
              height: 180,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_2,
                    size: 100,
                    color: Colors.grey[800],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Meja 5',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan QR code untuk melihat menu\n dan memesan langsung',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _handlePlaceOrder() {
    if (_order.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: Text(
          'Pesanan Dikirim!',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._order.entries.map((entry) {
              final item = _menuItems.firstWhere(
                (m) => m['name'] == entry.key,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${entry.value}x ${entry.key}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      'Rp ${((item['price'] as int) * entry.value).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(color: Colors.white24),
            Text(
              'Total: Rp ${_orderTotal.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF06B6D4),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() => _order.clear());
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menu',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Meja 5',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _showQrDialog,
                      icon: Icon(
                        Icons.qr_code_2,
                        color: Colors.white.withOpacity(0.8),
                        size: 28,
                      ),
                      tooltip: 'QR Code Meja',
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = cat['name'] == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          cat['name'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withOpacity(0.7),
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat['name']),
                        selectedColor: const Color(0xFF4F46E5),
                        backgroundColor: Colors.white.withOpacity(0.08),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    final orderQty = _order[item['name']] ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.restaurant,
                              color: Color(0xFF4F46E5),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['desc'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Rp ${(item['price'] as int).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF06B6D4),
                            ),
                          ),
                          if (orderQty > 0) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _removeFromOrder(item['name']),
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 20),
                              color: Colors.redAccent,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                            ),
                            Text(
                              '$orderQty',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _addToOrder(item['name']),
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 20),
                              color: const Color(0xFF10B981),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _addToOrder(item['name']),
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 24,
                              ),
                              color: const Color(0xFF10B981),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_orderCount > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_orderCount item',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            Text(
                              'Rp ${_orderTotal.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
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
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: _handlePlaceOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Pesan',
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
      ),
    );
  }
}