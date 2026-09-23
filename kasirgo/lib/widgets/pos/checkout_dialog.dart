import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/transaction.dart';
import '../../services/payment_service.dart';
import '../../utils/wa_helper.dart';

class CheckoutResult {
  final String paymentMethod;
  final double amount;
  final double change;
  final double cashPaid;
  final double tipAmount;
  final String? notes;
  final bool sendWhatsApp;

  const CheckoutResult({
    required this.paymentMethod,
    required this.amount,
    required this.change,
    required this.cashPaid,
    this.tipAmount = 0.0,
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
  String _qrisMode = 'static'; // static | dynamic
  final _cashController = TextEditingController();
  final _qrisAmountController = TextEditingController();
  final _tipController = TextEditingController();
  final _notesController = TextEditingController();
  final _customerWaController = TextEditingController();
  bool _sendWaReceipt = false;
  bool _isLoadingQris = false;

  double get _tipAmount => double.tryParse(_tipController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
  double get _grandTotal => widget.totalAmount + _tipAmount;
  double get _cashPaid => double.tryParse(_cashController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
  double get _change => (_cashPaid - _grandTotal).clamp(0.0, double.infinity);

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
    _tipController.dispose();
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
    if (_paymentMethod == 'cash' && _cashPaid < _grandTotal) {
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
      amount: _grandTotal,
      change: _paymentMethod == 'cash' ? _change : 0.0,
      cashPaid: _paymentMethod == 'cash' ? _cashPaid : _grandTotal,
      tipAmount: _tipAmount,
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildTotalCard(),
                          const SizedBox(height: 18),
                          Text(
                            'Metode Pembayaran',
                            style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildPaymentOption('cash', 'Tunai (Cash)', Icons.payments_rounded),
                          _buildPaymentOption('qris', 'QRIS Manual', Icons.qr_code_2_rounded),
                          if (_paymentMethod == 'qris') ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Mode QRIS:',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => setState(() => _qrisMode = 'static'),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              decoration: BoxDecoration(
                                                color: _qrisMode == 'static'
                                                    ? AppTheme.primaryColor.withValues(alpha: 0.25)
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: _qrisMode == 'static'
                                                      ? AppTheme.primaryColor
                                                      : AppTheme.borderColor,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'Statis',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: _qrisMode == 'static'
                                                        ? AppTheme.accentColor
                                                        : AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => setState(() => _qrisMode = 'dynamic'),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              decoration: BoxDecoration(
                                                color: _qrisMode == 'dynamic'
                                                    ? AppTheme.primaryColor.withValues(alpha: 0.25)
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: _qrisMode == 'dynamic'
                                                      ? AppTheme.primaryColor
                                                      : AppTheme.borderColor,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'Dinamis',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: _qrisMode == 'dynamic'
                                                        ? AppTheme.accentColor
                                                        : AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          _buildPaymentOption('bank_transfer', 'Transfer Bank', Icons.account_balance_rounded),
                          const SizedBox(height: 14),
                          if (_paymentMethod == 'cash') _buildCashSection(),
                          if (_paymentMethod == 'qris') _buildQrisSection(mode: _qrisMode),
                          if (_paymentMethod == 'bank_transfer') _buildTransferSection(),
                          const SizedBox(height: 16),
                          _buildWaReceiptSection(),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _tipController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Tip Tambahan / Sukarela (Opsional)',
                              labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              hintText: 'Contoh: 5000',
                              prefixText: 'Rp ',
                              prefixIcon: Icon(Icons.volunteer_activism_rounded, color: AppTheme.primaryColor, size: 20),
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
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Konfirmasi & Selesai',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppTheme.accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Pembayaran',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.35),
            AppTheme.secondaryColor.withValues(alpha: 0.22),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL TAGIHAN',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rp ${widget.totalAmount.toStringAsFixed(0)}',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, String label, IconData icon) {
    final isSelected = _paymentMethod == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.15) : AppTheme.backgroundColor.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: isSelected ? AppTheme.accentColor : AppTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, size: 20, color: AppTheme.accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nominal Diterima',
          style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _cashController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (text) => setState(() {}),
          style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
          decoration: const InputDecoration(
            prefixText: 'Rp ',
            prefixStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QuickAmountChip(label: 'Uang Pas', onTap: () => _setCash(_grandTotal)),
            if (_grandTotal < 50000)
              _QuickAmountChip(label: '50.000', onTap: () => _setCash(50000)),
            if (_grandTotal < 100000)
              _QuickAmountChip(label: '100.000', onTap: () => _setCash(100000)),
            if (_grandTotal < 200000)
              _QuickAmountChip(label: '200.000', onTap: () => _setCash(200000)),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Kembalian', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
              Text(
                'Rp ${_change.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrisSection({required String mode}) {
    if (mode == 'static') {
      return Column(children: _buildStaticQris());
    } else {
      return _buildDynamicQris();
    }
  }

  List<Widget> _buildStaticQris() {
    return [
      Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(Icons.qr_code_2_rounded, size: 140, color: Colors.black),
              const SizedBox(height: 6),
              const Text(
                'QRIS STANDAR PEMBAYARAN NASIONAL',
                style: TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.bold),
              ),
              Text(
                'NMID: ID1020038847291',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 8),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Scan QRIS Statis Merchant',
        style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12),
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
      const SizedBox(height: 8),
      Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.accentColor, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Masukkan nominal setelah customer scan dan transfer',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildDynamicQris() {
    if (_isLoadingQris) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.accentColor),
            ),
            const SizedBox(height: 10),
            Text('Membuat QR dinamis...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    final paymentService = PaymentService();
    final config = paymentService.getFinancialConfig();
    final amount = double.tryParse(_qrisAmountController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? widget.totalAmount;
    
    if (amount < config['min_payment'] || amount > config['max_payment']) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Nominal harus antara Rp ${config['min_payment'].toStringAsFixed(0)} - Rp ${config['max_payment'].toStringAsFixed(0)}',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.errorColor, fontSize: 12),
          ),
        ),
      );
    }

    if (amount >= config['free_threshold']) {
      // Auto-pay untuk free payment threshold
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 32),
            const SizedBox(height: 8),
            const Text(
              'Pembayaran Gratis!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text('Ambil alih dari tombol Konfirmasi', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
           onTap: () async {
             try {
               setState(() => _isLoadingQris = true);
               
               await paymentService.createCharge(
                 orderId: DateTime.now().millisecondsSinceEpoch.toString(),
                 amount: amount,
                 qrisType: 'dynamic',
               );

               if (mounted) {
                Navigator.pop(context);
                
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AlertDialog(
                    title: const Text('QRIS Dinamis'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Scan QR berikut untuk pembayaran otomatis:\n(Pembayaran akan terupdate via webhook)'),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/qrcode_placeholder.png',
                            width: 200,
                            height: 200,
                            errorBuilder: (_, __, ___) => const SizedBox(width: 200, height: 200, child: Icon(Icons.qr_code_2_rounded, size: 200)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Total: Rp ${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Tutup'),
                      ),
                    ],
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal generate QRIS dinamis: $e'), backgroundColor: AppTheme.errorColor),
                );
                setState(() => _isLoadingQris = false);
              }
            }
          },
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.qr_code_2_rounded, size: 140, color: Colors.black),
                  SizedBox(height: 6),
                  Text(
                    'TAP UNTUK BUAT QR',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.accentColor, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Klik QR untuk generate, pembayaran ter-update otomatis via webhook Midtrans',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransferSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rekening Tujuan:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          SizedBox(height: 4),
          Text('BCA 8735091223 (KasirGo Outlet)',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          SizedBox(height: 2),
          Text('Konfirmasi manual setelah mutasi masuk',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildWaReceiptSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: _sendWaReceipt,
                activeColor: const Color(0xFF25D366),
                onChanged: (val) => setState(() => _sendWaReceipt = val ?? false),
              ),
              const Expanded(
                child: Text(
                  'Kirim Struk via WhatsApp',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.receipt_long_rounded, color: Color(0xFF25D366), size: 20),
            ],
          ),
          if (_sendWaReceipt)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextField(
                controller: _customerWaController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Nomor WhatsApp Pelanggan',
                  hintText: '0812xxxxxxxx',
                  prefixIcon: Icon(Icons.phone_rounded, size: 18),
                  isDense: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAmountChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
      onPressed: onTap,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
      side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
    );
  }
}
