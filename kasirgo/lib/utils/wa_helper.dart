import 'package:url_launcher/url_launcher.dart';
import '../models/transaction.dart';
import 'formatters.dart';

class WaHelper {
  /// Format and launch WhatsApp message using wa.me URL
  static Future<bool> sendWhatsAppMessage({
    required String phone,
    required String message,
  }) async {
    // Sanitize phone number (Indonesia format)
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('62')) {
      cleanPhone = '62$cleanPhone';
    }

    final encodedMessage = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Generate digital receipt text for WhatsApp
  static String formatReceiptMessage({
    required String storeName,
    required Transaction transaction,
    String? cashierName,
    String? customerName,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('*$storeName*');
    buffer.writeln('==============================');
    buffer.writeln('No. Transaksi: #${transaction.id.substring(0, 8)}');
    buffer.writeln('Tanggal: ${Formatters.dateTime(transaction.createdAt)}');
    if (cashierName != null && cashierName.isNotEmpty) {
      buffer.writeln('Kasir: $cashierName');
    }
    if (customerName != null && customerName.isNotEmpty) {
      buffer.writeln('Pelanggan: $customerName');
    }
    buffer.writeln('Metode Bayar: ${transaction.paymentMethod.toUpperCase()}');
    buffer.writeln('==============================');

    for (final item in transaction.items) {
      final subtotal = item.quantity * item.price;
      buffer.writeln(
        '${item.productName}\n  ${item.quantity} x ${Formatters.currency(item.price)} = ${Formatters.currency(subtotal)}',
      );
    }

    buffer.writeln('------------------------------');
    buffer.writeln('Subtotal: ${Formatters.currency(transaction.totalAmount)}');
    final discount = transaction.discountAmount ?? 0;
    if (discount > 0) {
      buffer.writeln('Diskon: -${Formatters.currency(discount)}');
    }
    final tax = transaction.taxAmount ?? 0;
    if (tax > 0) {
      buffer.writeln('Pajak: +${Formatters.currency(tax)}');
    }
    if (transaction.tipAmount > 0) {
      buffer.writeln('Tip: +${Formatters.currency(transaction.tipAmount)}');
    }
    buffer.writeln('*TOTAL: ${Formatters.currency(transaction.finalAmount)}*');
    buffer.writeln('==============================');
    buffer.writeln('Terima kasih telah berbelanja di $storeName!');
    buffer.writeln('Struk digital ini dibuat otomatis via KasirGo.');

    return buffer.toString();
  }

  /// Format promotional broadcast message
  static String formatBroadcastPromo({
    required String storeName,
    required String promoTitle,
    required String promoDescription,
    String? promoCode,
    String? validUntil,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('*PROMO SPESIAL DARI $storeName!*');
    buffer.writeln('');
    buffer.writeln('*$promoTitle*');
    buffer.writeln(promoDescription);
    if (promoCode != null && promoCode.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Gunakan Kode: *$promoCode*');
    }
    if (validUntil != null && validUntil.isNotEmpty) {
      buffer.writeln('Berlaku s/d: $validUntil');
    }
    buffer.writeln('');
    buffer.writeln('Kunjungi toko kami atau hubungi kami sekarang.');
    buffer.writeln('Salam hangat dari $storeName');

    return buffer.toString();
  }

  /// Format retention message for inactive customer
  static String formatRetentionMessage({
    required String storeName,
    required String customerName,
    int daysInactive = 30,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Halo kak *$customerName*,');
    buffer.writeln('Kami kangen kakak di *$storeName*!');
    buffer.writeln('');
    buffer.writeln('Sudah $daysInactive hari nih kakak belum mampir lagi.');
    buffer.writeln('Ada banyak produk dan menu baru yang wajib dicoba lho.');
    buffer.writeln('');
    buffer.writeln('Dapatkan penawaran spesial untuk kunjungan kakak berikutnya.');
    buffer.writeln('Ditunggu kedatangannya ya kak!');
    buffer.writeln('-$storeName-');

    return buffer.toString();
  }
}
