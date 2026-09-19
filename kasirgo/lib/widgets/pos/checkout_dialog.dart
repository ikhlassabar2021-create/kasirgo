import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_theme.dart';
import '../../models/transaction.dart';
import '../../utils/wa_helper.dart';

class CheckoutResult {
  final String paymentMethod;
  final double amount;
  final double change;
  final double cashPaid;
  final String? notes;
  final bool sendWhatsApp;

  const CheckoutResult({
    required this.paymentMethod,
    required this.amount,
    required this.change,
    required this.cashPaid,
    this.notes,
    this.sendWhatsApp = false,
  });
}

class CheckoutDialog extends StatefulWidget {
  final List<TransactionItem> items;
  final double totalAmount;
  final Function({
    required String paymentMethod,
    String? notes,
    required double finalAmount,
    String? customerId,
  })? onConfirm;

  const CheckoutDialog({
    super.key,
    required this.items,
    required this.totalAmount,
    this.onConfirm,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  String _paymentMethod = 'cash';
  final _cashController = TextEditingController();
  final _qrisAmountController = TextEditingController();
  final _notesController = TextEditingController();
  final _customerWaController = TextEditingController();
  bool _sendWaReceipt = false;

  double get _cashPaid => double.tryParse(_cashController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
  double get _change => (_cashPaid - widget.totalAmount).clamp(0.0, double.infinity);

  @override
  void initState() {
    super.initState();
    _cashController.text = widget.totalAmount.toStringAsFixed(0);
    _qrisAmountController.text = widget.totalAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _cashController.dispose();
    _qrisAmountController.dispose();
    _notesController.dispose();
    _customerWaController.dispose();
    super.dispose();
  }

  void _setCash(double amount) {
    setState(() {
      _cashController.text = amount.toStringAsFixed(0);
    });
  }

  void _submit() {
    if (_paymentMethod == 'cash' && _cashPaid < widget.totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uang tunai kurang dari total pembayaran'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final result = CheckoutResult(
      paymentMethod: _paymentMethod,
      amount: widget.totalAmount,
      change: _paymentMethod == 'cash' ? _change : 0.0,
      cashPaid: _paymentMethod == 'cash' ? _cashPaid : widget.totalAmount,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      sendWhatsApp: _sendWaReceipt,
    );

    if (_sendWaReceipt && _customerWaController.text.trim().isNotEmpty) {
      final dummyTx = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        outletId: 'current',
        items: widget.items,
        totalAmount: widget.totalAmount,
        finalAmount: widget.totalAmount,
        paymentMethod: _paymentMethod,
        createdAt: DateTime.now(),
      );
      final msg = WaHelper.formatReceiptMessage(
        storeName: 'KasirGo Store',
        transaction: dummyTx,
      );
      WaHelper.sendWhatsAppMessage(
        phone: _customerWaController.text.trim(),
        message: msg,
      );
    }

    if (widget.onConfirm != null) {
      widget.onConfirm!(
        paymentMethod: _paymentMethod,
        notes: result.notes,
        finalAmount: widget.totalAmount,
      );
    }

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pembayaran',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Tagihan',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${widget.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Metode Pembayaran',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildPaymentOption('cash', 'Tunai (Cash)', Icons.money),
              _buildPaymentOption('qris', 'QRIS Manual', Icons.qr_code_2),
              _buildPaymentOption('bank_transfer', 'Transfer Bank', Icons.account_balance),
              const Divider(color: AppTheme.borderColor, height: 24),
              if (_paymentMethod == 'cash') _buildCashSection(),
              if (_paymentMethod == 'qris') _buildQrisSection(),
              if (_paymentMethod == 'bank_transfer') _buildTransferSection(),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _sendWaReceipt,
                          activeColor: const Color(0xFF25D366),
                          onChanged: (val) {
                            setState(() => _sendWaReceipt = val ?? false);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Kirim Struk via WhatsApp',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.receipt_long, color: Color(0xFF25D366), size: 20),
                      ],
                    ),
                    if (_sendWaReceipt)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                          controller: _customerWaController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Nomor WhatsApp Pelanggan',
                            hintText: '0812xxxxxxxx',
                            prefixIcon: Icon(Icons.phone, size: 18),
                            isDense: true,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Catatan Transaksi (Opsional)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  hintText: 'Contoh: Meja 4 / Tanpa sambal',
                  hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Konfirmasi & Selesai',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String value, String label, IconData icon) {
    final isSelected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, size: 18, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildCashSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nominal Diterima',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _cashController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (text) => setState(() {}),
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            prefixText: 'Rp ',
            prefixStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ActionChip(
              label: const Text('Uang Pas', style: TextStyle(fontSize: 11)),
              onPressed: () => _setCash(widget.totalAmount),
            ),
            if (widget.totalAmount < 50000)
              ActionChip(
                label: const Text('50.000', style: TextStyle(fontSize: 11)),
                onPressed: () => _setCash(50000),
              ),
            if (widget.totalAmount < 100000)
              ActionChip(
                label: const Text('100.000', style: TextStyle(fontSize: 11)),
                onPressed: () => _setCash(100000),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kembalian', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              Text(
                'Rp ${_change.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrisSection() {
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.qr_code_2,
                  size: 140,
                  color: Colors.black,
                ),
                const SizedBox(height: 6),
                const Text(
                  'QRIS STANDAR PEMBAYARAN NASIONAL',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'NMID: ID1020038847291',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Scan QRIS Statis Merchant',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _qrisAmountController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: const InputDecoration(
            labelText: 'Nominal Verifikasi QRIS',
            prefixText: 'Rp ',
          ),
        ),
      ],
    );
  }

  Widget _buildTransferSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rekening Tujuan:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          SizedBox(height: 4),
          Text('BCA 8735091223 (KasirGo Outlet)', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
          SizedBox(height: 2),
          Text('Konfirmasi manual setelah mutasi masuk', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
