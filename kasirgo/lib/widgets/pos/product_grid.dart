import 'package:flutter/material.dart';
import '../../models/product.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onTap;
  const ProductGrid({super.key, required this.products, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.85, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: products.length,
      itemBuilder: (ctx, i) {
        final p = products[i];
        return GestureDetector(
          onTap: () => onTap(p),
          child: Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.2))),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag, color: const Color(0xFF06B6D4).withOpacity(0.8), size: 28),
                const SizedBox(height: 4),
                Text(p.name, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text('Rp ${p.basePrice.toStringAsFixed(0)}', style: TextStyle(color: const Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.w600)),
                Text('Stok: ${p.stock.toStringAsFixed(0)}', style: TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        );
      },
    );
  }
}