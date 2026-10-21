import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/sidak_service.dart';

/// Laporan Sidak Bos (audit stok & kas) dalam PDF A4 dan teks WhatsApp.
class SidakReportPdf {
  static String verdictLabel(bool clean, int findingCount) {
    if (clean) return 'BERSIH';
    if (findingCount >= 3) return 'PERLU DITINDAKLANJUTI';
    return 'ADA SELISIH';
  }

  static Future<Uint8List> build({
    required String storeName,
    required DateTime periodFrom,
    required DateTime periodTo,
    required double cashSales,
    required double nonCashSales,
    required double expectedCash,
    required double actualCash,
    required double cashDiff,
    required double stockValueSystem,
    required double stockValuePhysical,
    required double stockDiffValue,
    required List<SidakFinding> findings,
    required List<SidakCountRow> rows,
    String note = '',
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final diffRows = rows.where((r) => !r.isService && r.diff != 0).toList();
    final clean = cashDiff == 0 && stockDiffValue == 0 && findings.isEmpty;

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
                      'LAPORAN SIDAK BOS',
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
                      'Audit Stok & Kas - KasirGo',
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
        build: (pw.Context ctx) => <pw.Widget>[
          pw.Text(
            'Periode: ${DateFormat('d MMM yyyy', 'id_ID').format(periodFrom)}'
            ' - ${DateFormat('d MMM yyyy', 'id_ID').format(periodTo)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Hasil: ${verdictLabel(clean, findings.length)}',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  clean
                      ? 'Kas dan stok sesuai catatan. Pertahankan pencatatan rapi.'
                      : '${findings.length} temuan perlu ditindaklanjuti.',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          _sectionTitle('A. Kas Laci'),
          _kvTable([
            ['Penjualan tunai', _rupiah(cashSales)],
            ['Penjualan non-tunai', _rupiah(nonCashSales)],
            ['Kas seharusnya', _rupiah(expectedCash)],
            ['Kas fisik dihitung', _rupiah(actualCash)],
            ['Selisih', _rupiah(cashDiff)],
          ]),
          pw.SizedBox(height: 16),
          _sectionTitle('B. Nilai Stok'),
          _kvTable([
            ['Nilai stok menurut sistem', _rupiah(stockValueSystem)],
            ['Nilai stok hasil hitung', _rupiah(stockValuePhysical)],
            ['Selisih nilai', _rupiah(stockDiffValue)],
            ['Produk berselisih', '${diffRows.length} produk'],
          ]),
          if (diffRows.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle('C. Rincian Selisih Stok'),
            pw.Table(
              border:
                  pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FixedColumnWidth(56),
                2: pw.FixedColumnWidth(56),
                3: pw.FixedColumnWidth(56),
                4: pw.FixedColumnWidth(70),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell('Produk', bold: true),
                    _cell('Sistem', bold: true),
                    _cell('Fisik', bold: true),
                    _cell('Selisih', bold: true),
                    _cell('Nilai', bold: true),
                  ],
                ),
                for (final r in diffRows)
                  pw.TableRow(
                    children: [
                      _cell(r.name),
                      _cell(_qty(r.stockSystem)),
                      _cell(_qty(r.physical)),
                      _cell(_qty(r.diff)),
                      _cell(_rupiah(r.diffValue)),
                    ],
                  ),
              ],
            ),
          ],
          if (findings.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle(
              diffRows.isEmpty ? 'C. Temuan' : 'D. Temuan & Saran',
            ),
            for (var i = 0; i < findings.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${i + 1}. ${findings[i].title}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      findings[i].detail,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
          ],
          if (note.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionTitle('Catatan'),
            pw.Text(note, style: const pw.TextStyle(fontSize: 10)),
          ],
          pw.SizedBox(height: 20),
          pw.Text(
            'Laporan ini dibuat otomatis dari data KasirGo. Simpan sebagai '
            'bukti audit internal dan tindak lanjuti temuan bernilai besar.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static String buildText({
    required String storeName,
    required DateTime periodFrom,
    required DateTime periodTo,
    required double cashSales,
    required double nonCashSales,
    required double expectedCash,
    required double actualCash,
    required double cashDiff,
    required double stockDiffValue,
    required List<SidakFinding> findings,
    required List<SidakCountRow> rows,
    String note = '',
  }) {
    final b = StringBuffer();
    final diffRows = rows.where((r) => !r.isService && r.diff != 0).toList();
    final clean = cashDiff == 0 && stockDiffValue == 0 && findings.isEmpty;
    b.writeln('*Laporan Sidak Bos*');
    if (storeName.isNotEmpty) b.writeln(storeName);
    b.writeln('${DateFormat('d MMM yyyy', 'id_ID').format(periodFrom)}'
        ' - ${DateFormat('d MMM yyyy', 'id_ID').format(periodTo)}');
    b.writeln('');
    b.writeln('*Hasil: ${verdictLabel(clean, findings.length)}*');
    b.writeln('');
    b.writeln('*Kas*');
    b.writeln('- Tunai: ${_rupiah(cashSales)}');
    b.writeln('- Non-tunai: ${_rupiah(nonCashSales)}');
    b.writeln('- Seharusnya: ${_rupiah(expectedCash)}');
    b.writeln('- Fisik: ${_rupiah(actualCash)}');
    b.writeln('- Selisih: ${_rupiah(cashDiff)}');
    b.writeln('');
    b.writeln('*Stok*');
    b.writeln('- Selisih nilai: ${_rupiah(stockDiffValue)}');
    b.writeln('- Produk berselisih: ${diffRows.length}');
    if (diffRows.isNotEmpty) {
      for (final r in diffRows.take(10)) {
        b.writeln('  - ${r.name}: ${_qty(r.diff)} ${r.unit}');
      }
    }
    if (findings.isNotEmpty) {
      b.writeln('');
      b.writeln('*Temuan*');
      for (var i = 0; i < findings.length; i++) {
        b.writeln('${i + 1}. ${findings[i].title}');
      }
    }
    if (note.isNotEmpty) {
      b.writeln('');
      b.writeln('*Catatan*');
      b.writeln(note);
    }
    b.writeln('');
    b.writeln('-- dari KasirGo - Sidak Bos');
    return b.toString();
  }

  static pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );

  static pw.Widget _kvTable(List<List<String>> rows) => pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(2),
        },
        children: [
          for (final r in rows)
            pw.TableRow(
              children: [_cell(r[0]), _cell(r[1], bold: true)],
            ),
        ],
      );

  static pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  static String _qty(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  static String _rupiah(double v) {
    final neg = v < 0;
    final s = v.abs().round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${neg ? '-' : ''}Rp $buf';
  }
}
