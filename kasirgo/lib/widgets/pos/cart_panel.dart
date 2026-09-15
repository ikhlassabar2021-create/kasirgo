import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/transaction.dart';

class CartPanel extends StatelessWidget {
  final List<TransactionItem> items;
  final VoidCallback onCheckout;
  final Function(int index) onRemoveItem;
  final Function(MapEntry<String, int> entry) onUpdateQty;
  final double discountAmount;
  final VoidCallback? onApplyDiscount;

  const CartPanel({
    super.key,
    required this.items,
    required this.onCheckout,
    required this.onRemoveItem,
    required this.onUpdateQty,
    this.discountAmount = 0.0,
    this.onApplyDiscount,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.subtotal);
  double get total => (subtotal - discountAmount).clamp(0.0, double.infinity);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.32,
      minChildSize: 0.20,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.20, 0.50, 0.88],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                height: 4,
                width: 36,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Keranjang (${items.length})',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rp ${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppTheme.borderColor, height: 1),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          'Keranjang masih kosong',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        separatorBuilder: (context, index) => const Divider(color: AppTheme.borderColor, height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Rp ${item.price.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppTheme.textSecondary),
                                      onPressed: () {
                                        if (item.quantity > 1) {
                                          onUpdateQty(MapEntry(item.productId, item.quantity - 1));
                                        } else {
                                          onRemoveItem(index);
                                        }
                                      },
                                    ),
                                    Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.primaryColor),
                                      onPressed: () {
                                        onUpdateQty(MapEntry(item.productId, item.quantity + 1));
                                      },
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  width: 75,
                                  child: Text(
                                    'Rp ${item.subtotal.toStringAsFixed(0)}',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border: Border(top: BorderSide(color: AppTheme.borderColor)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (discountAmount > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Diskon', style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                              Text('- Rp ${discountAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                            ],
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Rp ${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppTheme.accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: items.isEmpty ? null : onCheckout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Checkout',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
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
    );
  }
}
