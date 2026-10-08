import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';
import '../services/supporter_service.dart';
import 'formatters.dart';
import 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart';

/// Struk digital (PDF 80mm) dengan opsi logo kustom (Program Pendukung,
/// feature `custom_receipt`). Logo disimpan LOKAL di perangkat (kebijakan
/// penyimpanan: foto/gambar tidak pernah ke cloud).
class ReceiptGenerator {
  static const _logoKey = 'receipt_logo_base64';
  static const _taglineKey = 'receipt_tagline';

  static Future<String?> loadLogo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_logoKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLogo(String base64) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logoKey, base64);
  }

  static Future<void> deleteLogo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logoKey);
  }

  static Future<String?> loadTagline() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_taglineKey);
  }

  static Future<void> saveTagline(String tagline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_taglineKey, tagline);
  }

  /// Struk untuk transaksi POS yang baru selesai. Logo kustom hanya muncul
  /// bila outlet berhak atas fitur Pendukung `custom_receipt`.
  static Future<bool> shareTransactionReceipt({
    required String outletId,
    required String storeName,
    required List<TransactionItem> items,
    required String txId,
    required DateTime createdAt,
    required String paymentMethod,
    required double totalAmount,
    required double finalAmount,
    double discountAmount = 0,
  }) async {
    try {
      String? logoB64;
      try {
        final hasCustom = await SupporterService()
            .hasFeature(outletId, 'custom_receipt');
        if (hasCustom) {
          final logo = await loadLogo();
          if (logo != null && logo.isNotEmpty) logoB64 = logo;
        }
      } catch (_) {
        logoB64 = null;
      }
      final tagline = await loadTagline();

      final bytes = await build(
        storeName: storeName,
        items: items,
        totalAmount: totalAmount,
        finalAmount: finalAmount,
        discountAmount: discountAmount,
        paymentMethod: paymentMethod,
        txId: txId,
        createdAt: createdAt,
        tagline: tagline,
        logoBase64: logoB64,
      );
      final shortId =
          txId.length > 8 ? txId.substring(0, 8).toUpperCase() : txId;
      await share(bytes, 'Struk_$shortId.pdf');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Bagikan / unduh PDF. Di web pakai unduhan browser (blob),
  /// di native pakai share sheet Printing.
  static Future<void> share(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      await webDownload(bytes, filename);
      return;
    }
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// Bangun struk PDF. [logoBase64] kosong/null -> struk polos (fitur gratis),
  /// dengan logo -> tampilan branded (Pendukung).
  static Future<Uint8List> build({
    required String storeName,
    String? storeAddress,
    required List<TransactionItem> items,
    required double totalAmount,
    required double finalAmount,
    required String paymentMethod,
    required String txId,
    required DateTime createdAt,
    double discountAmount = 0,
    String? tagline,
    String? logoBase64,
  }) async {
    final doc = pw.Document();

    pw.MemoryImage? logo;
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        logo = pw.MemoryImage(base64Decode(logoBase64));
      } catch (_) {
        logo = null;
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity),
        margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        build: (pw.Context pContext) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null)
                pw.Container(
                  width: 90,
                  height: 90,
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Image(logo),
                ),
              pw.Text(
                storeName.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 12.5, fontWeight: pw.FontWeight.bold),
              ),
              if (tagline != null && tagline.trim().isNotEmpty)
                pw.Text(
                  tagline.trim(),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              if (storeAddress != null && storeAddress.trim().isNotEmpty)
                pw.Text(
                  storeAddress.trim(),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              pw.Divider(thickness: 1),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'No: ${txId.length > 10 ? txId.substring(0, 10) : txId}',
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ),
              pw.Text(
                Formatters.date(createdAt),
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 8),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (final item in items)
                    pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(item.productName,
                              style: const pw.TextStyle(fontSize: 9.5)),
                          pw.Text(
                            '${item.quantity} x ${Formatters.currency(item.price)}   '
                            '${Formatters.currency(item.price * item.quantity)}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              pw.Divider(),
              if (discountAmount > 0)
                _receiptRow('Diskon', '-${Formatters.currency(discountAmount)}'),
              _receiptRow('TOTAL', Formatters.currency(finalAmount), bold: true),
              _receiptRow('Bayar', ReceiptGenerator.methodLabel(paymentMethod)),
              pw.SizedBox(height: 10),
              pw.Text('Terima kasih telah berbelanja!',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Dicetak via KasirGo',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _receiptRow(String label, String value,
      {bool bold = false}) {
    final style = pw.TextStyle(
        fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label, style: style), pw.Text(value, style: style)],
      ),
    );
  }

  static String shortId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8).toUpperCase();
  }

  static String methodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'bank_transfer':
        return 'Transfer Bank';
      default:
        return method.toUpperCase();
    }
  }
}
