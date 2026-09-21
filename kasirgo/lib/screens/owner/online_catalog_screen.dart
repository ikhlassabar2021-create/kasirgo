import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../utils/wa_helper.dart';

class OnlineCatalogScreen extends ConsumerStatefulWidget {
  const OnlineCatalogScreen({super.key});

  @override
  ConsumerState<OnlineCatalogScreen> createState() => _OnlineCatalogScreenState();
}

class _OnlineCatalogScreenState extends ConsumerState<OnlineCatalogScreen> {
  final _service = SupabaseService();
  List<Product> _products = [];
  bool _isLoading = true;
  String _selectedCategory = 'Semua';

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
      _products = data.where((p) => p.isActive).toList();
      _isLoading = false;
    });
  }

  void _orderViaWhatsApp(Product product) {
    const storePhone = '081234567890'; // Merchant phone number placeholder
    final message = 'Halo, saya ingin memesan:\n\n'
        '*${product.name}*\n'
        'Harga: ${Formatters.currency(product.price)}\n'
        'Jumlah: 1 pcs\n\n'
        'Apakah stok ini masih tersedia? Terima kasih.';

    WaHelper.sendWhatsAppMessage(phone: storePhone, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final catalogUrl = 'https://kasirgo.online/catalog/${user?.outletId ?? "toko"}';

    final categories = ['Semua', ...{..._products.map((p) => p.category ?? 'Umum')}];
    final filtered = _selectedCategory == 'Semua'
        ? _products
        : _products.where((p) => (p.category ?? 'Umum') == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Katalog Toko Online'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Bagikan Link Katalog',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: catalogUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link katalog toko disalin ke clipboard!')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppTheme.surfaceColor,
                  child: Row(
                    children: [
                      const Icon(Icons.link, color: AppTheme.accentColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          catalogUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Salin Link', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: catalogUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link disalin!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = cat == _selectedCategory;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _selectedCategory = cat);
                          },
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('Belum ada produk untuk ditampilkan di katalog'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 0.95,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final p = filtered[index];

                            return Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Container(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                      width: double.infinity,
                                      child: const Icon(
                                        Icons.inventory_2,
                                        size: 28,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text(
                                            p.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                          Text(
                                            Formatters.currency(p.price),
                                            style: const TextStyle(
                                              color: AppTheme.accentColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10.5,
                                            ),
                                          ),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 24,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF25D366),
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.zero,
                                              ),
                                              icon: const Icon(Icons.chat, size: 12),
                                              label: const Text('Pesan WA', style: TextStyle(fontSize: 10)),
                                              onPressed: () => _orderViaWhatsApp(p),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
