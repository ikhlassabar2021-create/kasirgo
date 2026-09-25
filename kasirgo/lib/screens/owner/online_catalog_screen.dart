import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _showControl = true;
  String _selectedCategory = 'Semua';
  final Set<String> _publishedIds = {};
  final Set<String> _thumbOptIn = {};

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
      for (final p in _products) {
        if (p.thumbKey != null) {
          _publishedIds.add(p.id);
          _thumbOptIn.add(p.id);
        }
      }
      _isLoading = false;
    });
  }

  void _orderViaWhatsApp(Product product) {
    const storePhone = '081234567890';
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
        title: Text(
          'Katalog Toko Online',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(_showControl ? Icons.visibility_outlined : Icons.tune_rounded, color: AppTheme.primaryColor),
            tooltip: 'Mode Kelola / Preview',
            onPressed: () => setState(() => _showControl = !_showControl),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppTheme.primaryColor),
            tooltip: 'Bagikan Link Katalog',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: catalogUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link katalog toko disalin ke clipboard!'), backgroundColor: AppTheme.successColor),
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
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Link Toko Online', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary)),
                            const SizedBox(height: 2),
                            Text(catalogUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.primaryColor),
                        label: Text('Salin', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: catalogUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link disalin!'), backgroundColor: AppTheme.successColor),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (_showControl) _buildControlPanel(),
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
                          label: Text(cat, style: GoogleFonts.inter(fontSize: 12)),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                          backgroundColor: AppTheme.surfaceColor,
                          side: BorderSide(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                          ),
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
                      ? Center(
                          child: Text(
                            'Belum ada produk untuk ditampilkan di katalog',
                            style: GoogleFonts.inter(color: AppTheme.textSecondary),
                          ),
                        )
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
                            final isPublished = _publishedIds.contains(p.id);

                            return Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                border: Border.all(color: isPublished ? AppTheme.primaryColor : AppTheme.borderColor),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Container(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                          child: const Icon(
                                            Icons.inventory_2_outlined,
                                            size: 28,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isPublished ? AppTheme.successColor : AppTheme.textSecondary,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 1.2),
                                            ),
                                          ),
                                        ),
                                      ],
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
                                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.textPrimary),
                                          ),
                                          Text(
                                            Formatters.currency(p.price),
                                            style: GoogleFonts.inter(
                                              color: AppTheme.primaryColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10.5,
                                            ),
                                          ),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 24,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.whatsAppColor,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: EdgeInsets.zero,
                                              ),
                                              icon: const Icon(Icons.chat_outlined, size: 12),
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

  Widget _buildControlPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Kontrol Publikasi Katalog',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
              ),
              const Spacer(),
              Text(
                '${_publishedIds.length}/${_products.length} publik',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Thumbnail online diunggah opt-in ke Cloudflare R2 (WebP) hanya untuk produk yang dipublikasikan.',
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 10),
          ..._products.take(4).map((p) {
            final isPublished = _publishedIds.contains(p.id);
            final isOptIn = _thumbOptIn.contains(p.id);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textPrimary)),
                        Text(
                          isPublished ? 'Publik + thumbnail R2' : 'Tidak dipublikasikan',
                          style: GoogleFonts.inter(fontSize: 10, color: isPublished ? AppTheme.successColor : AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isPublished,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      setState(() {
                        if (val) {
                          _publishedIds.add(p.id);
                          _thumbOptIn.add(p.id);
                        } else {
                          _publishedIds.remove(p.id);
                          _thumbOptIn.remove(p.id);
                        }
                      });
                    },
                  ),
                  Checkbox(
                    value: isOptIn,
                    activeColor: AppTheme.accentColor,
                    onChanged: isPublished
                        ? (val) => setState(() {
                              if (val == true) {
                                _thumbOptIn.add(p.id);
                              } else {
                                _thumbOptIn.remove(p.id);
                              }
                            })
                        : null,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
