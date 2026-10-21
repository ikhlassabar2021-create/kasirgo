import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'formatters.dart';

/// Ringkasan hasil diagnosa Dokter Bisnis AI (BAGIAN 13.21A) dalam bentuk
/// PDF A4 dan teks WhatsApp. Dipakai tombol "Simpan / Bagikan".
class DoctorResultPdf {
  static String scoreTone(int? score) {
    final s = score ?? 0;
    if (s >= 70) return 'SEHAT';
    if (s >= 40) return 'PERLU PERHATIAN';
    return 'BUTUH PENANGANAN';
  }

  static Future<Uint8List> build({
    required String storeName,
    required String verdictTitle,
    required String verdictBody,
    int? score,
    String scoreHint = '',
    int? targetDays,
    DateTime? dueDate,
    List<Map<String, dynamic>> steps = const [],
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HASIL PEMERIKSAAN USAHA',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      storeName.isEmpty ? 'Usaha Saya' : storeName,
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      DateFormat('d MMMM yyyy', 'id_ID').format(now),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Dokter Bisnis AI KasirGo',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (pw.Context ctx) {
          final due = dueDate;
          final targetText = [
            if (targetDays != null) 'Selesaikan dalam $targetDays hari',
            if (due != null)
              'batas ${DateFormat('d MMM yyyy', 'id_ID').format(due)}',
          ].join(' | ');

          return <pw.Widget>[
            if (score != null) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      '${score.clamp(0, 100)}',
                      style: pw.TextStyle(
                        fontSize: 34,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Skor Kesehatan Usaha - ${scoreTone(score)}',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (scoreHint.isNotEmpty)
                            pw.Text(
                              scoreHint,
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
            ],
            pw.Text(
              'A. Vonis Dokter',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    verdictTitle.isEmpty ? 'Belum ada vonis' : verdictTitle,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (verdictBody.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      verdictBody,
                      style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
                    ),
                  ],
                ],
              ),
            ),
            if (steps.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text(
                'B. Peta Resep',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                columnWidths: const {
                  0: pw.FixedColumnWidth(26),
                  1: pw.FlexColumnWidth(4),
                  2: pw.FixedColumnWidth(70),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _cell('No', bold: true),
                      _cell('Langkah Perbaikan', bold: true),
                      _cell('Status', bold: true),
                    ],
                  ),
                  for (var i = 0; i < steps.length; i++)
                    pw.TableRow(
                      children: [
                        _cell('${i + 1}'),
                        _cell(steps[i]['text']?.toString() ?? ''),
                        _cell(
                          steps[i]['done'] == true ? 'Selesai' : 'Belum',
                        ),
                      ],
                    ),
                ],
              ),
            ],
            if (targetText.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text(
                'C. Target & Waktu',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(targetText, style: const pw.TextStyle(fontSize: 10)),
            ],
            pw.SizedBox(height: 20),
            pw.Text(
              'Catatan: hasil ini adalah saran otomatis dari data usaha Anda, '
              'bukan jaminan hasil. Jalankan satu per satu dan catat hasilnya '
              'agar Dokter Bisnis AI dapat mengevaluasi.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Dibuat otomatis oleh KasirGo - Dokter Bisnis AI',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  /// Teks ringkas untuk dibagikan lewat WhatsApp.
  static String buildText({
    required String storeName,
    required String verdictTitle,
    required String verdictBody,
    int? score,
    int? targetDays,
    DateTime? dueDate,
    List<Map<String, dynamic>> steps = const [],
  }) {
    final b = StringBuffer();
    b.writeln('*Hasil Pemeriksaan Usaha*');
    if (storeName.isNotEmpty) b.writeln(storeName);
    b.writeln(Formatters.date(DateTime.now()));
    b.writeln('');
    if (score != null) {
      b.writeln('*Skor Kesehatan: ${score.clamp(0, 100)}/100 '
          '(${scoreTone(score)})*');
      b.writeln('');
    }
    b.writeln('*Vonis*');
    b.writeln(verdictTitle.isEmpty ? '-' : verdictTitle);
    if (verdictBody.isNotEmpty) b.writeln(verdictBody);
    if (steps.isNotEmpty) {
      b.writeln('');
      b.writeln('*Peta Resep*');
      for (var i = 0; i < steps.length; i++) {
        final mark = steps[i]['done'] == true ? '[x]' : '[ ]';
        b.writeln('$mark ${i + 1}. ${steps[i]['text'] ?? ''}');
      }
    }
    final due = dueDate;
    if (targetDays != null || due != null) {
      b.writeln('');
      b.writeln('*Target & Waktu*');
      if (targetDays != null) b.writeln('- Selesaikan dalam $targetDays hari');
      if (due != null) {
        b.writeln('- Batas ${DateFormat('d MMM yyyy', 'id_ID').format(due)}');
      }
    }
    b.writeln('');
    b.writeln('-- dari Dokter Bisnis AI KasirGo');
    return b.toString();
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
