import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/transaction.dart';

/// Isi keranjang murni (tanpa wrapper sheet) — dipakai di mobile sheet & tablet panel.
class CartContent extends StatelessWidget {
  final List<TransactionItem> items;
  final VoidCallback onCheckout;
  final Function(int index) onRemoveItem;
  final Function(MapEntry<String, int> entry) onUpdateQty;
  final double discountAmount;
  final ScrollController? scrollController;
  final bool showDragHandle;

  const CartContent({
    super.key,
    required this.items,
    required this.onCheckout,
    required this.onRemoveItem,
    required this.onUpdateQty,
    this.discountAmount = 0.0,
    this.scrollController,
    this.showDragHandle = true,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.subtotal);
  double get total => (subtotal - discountAmount).clamp(0.0, double.infinity);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Column(
            children: [
              if (showDragHandle)
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shopping_cart_rounded, color: AppTheme.accentColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Keranjang',
                          style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _CartCountPill(count: items.length),
                      ],
                    ),
                    _MoneyInline(value: total, size: 17),
                  ],
                ),
              ),
              Divider(height: 1, color: AppTheme.borderColor),
              Expanded(
                child: items.isEmpty
                    ? const _EmptyCart()
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _CartItemRow(
                            item: item,
                            onMinus: () {
                              if (item.quantity > 1) {
                                onUpdateQty(MapEntry(item.productId, item.quantity - 1));
                              } else {
                                onRemoveItem(index);
                              }
                            },
                            onPlus: () => onUpdateQty(MapEntry(item.productId, item.quantity + 1)),
                          );
                        },
                      ),
              ),
              _CheckoutBar(
                discountAmount: discountAmount,
                total: total,
                enabled: items.isNotEmpty,
                onCheckout: onCheckout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CartPanel extends StatelessWidget {
  final List<TransactionItem> items;
  final VoidCallback onCheckout;
  final Function(int index) onRemoveItem;
  final Function(MapEntry<String, int> entry) onUpdateQty;
  final double discountAmount;

  const CartPanel({
    super.key,
    required this.items,
    required this.onCheckout,
    required this.onRemoveItem,
    required this.onUpdateQty,
    this.discountAmount = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.34,
      minChildSize: 0.22,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.22, 0.5, 0.9],
      builder: (context, scrollController) {
        return CartContent(
          items: items,
          onCheckout: onCheckout,
          onRemoveItem: onRemoveItem,
          onUpdateQty: onUpdateQty,
          discountAmount: discountAmount,
          scrollController: scrollController,
        );
      },
    );
  }
}

class _CartCountPill extends StatelessWidget {
  final int count;
  const _CartCountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: AppTheme.accentColor, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: AppTheme.textSecondary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            'Keranjang masih kosong',
            style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            'Tap produk untuk menambahkan',
            style: GoogleFonts.inter(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final TransactionItem item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _CartItemRow({required this.item, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp ${item.price.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          _QtyButton(icon: Icons.remove_rounded, onTap: onMinus),
          SizedBox(
            width: 30,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          _QtyButton(icon: Icons.add_rounded, onTap: onPlus, primary: true),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            child: _MoneyInline(value: item.subtotal, size: 12.5, bold: true),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _QtyButton({required this.icon, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: primary
            ? AppTheme.primaryColor.withValues(alpha: 0.2)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Icon(
            icon,
            size: 18,
            color: primary ? AppTheme.accentColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  final double discountAmount;
  final double total;
  final bool enabled;
  final VoidCallback onCheckout;

  const _CheckoutBar({
    required this.discountAmount,
    required this.total,
    required this.enabled,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Diskon', style: GoogleFonts.inter(color: AppTheme.errorColor, fontSize: 12)),
                    Text('- Rp ${discountAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(color: AppTheme.errorColor, fontSize: 12)),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'TOTAL',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
                _MoneyInline(value: total, size: 24, color: AppTheme.accentColor),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: enabled ? onCheckout : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.borderColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Bayar Sekarang',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
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

class _MoneyInline extends StatelessWidget {
  final double value;
  final double size;
  final Color color;
  final bool bold;

  const _MoneyInline({
    required this.value,
    required this.size,
    this.color = AppTheme.textPrimary,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'Rp ${value.toStringAsFixed(0)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: GoogleFonts.inter(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w800,
        letterSpacing: -0.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
