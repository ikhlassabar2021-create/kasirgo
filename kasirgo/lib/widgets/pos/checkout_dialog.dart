import 'package:flutter/material.dart';

class CheckoutDialog extends StatefulWidget {
  final double total;
  final Function(String paymentMethod) onConfirm;
  const CheckoutDialog({super.key, required this.total, required this.onConfirm});

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  String _paymentMethod = 'cash';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1B4B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Checkout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total: Rp ${widget.total.toStringAsFixed(0)}', style: TextStyle(color: const Color(0xFF06B6D4), fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Text('Metode Pembayaran', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            dropdownColor: const Color(0xFF1E1B4B),
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
            ),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Tunai')),
              DropdownMenuItem(value: 'qris', child: Text('QRIS')),
              DropdownMenuItem(value: 'bank_transfer', child: Text('Transfer Bank')),
            ],
            onChanged: (v) => setState(() => _paymentMethod = v!),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          onPressed: () { Navigator.pop(context); widget.onConfirm(_paymentMethod); },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text('Konfirmasi', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}