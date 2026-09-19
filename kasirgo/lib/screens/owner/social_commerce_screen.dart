import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

class SocialCommerceScreen extends ConsumerStatefulWidget {
  const SocialCommerceScreen({super.key});

  @override
  ConsumerState<SocialCommerceScreen> createState() => _SocialCommerceScreenState();
}

class _SocialCommerceScreenState extends ConsumerState<SocialCommerceScreen> {
  final _service = SupabaseService();
  String _selectedChannel = 'tokopedia';
  List<Product> _products = [];
  bool _isLoading = true;

  final _channels = [
    {'id': 'tokopedia', 'name': 'Tokopedia', 'icon': Icons.shopping_bag, 'fee': 4.5, 'color': Color(0xFF03AC0E)},
    {'id': 'shopee', 'name': 'Shopee', 'icon': Icons.storefront, 'fee': 5.0, 'color': Color(0xFFEE4D2D)},
    {'id': 'gofood', 'name': 'GoFood', 'icon': Icons.delivery_dining, 'fee': 20.0, 'color': Color(0xFF00AA13)},
    {'id': 'grabfood', 'name': 'GrabFood', 'icon': Icons.fastfood, 'fee': 20.0, 'color': Color(0xFF00B14F)},
    {'id': 'shopeefood', 'name': 'ShopeeFood', 'icon': Icons.lunch_dining, 'fee': 20.0, 'color': Color(0xFFEE4D2D)},
    {'id': 'tiktok_shop', 'name': 'TikTok Shop', 'icon': Icons.music_note, 'fee': 6.0, 'color': Color(0xFF000000)},
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final user = ref.read(currentUserProvider);
    if (user?.outletId == null) return;
    setState(() => _isLoading = true);
    final data = await _service.getProducts(user!.outletId!);
    setState(() {
      _products = data;
      _isLoading = false;
    });
  }

  void _openManualTxDialog(Map<String, dynamic> channel) {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada data produk untuk input transaksi')),
      );
      return;
    }

    Product selectedProduct = _products.first;
    int quantity = 1;
    double customPrice = selectedProduct.price;
    double platformFeePercent = (channel['fee'] as num).toDouble();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final totalAmount = customPrice * quantity;
          final platformFee = totalAmount * (platformFeePercent / 100);
          final netRevenue = totalAmount - platformFee;

          return AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: Text('Input Transaksi ${channel['name']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<Product>(
                    initialValue: selectedProduct,
                    decoration: const InputDecoration(labelText: 'Pilih Produk'),
                    items: _products.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text('${p.name} (Stok: ${p.stock})'),
                      );
                    }).toList(),
                    onChanged: (p) {
                      if (p != null) {
                        setDialogState(() {
                          selectedProduct = p;
                          customPrice = p.price;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: '$quantity',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Jumlah (Qty)'),
                          onChanged: (val) {
                            setDialogState(() {
                              quantity = int.tryParse(val) ?? 1;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: customPrice.toStringAsFixed(0),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Harga Satuan'),
                          onChanged: (val) {
                            setDialogState(() {
                              customPrice = double.tryParse(val) ?? selectedProduct.price;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Resi / Order ID',
                      hintText: 'Misal: INV/2026/TKP/12345',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Bruto: ${Formatters.currency(totalAmount)}'),
                        Text('Potongan Platform (${platformFeePercent.toStringAsFixed(1)}%): -${Formatters.currency(platformFee)}',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        const Divider(),
                        Text(
                          'Pendapatan Bersih: ${Formatters.currency(netRevenue)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (quantity > selectedProduct.stock) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Stok tidak cukup! Tersisa ${selectedProduct.stock}')),
                    );
                    return;
                  }

                  final user = ref.read(currentUserProvider);
                  if (user?.outletId == null) return;

                  final tx = Transaction(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    outletId: user!.outletId!,
                    cashierId: user.id,
                    items: [
                      TransactionItem(
                        productId: selectedProduct.id,
                        productName: selectedProduct.name,
                        price: customPrice,
                        quantity: quantity,
                        subtotal: totalAmount,
                      ),
                    ],
                    totalAmount: totalAmount,
                    discountAmount: platformFee,
                    taxAmount: 0,
                    finalAmount: netRevenue,
                    paymentMethod: channel['id'] as String,
                    paymentStatus: 'paid',
                    channel: channel['id'] as String,
                    notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                    createdAt: DateTime.now(),
                  );

                  await _service.createTransaction(tx);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadProducts();

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Transaksi ${channel['name']} berhasil dicatat & stok berkurang'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                },
                child: const Text('Simpan Transaksi'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Sinkronisasi Social Commerce'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hub, color: AppTheme.accentColor, size: 30),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Catat pesanan dari berbagai marketplace & online delivery. Stok akan otomatis berkurang dan pendapatan bersih tercatat rapi di laporan.',
                            style: TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Pilih Channel Penjualan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _channels.length,
                    itemBuilder: (context, index) {
                      final c = _channels[index];
                      final isSelected = _selectedChannel == c['id'];

                      return InkWell(
                        onTap: () {
                          setState(() => _selectedChannel = c['id'] as String);
                          _openManualTxDialog(c);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppTheme.accentColor : AppTheme.borderColor.withValues(alpha: 0.5),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: (c['color'] as Color).withValues(alpha: 0.2),
                                    child: Icon(c['icon'] as IconData, color: c['color'] as Color),
                                  ),
                                  Text(
                                    'Fee ${c['fee']}%',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['name'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    '+ Catat Pesanan',
                                    style: TextStyle(fontSize: 12, color: AppTheme.accentColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
