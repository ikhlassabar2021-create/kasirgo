import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/transaction.dart';
import '../../utils/formatters.dart';

class CartPanel extends StatefulWidget {
  final List<TransactionItem> items;
  final VoidCallback onCheckout;
  final ValueChanged<int> onRemoveItem;
  final ValueChanged<MapEntry<String, int>> onUpdateQty;
  final double discountAmount;
  final ValueChanged<double>? onUpdateDiscount;
  final bool readOnly;

  const CartPanel({
    super.key,
    required this.items,
    required this.onCheckout,
    required this.onRemoveItem,
    required this.onUpdateQty,
    this.discountAmount = 0.0,
    this.onUpdateDiscount,
    this.readOnly = false,
  });

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  bool _isExpanded = false;

  double get _subtotal =>
      widget.items.fold(0.0, (sum, item) => sum + item.subtotal);

  double get _finalTotal =>
      (_subtotal - widget.discountAmount).clamp(0.0, double.infinity);

  int get _totalItemCount =>
      widget.items.fold(0, (sum, item) => sum + item.quantity);

  void _showDiscountDialog() {
    final controller = TextEditingController(
      text: widget.discountAmount > 0
          ? widget.discountAmount.toStringAsFixed(0)
          : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.discount_outlined, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Potongan / Diskon', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nominal Diskon (Rp)',
                prefixIcon: Icon(Icons.money_off),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [5000, 10000, 15000, 20000].map((nominal) {
                return ActionChip(
                  label: Text(Formatters.currency(nominal.toDouble())),
                  onPressed: () {
                    controller.text = nominal.toString();
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onUpdateDiscount?.call(0.0);
              Navigator.pop(ctx);
            },
            child: const Text('Hapus Diskon', style: TextStyle(color: AppTheme.errorColor)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim()) ?? 0.0;
              widget.onUpdateDiscount?.call(val);
              Navigator.pop(ctx);
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(
            top: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.4)),
          ),
        ),
        child: const SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, color: AppTheme.textSecondary, size: 20),
              SizedBox(width: 8),
              Text(
                'Keranjang masih kosong. Pilih produk di atas.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle & toggle header
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_bag, color: AppTheme.primaryColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Keranjang ($_totalItemCount item)',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${widget.items.length} jenis produk',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Formatters.currency(_finalTotal),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Expanded Item List
            if (_isExpanded)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.borderColor),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${Formatters.currency(item.price)} x ${item.quantity}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            Formatters.currency(item.subtotal),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          if (!widget.readOnly) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                if (item.quantity > 1) {
                                  widget.onUpdateQty(MapEntry(item.productId, item.quantity - 1));
                                } else {
                                  widget.onRemoveItem(index);
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.borderColor),
                                ),
                                child: const Icon(Icons.remove, size: 14, color: AppTheme.errorColor),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                widget.onUpdateQty(MapEntry(item.productId, item.quantity + 1));
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add, size: 14, color: AppTheme.primaryColor),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Calculation Breakdown & Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  if (_isExpanded) ...[
                    const Divider(color: AppTheme.borderColor),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text(Formatters.currency(_subtotal), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: widget.readOnly ? null : _showDiscountDialog,
                          child: Row(
                            children: [
                              const Icon(Icons.discount, size: 14, color: AppTheme.primaryColor),
                              const SizedBox(width: 4),
                              Text(
                                widget.discountAmount > 0 ? 'Diskon (Ubah)' : '+ Tambah Diskon',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.discountAmount > 0)
                          Text(
                            '-${Formatters.currency(widget.discountAmount)}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.errorColor, fontWeight: FontWeight.bold),
                          )
                        else
                          const Text('Rp0', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Bayar', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            Text(
                              Formatters.currency(_finalTotal),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: widget.onCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.payment, size: 18),
                            SizedBox(width: 8),
                            Text('Bayar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
