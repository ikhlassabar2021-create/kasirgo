import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<Product> onProductTap;
  final Map<String, int> cartQuantities;
  final Map<String, double>? customPrices;
  final Map<String, String>? discountBadges;
  final Map<String, double>? originalPrices;

  const ProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.cartQuantities = const {},
    this.customPrices,
    this.discountBadges,
    this.originalPrices,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada produk',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 220),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.70,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isOutOfStock = product.stock <= 0;
        final inCartQty = cartQuantities[product.id] ?? 0;
        final hasInCart = inCartQty > 0;
        final displayPrice = customPrices?[product.id] ?? product.price;
        final originalPrice = originalPrices?[product.id];
        final discountBadge = discountBadges?[product.id];
        final hasDiscount = discountBadge != null && discountBadge.isNotEmpty;

        return Material(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isOutOfStock ? null : () => onProductTap(product),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isOutOfStock
                      ? AppTheme.errorColor.withValues(alpha: 0.4)
                      : hasInCart
                          ? AppTheme.accentColor
                          : AppTheme.borderColor,
                  width: hasInCart ? 2 : 1,
                ),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: AppTheme.surfaceColor,
                          child: _buildImage(product.imageLocalPath),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (hasDiscount && originalPrice != null && originalPrice > displayPrice) ...[
                              Row(
                                children: [
                                  Text(
                                    'Rp ${displayPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: AppTheme.successColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Rp ${originalPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 9,
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
                                style: const TextStyle(
                                  color: AppTheme.accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              isOutOfStock ? 'Habis' : 'Stok: ${product.stock}',
                              style: TextStyle(
                                color: isOutOfStock ? AppTheme.errorColor : AppTheme.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (hasDiscount)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          discountBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (hasInCart)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$inCartQty',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.inventory_2, color: AppTheme.textSecondary, size: 24),
        );
      }
      if (!kIsWeb) {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.inventory_2, color: AppTheme.textSecondary, size: 24),
          );
        }
      }
    }
    return const Icon(Icons.inventory_2, color: AppTheme.textSecondary, size: 24);
  }
}
