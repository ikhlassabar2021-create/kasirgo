import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import 'customer_order_screen.dart';

class CustomerMenuScreen extends ConsumerStatefulWidget {
  const CustomerMenuScreen({super.key});

  @override
  ConsumerState<CustomerMenuScreen> createState() => _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends ConsumerState<CustomerMenuScreen> {
  final _tableController = TextEditingController(text: '1');
  final _outletController = TextEditingController();

  @override
  void dispose() {
    _tableController.dispose();
    _outletController.dispose();
    super.dispose();
  }

  void _openOrderScreen(String outletId, String tableNumber) {
    if (outletId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan Kode Outlet / Scan QR Meja'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerOrderScreen(
          outletId: outletId.trim(),
          tableNumber: tableNumber.trim().isNotEmpty ? tableNumber.trim() : '1',
        ),
      ),
    );
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
                const SizedBox(height: 18),
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
                  keyboardType: TextInputType.number,
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
                    onPressed: () => _openOrderScreen(_outletController.text, _tableController.text),
                    icon: const Icon(Icons.restaurant_menu_rounded, size: 20),
                    label: Text(
                      'Buka Katalog & Pesan',
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
                const _StepItem(step: '3', text: 'Pesanan langsung masuk ke antrean KDS Dapur & Kasir.'),
              ],
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
