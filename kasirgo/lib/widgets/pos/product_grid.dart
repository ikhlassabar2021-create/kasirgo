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
        child: Text(
          'Tidak ada produk',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return GridView.builder(
      padding: padding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
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

  @override
  Widget build(BuildContext context) {
    final stockLow = product.stock <= 5;
    final outOfStock = product.stock <= 0;

    return GestureDetector(
      onTap: outOfStock ? null : onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: outOfStock
                      ? AppTheme.errorColor.withValues(alpha: 0.1)
                      : AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: outOfStock
                      ? AppTheme.errorColor.withValues(alpha: 0.5)
                      : AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: outOfStock ? AppTheme.textSecondary : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Formatters.currency(product.price),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: outOfStock
                      ? AppTheme.textSecondary
                      : AppTheme.primaryColor,
                ),
              ),
              if (stockLow && !outOfStock)
                Text(
                  'Stok: ${product.stock}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.warningColor,
                  ),
                ),
              if (outOfStock)
                const Text(
                  'Habis',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.errorColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}