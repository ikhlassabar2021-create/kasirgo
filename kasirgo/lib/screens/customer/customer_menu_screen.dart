import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_theme.dart';
import '../../providers/module_provider.dart';
import '../../services/supabase_service.dart';
import 'customer_order_screen.dart';

class CustomerMenuScreen extends ConsumerStatefulWidget {
  final String initialOutletId;
  final String initialTable;

  const CustomerMenuScreen({
    super.key,
    this.initialOutletId = '',
    this.initialTable = '',
  });

  @override
  ConsumerState<CustomerMenuScreen> createState() => _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends ConsumerState<CustomerMenuScreen> {
  late final TextEditingController _tableController;
  late final TextEditingController _outletController;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _tableController = TextEditingController(text: widget.initialTable.isNotEmpty ? widget.initialTable : '1');
    _outletController = TextEditingController(text: widget.initialOutletId);
    if (widget.initialOutletId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openOrderScreen(widget.initialOutletId, widget.initialTable);
      });
    }
  }

  @override
  void dispose() {
    _tableController.dispose();
    _outletController.dispose();
    super.dispose();
  }

  Future<void> _openOrderScreen(String outletId, String tableNumber) async {
    if (outletId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan QR meja atau masukkan Kode Outlet terlebih dahulu'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _opening = true);
    final outlet = await SupabaseService().findOutlet(outletId.trim());
    if (!mounted) return;
    setState(() => _opening = false);

    if (outlet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Outlet tidak ditemukan. Pastikan QR benar atau minta kode ke kasir.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // QR Meja / self-order hanya untuk usaha makan-minum (cafe/warteg).
    // Warung/kelontong/retail/gerobak tidak punya layanan meja.
    if (!ModuleConfig.isFoodBusiness(outlet.type)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Outlet ini tidak menyediakan pesan-antar meja. Silakan pesan langsung di kasir.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerOrderScreen(
          outletId: outlet.id,
          outletName: outlet.name,
          tableNumber: tableNumber.trim().isNotEmpty ? tableNumber.trim() : '1',
        ),
      ),
    );
  }

  void _parseScannedCode(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return;

    // QR bisa berupa URL deep-link penuh atau hanya ID outlet.
    try {
      final uri = Uri.parse(value);
      if (uri.queryParameters.containsKey('outlet')) {
        final o = uri.queryParameters['outlet'] ?? '';
        final t = uri.queryParameters['table'] ?? '';
        _outletController.text = o;
        if (t.isNotEmpty) _tableController.text = t;
      } else if (uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last;
        _outletController.text = last;
      } else {
        _outletController.text = value;
      }
    } catch (_) {
      _outletController.text = value;
    }
  }

  Future<void> _scanQr() async {
    try {
      final scanned = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const _QrScannerPage()),
      );
      if (!mounted || scanned == null || scanned.isEmpty) return;
      _parseScannedCode(scanned);
      final outlet = _outletController.text.trim();
      final table = _tableController.text.trim();
      if (outlet.isNotEmpty) {
        _openOrderScreen(outlet, table);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamera tidak tersedia. Tempel Kode Outlet dari QR secara manual.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
        title: Text(
          'Menu Mandiri Pelanggan',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17, color: AppTheme.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan QR Meja',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Order langsung dari meja tanpa install aplikasi',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _scanQr,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: Text(
                      'Scan QR Kamera',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _outletController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'ID / Kode Outlet',
                    hintText: 'Tempel ID outlet cafe/resto...',
                    prefixIcon: Icon(Icons.storefront_rounded, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tableController,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Nomor Meja',
                    hintText: 'Contoh: 1, 2, atau VIP',
                    prefixIcon: Icon(Icons.table_restaurant_rounded, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _opening
                        ? null
                        : () => _openOrderScreen(_outletController.text, _tableController.text),
                    icon: _opening
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.restaurant_menu_rounded, size: 20),
                    label: Text(
                      _opening ? 'Membuka menu...' : 'Buka Katalog & Pesan',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Alur Pesan Cepat',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _StepItem(step: '1', text: 'Scan QR di meja atau masukkan ID outlet & meja.'),
                const _StepItem(step: '2', text: 'Pilih hidangan, atur jumlah porsi, klik Pesan.'),
                const _StepItem(step: '3', text: 'Pesanan langsung masuk ke antrean kasir/dapur.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR Meja', style: TextStyle(fontSize: 16)),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.no_photography_rounded, color: Colors.white70, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Kamera tidak dapat diakses.\n${error.errorDetails?.message ?? error.errorCode.name}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Kembali & input manual'),
                    ),
                  ],
                ),
              ),
            ),
            onDetect: (capture) {
              if (_handled) return;
              for (final barcode in capture.barcodes) {
                final code = barcode.rawValue ?? barcode.displayValue;
                if (code != null && code.isNotEmpty) {
                  _handled = true;
                  Navigator.pop(context, code);
                  break;
                }
              }
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Arahkan kamera ke QR di meja',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String step;
  final String text;

  const _StepItem({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            child: Text(
              step,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
