import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barcode/barcode.dart' as bc;
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../config/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';

class QrTableScreen extends ConsumerStatefulWidget {
  const QrTableScreen({super.key});

  @override
  ConsumerState<QrTableScreen> createState() => _QrTableScreenState();
}

class _QrTableScreenState extends ConsumerState<QrTableScreen> {
  final _service = SupabaseService();
  List<String> _tables = [];
  bool _isLoading = true;
  bool _isAdding = false;
  final _newTableController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  @override
  void dispose() {
    _newTableController.dispose();
    super.dispose();
  }

  Future<void> _loadTables() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final tables = await _service.getOutletTables(outletId);
    if (!mounted) return;
    setState(() {
      _tables = tables;
      _isLoading = false;
    });
  }

  Future<void> _addTable() async {
    final outletId = ref.read(currentUserProvider)?.outletId ?? '';
    final name = _newTableController.text.trim();
    if (name.isEmpty || outletId.isEmpty) return;
    setState(() => _isAdding = true);
    final result = await _service.addOutletTableDetailed(outletId, name);
    if (!mounted) return;
    setState(() => _isAdding = false);
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? 'Gagal menambah meja'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    _newTableController.clear();
    await _loadTablesSafe();
  }

  Future<void> _loadTablesSafe() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    final tables = await _service.getOutletTables(outletId);
    if (!mounted) return;
    setState(() => _tables = tables);
  }

  Future<void> _removeTable(String name) async {
    final outletId = ref.read(currentUserProvider)?.outletId ?? '';
    if (outletId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Text('Hapus $name?',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTheme.textPrimary)),
        content: Text(
          'QR meja ini tidak bisa dipakai lagi. Riwayat pesanan lama tetap tersimpan.',
          style: GoogleFonts.inter(
              fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus',
                style: GoogleFonts.inter(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _tables.remove(name));
    final removed = await _service.deleteOutletTable(outletId, name);
    if (!removed && mounted) {
      await _loadTablesSafe();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal menghapus meja'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  String _buildQrData(String table) {
    final outletId = ref.read(currentUserProvider)?.outletId ?? '';
    return SupabaseConfig.tableUrl(outletId, table);
  }

  void _copyLink(BuildContext context, String table) {
    final data = _buildQrData(table);
    Clipboard.setData(ClipboardData(text: data));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Link pesanan $table disalin! Bagikan via WhatsApp.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
  }

  void _showQrModal(String table) {
    // Deep-link ke aplikasi pelanggan: bawa outlet_id + nomor meja.
    final qrData = _buildQrData(table);
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
            icon: const Icon(Icons.link_rounded, size: 16),
            label: const Text('Salin Link'),
            onPressed: () => _copyLink(ctx, table),
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
                    onPressed: _isAdding ? null : _addTable,
                    icon: _isAdding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.add_rounded, size: 18),
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
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryColor)),
              )
            else if (_tables.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.table_restaurant_outlined,
                          size: 40, color: AppTheme.textSecondary),
                      const SizedBox(height: 10),
                      Text(
                        'Belum ada meja. Tambahkan meja pertama di atas.',
                        style: GoogleFonts.inter(
                            fontSize: 12.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
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
                    onLongPress: () => _removeTable(table),
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
                    child: Stack(
                      children: [
                        Column(
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
                        Positioned(
                          top: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () => _removeTable(table),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.delete_outline_rounded,
                                  size: 18, color: AppTheme.errorColor),
                            ),
                          ),
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
