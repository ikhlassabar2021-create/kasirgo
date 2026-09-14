import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../utils/formatters.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<Product> onTap;
  final EdgeInsetsGeometry padding;

  const ProductGrid({
    super.key,
    required this.products,
    required this.onTap,
    this.padding = const EdgeInsets.all(8),
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text(
              'Tidak ada produk ditemukan',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: padding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.76,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductCard(product: product, onTap: () => onTap(product));
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  Widget _buildThumbnail() {
    final path = product.imageLocalPath;
    if (path != null && path.isNotEmpty) {
      if (kIsWeb) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 52,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      } else {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 52,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        }
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 52,
      width: double.infinity,
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: const Icon(
        Icons.inventory_2,
        color: AppTheme.primaryColor,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stockLow = product.stock > 0 && product.stock <= 5;
    final outOfStock = product.stock <= 0;

    return InkWell(
      onTap: outOfStock ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: outOfStock
                ? AppTheme.errorColor.withValues(alpha: 0.3)
                : AppTheme.borderColor.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: outOfStock ? AppTheme.textSecondary : Colors.white,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Formatters.currency(product.price),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: outOfStock
                                ? AppTheme.textSecondary
                                : AppTheme.accentColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (outOfStock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Habis',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else if (stockLow)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Sisa ${product.stock}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          Text(
                            'Stok: ${product.stock}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
