import 'package:flutter/material.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;
  CartItem({required this.id, required this.name, required this.price, this.quantity = 1});
  double get subtotal => price * quantity;
}

class CartPanel extends StatelessWidget {
  final List<CartItem> items;
  final VoidCallback onCheckout;
  final Function(int index) onRemove;
  final Function(int index, int qty) onUpdateQty;
  const CartPanel({super.key, required this.items, required this.onCheckout, required this.onRemove, required this.onUpdateQty});

  @override
  Widget build(BuildContext context) {
    final total = items.fold(0.0, (sum, item) => sum + item.subtotal);
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), border: Border.all(color: Colors.white.withOpacity(0.2))),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Keranjang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text('Belum ada item', style: TextStyle(color: Colors.white54)))
          else
            SizedBox(
              height: 150,
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  return ListTile(
                    dense: true,
                    title: Text(item.name, style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text('Rp ${item.price.toStringAsFixed(0)} x${item.quantity}', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.remove, size: 18, color: Colors.white), onPressed: () => onUpdateQty(i, item.quantity - 1)),
                        Text('${item.quantity}', style: TextStyle(color: Colors.white)),
                        IconButton(icon: const Icon(Icons.add, size: 18, color: Colors.white), onPressed: () => onUpdateQty(i, item.quantity + 1)),
                        IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), onPressed: () => onRemove(i)),
                      ],
                    ),
                  );
                },
              ),
            ),
          const Divider(color: Colors.white24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text('Rp ${total.toStringAsFixed(0)}', style: TextStyle(color: const Color(0xFF06B6D4), fontWeight: FontWeight.w700, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: items.isEmpty ? null : onCheckout,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Bayar', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}