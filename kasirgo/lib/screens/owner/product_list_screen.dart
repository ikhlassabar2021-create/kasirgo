import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_db_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

/// Katalog produk offline-first: online -> Supabase + cache SQLite;
/// offline -> baca cache SQLite (stok terakhir termasuk hasil penjualan offline).
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user?.outletId == null) return [];
  final outletId = user!.outletId!;
  final db = LocalDatabase.shared;
  final dbReady = await db.ensureInitialized();

  Future<List<Product>> readCache() async {
    if (!dbReady) return [];
    return db.getAllProducts(outletId);
  }

  try {
    final conn = await Connectivity().checkConnectivity();
    final online = conn.isNotEmpty && !conn.contains(ConnectivityResult.none);
    if (!online) return await readCache();

    final products = await SupabaseService().getProducts(outletId);
    if (dbReady && products.isNotEmpty) {
      try {
        db.batchInsertProducts(products);
      } catch (_) {}
    }
    if (products.isEmpty) {
      // Supabase bisa gagal dalam (getProducts menelan error) -> pakai cache.
      final cached = await readCache();
      if (cached.isNotEmpty) return cached;
    }
    return products;
  } catch (_) {
    return await readCache();
  }
});

class ProductListScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const ProductListScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showBarcodeScanDialog() {
    final barcodeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Scan Barcode'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: barcodeController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Arahkan scanner atau ketik barcode...',
                prefixIcon: Icon(Icons.barcode_reader, color: AppTheme.textSecondary),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                    _searchController.text = val.trim();
                  });
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Icon(Icons.close_rounded, size: 20),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              final val = barcodeController.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                  _searchController.text = val;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Cari'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(Product product) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.errorColor, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Hapus Produk',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            IconButton(
              tooltip: 'Tutup',
              icon: const Icon(Icons.close_rounded,
                  color: AppTheme.textSecondary),
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
        content: Text('Yakin ingin menghapus "${product.name}"?'),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: const Text('Hapus',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStockBadge(int stock, String? unit) {
    Color bg;
    Color text;
    String label;

    if (stock <= 0) {
      bg = AppTheme.errorColor.withValues(alpha: 0.18);
      text = AppTheme.errorColor;
      label = 'Habis (0)';
    } else if (stock <= 5) {
      bg = AppTheme.warningColor.withValues(alpha: 0.18);
      text = AppTheme.warningColor;
      label = 'Stok: $stock';
    } else {
      bg = AppTheme.successColor.withValues(alpha: 0.18);
      text = AppTheme.successColor;
      label = 'Stok: $stock ${unit ?? "pcs"}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProductImage(Product product) {
    if (!kIsWeb && product.imageLocalPath != null && product.imageLocalPath!.isNotEmpty) {
      final file = File(product.imageLocalPath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Image.file(
            file,
            width: double.infinity,
            height: 110,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          ),
        );
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppTheme.primaryColor,
        size: 38,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: productsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
            error: (err, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Gagal memuat produk\n${err.toString()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(productsProvider),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
            data: (products) {
              final categories = {'Semua', ...products.map((p) => p.category ?? 'Umum').where((c) => c.isNotEmpty)};

              final filtered = products.where((p) {
                final matchesSearch = _searchQuery.isEmpty ||
                    p.name.toLowerCase().contains(_searchQuery) ||
                    (p.barcode != null && p.barcode!.toLowerCase().contains(_searchQuery));
                final matchesCategory = _selectedCategory == 'Semua' || (p.category ?? 'Umum') == _selectedCategory;
                return matchesSearch && matchesCategory;
              }).toList();

              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                            decoration: InputDecoration(
                              hintText: 'Cari produk atau barcode...',
                              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: _showBarcodeScanDialog,
                          tooltip: 'Scan Barcode',
                          icon: const Icon(Icons.qr_code_scanner),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final cat = categories.elementAt(idx);
                        final isSelected = _selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 12,
                          ),
                          backgroundColor: AppTheme.surfaceColor,
                          onSelected: (val) {
                            setState(() => _selectedCategory = cat);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inventory, size: 48, color: AppTheme.textSecondary),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty || _selectedCategory != 'Semua'
                                    ? 'Tidak ada produk yang cocok'
                                    : 'Belum ada produk',
                                style: const TextStyle(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => ref.invalidate(productsProvider),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final crossAxisCount = width >= 1000
                                  ? 5
                                  : width >= 760
                                      ? 4
                                      : width >= 520
                                          ? 3
                                          : 2;
                              return GridView.builder(
                                padding: const EdgeInsets.fromLTRB(12, 6, 12, 80),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: 0.95,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final product = filtered[index];
                                  final canDelete = ref.watch(currentUserProvider)?.role == 'owner';

                                  final cardContent = Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: AppTheme.borderColor,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => context.push('/owner/products/add', extra: product),
                                  child: Stack(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: SizedBox(
                                              width: double.infinity,
                                              child: _buildProductImage(product),
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
                                                    product.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        Formatters.currency(product.price),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppTheme.accentColor,
                                                        ),
                                                      ),
                                                      _buildStockBadge(product.stock, product.unit),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (canDelete)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: InkWell(
                                              onTap: () async {
                                                final confirm = await _confirmDelete(product);
                                                if (confirm == true && context.mounted) {
                                                  final success = await SupabaseService().deleteProduct(product.id);
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        success
                                                            ? '${product.name} berhasil dihapus'
                                                            : 'Gagal menghapus ${product.name}. Coba lagi.',
                                                      ),
                                                      backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
                                                    ),
                                                  );
                                                  ref.invalidate(productsProvider);
                                                }
                                              },
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.9),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.1),
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(Icons.delete_outline, size: 16, color: AppTheme.errorColor),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                              return cardContent;
                                },
                              );
                            },
                          ),
                        ),
                  ),
                ],
              );
            },
          ),
        ),
      );

    if (widget.embedded) {
      return Stack(
        children: [
          content,
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'fab_products_embedded',
              onPressed: () => context.push('/owner/products/add'),
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Tambah', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Barcode',
            onPressed: _showBarcodeScanDialog,
          ),
        ],
      ),
      body: content,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_products',
        onPressed: () => context.push('/owner/products/add'),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }
}
