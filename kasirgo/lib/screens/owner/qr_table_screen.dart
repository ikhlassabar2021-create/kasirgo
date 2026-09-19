import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart' as bc;
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
        title: Center(child: Text('QR Code $table')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
            const Text(
              'Pelanggan scan QR ini di meja untuk melihat menu & kirim pesanan otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            SelectableText(
              qrData,
              style: const TextStyle(fontSize: 11, color: AppTheme.accentColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.print, size: 18),
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
        title: const Text('Manajemen QR Meja'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: AppTheme.accentColor, size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cetak kode QR untuk setiap meja makan di cafe / resto Anda. Pelanggan langsung scan, pesan, dan bayar tanpa menunggu pelayan.',
                      style: TextStyle(fontSize: 13, height: 1.4),
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
                    decoration: const InputDecoration(
                      labelText: 'Nama / Nomor Meja Baru',
                      hintText: 'Misal: Meja 06, VIP 1, Outdoor 3',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _addTable,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Daftar Meja (${_tables.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _tables.length,
              itemBuilder: (context, index) {
                final table = _tables[index];

                return InkWell(
                  onTap: () => _showQrModal(table),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.table_restaurant, size: 36, color: AppTheme.accentColor),
                        const SizedBox(height: 8),
                        Text(
                          table,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code, size: 14, color: AppTheme.textSecondary),
                            SizedBox(width: 4),
                            Text('Lihat QR', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
