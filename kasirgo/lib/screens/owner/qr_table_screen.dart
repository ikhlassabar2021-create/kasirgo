import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart' as bc;
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';

class QrTableScreen extends StatefulWidget {
  const QrTableScreen({super.key});

  @override
  State<QrTableScreen> createState() => _QrTableScreenState();
}

class _QrTableScreenState extends State<QrTableScreen> {
  final List<String> _tables = ['Meja 01', 'Meja 02', 'Meja 03', 'Meja 04', 'Meja 05'];
  final _newTableController = TextEditingController();

  @override
  void dispose() {
    _newTableController.dispose();
    super.dispose();
  }

  void _addTable() {
    if (_newTableController.text.trim().isEmpty) return;
    setState(() {
      _tables.add(_newTableController.text.trim());
      _newTableController.clear();
    });
  }

  void _showQrModal(String table) {
    // Deep-link format with table parameter
    final qrData = 'https://kasirgo.online/order?table=${Uri.encodeComponent(table)}';
    final qrCode = bc.Barcode.qrCode();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Center(
          child: Text(
            'QR Code $table',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: _QrPainter(data: qrData, barcode: qrCode),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pelanggan scan QR ini di meja untuk melihat menu & kirim pesanan otomatis.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 8),
            SelectableText(
              qrData,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.primaryColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tutup', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.borderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
            ),
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Download'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('QR $table diunduh ke galeri perangkat'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
            ),
            icon: const Icon(Icons.print_outlined, size: 16),
            label: const Text('Cetak QR'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Menyiapkan cetak stiker QR untuk $table')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Manajemen QR Meja',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QR Order per Meja',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Cetak QR untuk tiap meja. Pelanggan scan, pesan, dan bayar tanpa menunggu pelayan.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTableController,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Nama / Nomor Meja Baru',
                      hintText: 'Misal: Meja 06, VIP 1',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: AppTheme.touchTargetLarge,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                    ),
                    onPressed: _addTable,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('Tambah', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Daftar Meja (${_tables.length})',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.15,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _tables.length,
              itemBuilder: (context, index) {
                final table = _tables[index];

                return InkWell(
                  onTap: () => _showQrModal(table),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(color: AppTheme.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.textPrimary.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: const Icon(Icons.table_restaurant_outlined, size: 24, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          table,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_2_outlined, size: 14, color: AppTheme.primaryColor),
                            const SizedBox(width: 4),
                            Text('Lihat QR', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final String data;
  final bc.Barcode barcode;

  const _QrPainter({required this.data, required this.barcode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    try {
      for (final element in barcode.make(data, width: size.width, height: size.height)) {
        if (element is bc.BarcodeBar && element.black) {
          canvas.drawRect(
            Rect.fromLTWH(
              element.left,
              element.top,
              element.width,
              element.height,
            ),
            paint,
          );
        }
      }
    } catch (_) {
      // Fallback
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.data != data;
}
