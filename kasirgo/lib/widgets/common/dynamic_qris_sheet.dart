import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../services/payment_service.dart';
import '../../services/supporter_service.dart';
import '../../utils/formatters.dart';

/// Sheet QRIS dinamis dengan polling status pembayaran otomatis.
///
/// Dipakai oleh alur Program Pendukung (upgrade/perpanjang) agar pembayaran
/// terverifikasi otomatis via webhook/polling gateway.
class DynamicQrisSheet extends StatefulWidget {
  final SupporterCheckoutResult result;

  const DynamicQrisSheet({super.key, required this.result});

  @override
  State<DynamicQrisSheet> createState() => _DynamicQrisSheetState();
}

class _DynamicQrisSheetState extends State<DynamicQrisSheet> {
  Timer? _timer;
  late String _status;

  bool get _paid => _status == 'PAID';

  @override
  void initState() {
    super.initState();
    _status = widget.result.status.toUpperCase();
    if (_status != 'PAID') _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    final orderId = widget.result.providerOrderId;
    if (orderId == null) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final status = await PaymentService().checkStatus(orderId);
      if (!mounted) return;
      if (status == 'PAID' || status == 'SUCCESS' || status == 'SETTLEMENT') {
        timer.cancel();
        await PaymentService().confirmPaid(orderId);
        if (mounted) setState(() => _status = 'PAID');
      } else if (status == 'EXPIRED' || status == 'FAILED') {
        timer.cancel();
        if (mounted) setState(() => _status = status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final qrisString = widget.result.qrisString ?? '';
    final qrisUrl = widget.result.qrisUrl ?? '';
    final paymentUrl = widget.result.paymentUrl ?? '';
    final total = widget.result.totalAmount > 0
        ? widget.result.totalAmount
        : widget.result.amount;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(_paid ? 'Pembayaran Berhasil' : 'Pembayaran QRIS',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(
                'Order: ${widget.result.providerOrderId ?? widget.result.orderId}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _paid ? AppTheme.successColor : AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  Text(Formatters.currency(total),
                      style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.secondaryColor)),
                  const SizedBox(height: 4),
                  Text('Program Pendukung - ${widget.result.periodDays} hari',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  if (_paid)
                    const Icon(Icons.check_circle_rounded,
                        size: 110, color: AppTheme.successColor)
                  else if (qrisString.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: QrImageView(
                        data: qrisString,
                        size: 190,
                        backgroundColor: Colors.white,
                      ),
                    )
                  else if (qrisUrl.isNotEmpty)
                    Image.network(qrisUrl,
                        width: 190,
                        height: 190,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.qr_code_2_rounded, size: 110))
                  else
                    const Icon(Icons.qr_code_2_rounded,
                        size: 110, color: AppTheme.textSecondary),
                  const SizedBox(height: 10),
                  if (!_paid)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Menunggu pembayaran...',
                            style: TextStyle(
                                fontSize: 11.5, color: AppTheme.textSecondary)),
                      ],
                    )
                  else
                    Text('Terima kasih! Program Pendukung Anda sudah aktif.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (!_paid && paymentUrl.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(paymentUrl),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Buka Halaman Bayar'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (!_paid) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _paid),
                icon: Icon(_paid ? Icons.check_rounded : Icons.close_rounded,
                    size: 18),
                label: Text(_paid ? 'Selesai' : 'Tutup',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _paid ? AppTheme.successColor : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
