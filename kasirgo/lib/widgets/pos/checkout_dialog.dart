import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/transaction.dart';
import '../../utils/formatters.dart';

class CheckoutDialog extends StatefulWidget {
  final List<TransactionItem> items;
  final double totalAmount;
  final double? discountAmount;
  final void Function({
    required String paymentMethod,
    required String? notes,
    required double finalAmount,
    required String? customerId,
  }) onConfirm;

  const CheckoutDialog({
    super.key,
    required this.items,
    required this.totalAmount,
    this.discountAmount,
    required this.onConfirm,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  String _selectedPayment = 'Tunai';
  final _notesController = TextEditingController();

  double get _finalAmount =>
      widget.totalAmount - (widget.discountAmount ?? 0);

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Checkout',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: AppTheme.borderColor),
              Text(
                '${widget.items.length} item',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal'),
                  Text(Formatters.currency(widget.totalAmount)),
                ],
              ),
              if (widget.discountAmount != null && widget.discountAmount! > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Diskon',
                        style: TextStyle(color: AppTheme.successColor)),
                    Text(
                      '-${Formatters.currency(widget.discountAmount!)}',
                      style: const TextStyle(color: AppTheme.successColor),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              const Divider(color: AppTheme.borderColor),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    Formatters.currency(_finalAmount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Metode Pembayaran',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppConstants.paymentMethods.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final method = AppConstants.paymentMethods[index];
                    final isSelected = _selectedPayment == method;
                    return ChoiceChip(
                      label: Text(method),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedPayment = method);
                      },
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textPrimary,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onConfirm(
                      paymentMethod: _selectedPayment,
                      notes: _notesController.text.isEmpty
                          ? null
                          : _notesController.text,
                      finalAmount: _finalAmount,
                      customerId: null,
                    );
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Bayar ${Formatters.currency(_finalAmount)}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}