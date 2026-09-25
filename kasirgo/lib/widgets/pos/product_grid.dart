import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../common/app_badge.dart';
import '../common/app_empty_state.dart';
import '../common/stock_badge.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<Product> onProductTap;
  final Map<String, int> cartQuantities;
  final Map<String, double>? customPrices;
  final Map<String, String>? discountBadges;
  final Map<String, double>? originalPrices;
  final double bottomPadding;

  const ProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.cartQuantities = const {},
    this.customPrices,
    this.discountBadges,
    this.originalPrices,
    this.bottomPadding = 220,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Produk tidak ditemukan',
        subtitle: 'Coba kata kunci lain atau tambahkan produk baru',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxis = 4;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(10, 10, 10, bottomPadding),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxis,
            childAspectRatio: 0.95,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => _ProductCard(
            product: products[index],
            inCartQty: cartQuantities[products[index].id] ?? 0,
            displayPrice: customPrices?[products[index].id] ?? products[index].price,
            originalPrice: originalPrices?[products[index].id],
            discountBadge: discountBadges?[products[index].id],
            onTap: onProductTap,
            buildImage: _buildImage,
          ),
        );
      },
    );
  }

  Widget _buildImage(String? path) {
    if (path != null && path.isNotEmpty) {
      final isRemote = path.startsWith('http://') ||
          path.startsWith('https://') ||
          path.startsWith('blob:') ||
          path.startsWith('data:');
      if (isRemote) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.inventory_2_rounded, color: AppTheme.textSecondary, size: 24),
        );
      }
      if (!kIsWeb) {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.inventory_2_rounded, color: AppTheme.textSecondary, size: 24),
          );
        }
      }
    }
    return const Icon(Icons.inventory_2_rounded, color: AppTheme.textSecondary, size: 24);
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final int inCartQty;
  final double displayPrice;
  final double? originalPrice;
  final String? discountBadge;
  final ValueChanged<Product> onTap;
  final Widget Function(String?) buildImage;

  const _ProductCard({
    required this.product,
    required this.inCartQty,
    required this.displayPrice,
    this.originalPrice,
    this.discountBadge,
    required this.onTap,
    required this.buildImage,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.stock <= 0;
    final hasInCart = inCartQty > 0;
    final hasDiscount = discountBadge != null && discountBadge!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: AppTheme.surfaceColor,
        child: InkWell(
          onTap: isOutOfStock ? null : () => onTap(product),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOutOfStock
                    ? AppTheme.errorColor.withValues(alpha: 0.3)
                    : hasInCart
                        ? AppTheme.accentColor
                        : AppTheme.borderColor,
                width: hasInCart ? 1.8 : 1,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        width: double.infinity,
                        color: AppTheme.primaryColor.withValues(alpha: 0.05),
                        child: Opacity(
                          opacity: isOutOfStock ? 0.4 : 1,
                          child: buildImage(product.imageLocalPath),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: AppTheme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (hasDiscount && originalPrice != null && originalPrice! > displayPrice) ...[
                              Row(
                                children: [
                                  Text(
                                    'Rp ${displayPrice.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.successColor,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Rp ${originalPrice!.toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(
                                        color: AppTheme.textSecondary,
                                        fontSize: 8.5,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                'Rp ${displayPrice.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  color: AppTheme.accentColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                            const SizedBox(height: 1),
                            Text(
                              isOutOfStock
                                  ? 'Habis'
                                  : 'Stok ${product.stock}',
                              style: GoogleFonts.inter(
                                color: product.stock <= 0
                                    ? AppTheme.errorColor
                                    : product.stock <= 10
                                        ? AppTheme.warningColor
                                        : AppTheme.successColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: hasDiscount
                        ? AppBadge(
                            label: discountBadge!,
                            variant: AppBadgeVariant.danger,
                            compact: true,
                          )
                        : StockBadge(stock: product.stock),
                  ),
                  if (hasInCart)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: AppTheme.accentColor.withValues(alpha: 0.4), blurRadius: 8),
                          ],
                        ),
                        child: Text(
                          '$inCartQty',
                          style: GoogleFonts.inter(
                            color: AppTheme.backgroundColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                if (isOutOfStock)
                  Positioned.fill(
                    child: Container(
                      color: AppTheme.scrimColor,
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          'STOK HABIS',
                          style: GoogleFonts.inter(
                            color: AppTheme.errorColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
