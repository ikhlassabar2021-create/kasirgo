import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';

/// Dialog sukses setelah checkout.
///
/// Aksi struk (bila callback tersedia):
/// - Kirim struk TEXT ke WhatsApp pelanggan
/// - Kirim struk PDF ke WhatsApp pelanggan
/// - Struk PDF (unduh/bagikan)
/// - Selesai
class CheckoutSuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onReceipt;
  final VoidCallback onFinish;

  /// True bila data pelanggan (nomor WA) tersedia -> opsi kirim WA muncul.
  final bool canSendWhatsApp;
  final VoidCallback? onWaText;
  final VoidCallback? onWaPdf;

  const CheckoutSuccessDialog({
    super.key,
    required this.onReceipt,
    required this.onFinish,
    this.title = 'Transaksi Berhasil',
    this.message = '',
    this.canSendWhatsApp = false,
    this.onWaText,
    this.onWaPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge + 8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppTheme.successColor, size: 44),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (canSendWhatsApp && onWaText != null) ...[
                _wideButton(
                  onPressed: onWaText!,
                  icon: Icons.chat_rounded,
                  label: 'Kirim Struk Text ke WA',
                  background: AppTheme.whatsAppColor,
                ),
                const SizedBox(height: 10),
              ],
              if (canSendWhatsApp && onWaPdf != null) ...[
                _wideButton(
                  onPressed: onWaPdf!,
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'Kirim Struk PDF ke WA',
                  background: AppTheme.secondaryColor,
                ),
                const SizedBox(height: 10),
              ],
              _wideButton(
                onPressed: onReceipt,
                icon: Icons.print_rounded,
                label: 'Struk PDF (Unduh / Cetak)',
                background: AppTheme.primaryColor,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: onFinish,
                  child: Text(
                    'Selesai',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wideButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color background,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
