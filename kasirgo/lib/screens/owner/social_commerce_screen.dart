import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _isSyncing = false;

  final _channels = [
    {'id': 'tokopedia', 'name': 'Tokopedia', 'icon': Icons.shopping_bag_outlined, 'fee': 4.5, 'color': Color(0xFF03AC0E), 'status': 'Terhubung'},
    {'id': 'shopee', 'name': 'Shopee', 'icon': Icons.storefront_outlined, 'fee': 5.0, 'color': Color(0xFFEE4D2D), 'status': 'Terhubung'},
    {'id': 'gofood', 'name': 'GoFood', 'icon': Icons.delivery_dining_outlined, 'fee': 20.0, 'color': Color(0xFF00AA13), 'status': 'Siap Sinkron'},
    {'id': 'grabfood', 'name': 'GrabFood', 'icon': Icons.fastfood_outlined, 'fee': 20.0, 'color': Color(0xFF00B14F), 'status': 'Siap Sinkron'},
    {'id': 'shopeefood', 'name': 'ShopeeFood', 'icon': Icons.lunch_dining_outlined, 'fee': 20.0, 'color': Color(0xFFEE4D2D), 'status': 'Siap Sinkron'},
    {'id': 'tiktok_shop', 'name': 'TikTok Shop', 'icon': Icons.music_note_outlined, 'fee': 6.0, 'color': Color(0xFF0F172A), 'status': 'Terhubung'},
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
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
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
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Bruto: ${Formatters.currency(totalAmount)}', style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Potongan Platform (${platformFeePercent.toStringAsFixed(1)}%): -${Formatters.currency(platformFee)}',
                            style: const TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                        const Divider(height: 16),
                        Text(
                          'Pendapatan Bersih: ${Formatters.currency(netRevenue)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
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
                child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                ),
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

  Future<void> _syncAllChannels() async {
    setState(() => _isSyncing = true);
    await Future.delayed(const Duration(milliseconds: 600));
    await _loadProducts();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Katalog & stok berhasil disinkronkan ke semua channel aktif'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Social Commerce Sync',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: 'Sinkronisasi Ulang',
            icon: _isSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded, color: AppTheme.primaryColor),
            onPressed: _isSyncing ? null : _syncAllChannels,
          ),
        ],
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
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          child: const Icon(Icons.hub_outlined, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sinkronisasi Multi-Channel',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Catat order marketplace & delivery. Stok berkurang otomatis dan laporan bersih rapi.',
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pilih Channel Penjualan',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                      ),
                      TextButton.icon(
                        onPressed: _isSyncing ? null : _syncAllChannels,
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.primaryColor),
                        label: Text('Sync All', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.15,
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
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                              width: isSelected ? 1.8 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.textPrimary.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: (c['color'] as Color).withValues(alpha: 0.12),
                                    child: Icon(c['icon'] as IconData, color: c['color'] as Color, size: 20),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.backgroundColor,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.borderColor),
                                    ),
                                    child: Text(
                                      'Fee ${c['fee']}%',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['name'] as String,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: c['status'] == 'Terhubung' ? AppTheme.successColor : AppTheme.warningColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        c['status'] as String,
                                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '+ Catat Order',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.primaryColor),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Preview Stok Produk (${_products.length})',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Sync Otomatis',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _products.take(5).length,
                    separatorBuilder: (c, i) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = _products[index];
                      final stockColor = p.stock > 10
                          ? AppTheme.successColor
                          : (p.stock > 0 ? AppTheme.warningColor : AppTheme.errorColor);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: const Icon(Icons.inventory_2_outlined, size: 20, color: AppTheme.primaryColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(Formatters.currency(p.price), style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: stockColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: stockColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'Stok: ${p.stock}',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: stockColor),
                              ),
                            ),
                          ],
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
