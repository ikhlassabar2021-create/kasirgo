import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

/// Ilustrasi simulasi layar KasirGo (bukan gambar aset) untuk panduan.
/// Dibuat dari widget sehingga ringan, tajam, dan bekerja offline.
class GuideMock extends StatelessWidget {
  const GuideMock({super.key, required this.scene, this.height = 252});

  final String scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = height * 0.56;
    return Center(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textPrimary.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: AppTheme.backgroundColor,
            child: Column(
              children: [
                _statusBar(),
                Expanded(child: _sceneContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBar() {
    return Container(
      height: 15,
      color: AppTheme.surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Row(
        children: [
          Text(
            '09.41',
            style: const TextStyle(
              fontSize: 5.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          const Icon(
            Icons.wifi_rounded,
            size: 6,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.battery_full_rounded,
            size: 6,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _sceneContent() {
    switch (scene) {
      case 'products':
        return _products();
      case 'pos':
        return _pos();
      case 'checkout':
        return _checkout();
      case 'orders':
        return _orders();
      case 'reports':
        return _reports();
      case 'employees':
        return _employees();
      case 'doctor':
        return _doctor();
      case 'tickets':
        return _tickets();
      case 'settings':
        return _settings();
      case 'buyer_radar':
        return _buyerRadar();
      case 'buyer_catalog':
        return _buyerCatalog();
      case 'buyer_cart':
        return _buyerCart();
      case 'buyer_checkout':
        return _buyerCheckout();
      case 'buyer_tracking':
        return _buyerTracking();
      case 'dashboard':
      default:
        return _dashboard();
    }
  }

  Widget _pad(Widget child) =>
      Padding(padding: const EdgeInsets.fromLTRB(8, 7, 8, 7), child: child);

  Widget _title(String text, {double size = 8}) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: AppTheme.textPrimary,
    ),
  );

  Widget _sub(String text) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 5.5,
      color: AppTheme.textSecondary,
      height: 1.3,
    ),
  );

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 4.8,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );

  Widget _field(String hint, {IconData icon = Icons.search_rounded}) =>
      Container(
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 8, color: AppTheme.textSecondary),
            const SizedBox(width: 3),
            _sub(hint),
          ],
        ),
      );

  Widget _dashboard() {
    return _pad(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Toko Test'),
          _sub('Ringkasan hari ini'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _statTile('Omzet', 'Rp350rb', AppTheme.primaryColor),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _statTile('Transaksi', '24', AppTheme.successColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: _bars([
              10.0,
              16.0,
              12.0,
              20.0,
              14.0,
              24.0,
              18.0,
            ], height: 30),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _quick(Icons.point_of_sale_rounded, 'Kasir'),
              _quick(Icons.inventory_2_rounded, 'Produk'),
              _quick(Icons.receipt_long_rounded, 'Pesanan'),
              _quick(Icons.insights_rounded, 'Laporan'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 4.8,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quick(IconData icon, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(icon, size: 9, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 4.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bars(List<double> values, {double height = 44}) {
    final max = values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values
            .map(
              (v) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: FractionallySizedBox(
                    heightFactor: (v / max).clamp(0.12, 1.0),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xFF0284C7), Color(0xFF06B6D4)],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _products() {
    return _pad(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('Cari produk...'),
          const SizedBox(height: 6),
          _productRow(Icons.rice_bowl_rounded, 'Beras 5 kg', 'Rp 62.000', '12'),
          _productRow(
            Icons.local_cafe_rounded,
            'Kopi Sachet',
            'Rp 2.000',
            '40',
          ),
          _productRow(
            Icons.bakery_dining_rounded,
            'Roti Bakar',
            'Rp 12.000',
            '8',
          ),
          _productRow(
            Icons.cleaning_services_rounded,
            'Sabun Cuci',
            'Rp 6.500',
            '0',
          ),
        ],
      ),
    );
  }

  Widget _productRow(IconData icon, String name, String price, String stock) {
    final color = stock == '0'
        ? AppTheme.errorColor
        : (int.parse(stock) <= 10
              ? AppTheme.warningColor
              : AppTheme.successColor);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 9, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 5.2,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _chip('Stok $stock', color),
        ],
      ),
    );
  }

  Widget _pos() {
    return Column(
      children: [
        _pad(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field('Cari produk...'),
              const SizedBox(height: 5),
              Row(
                children: [
                  _posTile(Icons.rice_bowl_rounded, 'Beras', '62rb'),
                  _posTile(Icons.local_cafe_rounded, 'Kopi', '2rb'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _posTile(Icons.bakery_dining_rounded, 'Roti', '12rb'),
                  _posTile(Icons.water_drop_rounded, 'Air', '4rb'),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(top: BorderSide(color: AppTheme.borderColor)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 4.8,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    'Rp 35.000',
                    style: const TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Bayar',
                  style: TextStyle(
                    fontSize: 5.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _posTile(IconData icon, String name, String price) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Icon(icon, size: 12, color: AppTheme.primaryColor),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 5.2,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              price,
              style: const TextStyle(
                fontSize: 4.8,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkout() {
    return Column(
      children: [
        _pad(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('Konfirmasi Pesanan', size: 7),
              const SizedBox(height: 5),
              _line('Beras 5 kg', 'x1', 'Rp62.000'),
              _line('Kopi Sachet', 'x2', 'Rp4.000'),
              const Divider(height: 7, color: AppTheme.borderColor),
              Row(
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 5.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Rp66.000',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(top: BorderSide(color: AppTheme.borderColor)),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'Buat Pesanan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.6),
                  ),
                ),
                child: const Text(
                  'area navigasi HP',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 4.5, color: AppTheme.warningColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(String name, String qty, String price) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 5.5,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            qty,
            style: const TextStyle(fontSize: 5, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 5),
          Text(
            price,
            style: const TextStyle(
              fontSize: 5.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orders() {
    return _pad(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Pesanan Masuk'),
          const SizedBox(height: 4),
          Row(
            children: [
              _chip('Dine-in', AppTheme.primaryColor),
              const SizedBox(width: 3),
              _chip('Online', AppTheme.textSecondary),
              const Spacer(),
              _chip('2 menunggu', AppTheme.warningColor),
            ],
          ),
          const SizedBox(height: 5),
          _orderCard(
            'Meja 4',
            '3 item - Rp45.000',
            'Menunggu Bayar',
            AppTheme.warningColor,
          ),
          _orderCard(
            'Andi (WA)',
            '2 item - Rp28.000',
            'Diantar',
            AppTheme.primaryColor,
          ),
          _orderCard(
            'Meja 2',
            '1 item - Rp12.000',
            'Diproses',
            AppTheme.successColor,
          ),
        ],
      ),
    );
  }

  Widget _orderCard(String title, String subtitle, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _chip(status, color),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _reports() {
    return _pad(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Laporan 7 Hari'),
          _sub('1 - 7 Nov 2026'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: [
                _bars([12.0, 18.0, 9.0, 22.0, 16.0, 26.0, 20.0], height: 42),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sub('Sen'),
                    _sub('Sel'),
                    _sub('Rab'),
                    _sub('Kam'),
                    _sub('Jum'),
                    _sub('Sab'),
                    _sub('Min'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          _reportRow('Omzet', 'Rp1.240.000', AppTheme.primaryColor),
          _reportRow('Laba kotor', 'Rp420.000', AppTheme.successColor),
          _reportRow('Transaksi', '86', AppTheme.warningColor),
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 5.2,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 5.6,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _employees() {
    return _pad(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Karyawan'),
          _sub('3 akun aktif - 1 Admin, 1 Kasir, 1 Koki'),
          const SizedBox(height: 6),
          _employeeRow('Sari', 'Admin', AppTheme.primaryColor),
          _employeeRow('Budi', 'Kasir', AppTheme.successColor),
          _employeeRow('Dewi', 'Koki', AppTheme.warningColor),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '+ Tambah Karyawan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 5,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _employeeRow(String name, String role, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 6,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              name.substring(0, 1),
              style: TextStyle(
                fontSize: 5.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 6,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          _chip(role, color),
        ],
      ),
    );
  }

  Widget _doctor() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF06B6D4), Color(0xFF4F46E5)],
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.medical_services_rounded,
                size: 8,
                color: Colors.white,
              ),
              SizedBox(width: 3),
              Text(
                'Dokter Bisnis AI',
                style: TextStyle(
                  fontSize: 5.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _pad(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bubble('Omzet 7 hari turun 18%. Stok beras menumpuk.', false),
                _bubble('Kenapa bisa turun ya, Dok?', true),
                _bubble(
                  'Buat paket hemat beras + kopi, lalu promo jam 16-19.',
                  false,
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(top: BorderSide(color: AppTheme.borderColor)),
          ),
          child: _field('Tanya dokter...', icon: Icons.edit_rounded),
        ),
      ],
    );
  }

  Widget _bubble(String text, bool mine) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: mine
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: mine
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : AppTheme.borderColor,
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 5,
            height: 1.3,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _tickets() {
    return Column(
      children: [
        Expanded(
          child: _pad(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bubble('Halo, ada yang bisa kami bantu?', false),
                _bubble('QRIS tidak muncul saat bayar. Ini fotonya.', true),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 26,
                      height: 20,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.image_rounded,
                        size: 9,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: const Center(
                        child: Text(
                          'bukti.pdf',
                          style: TextStyle(
                            fontSize: 4,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(top: BorderSide(color: AppTheme.borderColor)),
          ),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.attach_file_rounded,
                  size: 8,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: _field('Tulis balasan...', icon: Icons.edit_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settings() {
    return _pad(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Pengaturan'),
          const SizedBox(height: 5),
          _settingRow(Icons.store_rounded, 'Profil Toko'),
          _settingRow(Icons.people_outline, 'Karyawan & Akses'),
          _settingRow(Icons.credit_card_rounded, 'QRIS Toko'),
          _settingRow(Icons.menu_book_rounded, 'Panduan'),
          _settingRow(Icons.support_agent_rounded, 'Tiket Bantuan'),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.help_outline, size: 8, color: AppTheme.primaryColor),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Bantuan & Tutorial',
                    style: TextStyle(
                      fontSize: 5.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 8,
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 7, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 5.2,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 7,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buyerRadar() {
    return _pad(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.near_me_rounded, size: 8, color: AppTheme.primaryColor),
              SizedBox(width: 3),
              Text(
                'Lokasi: -6.3950, 106.8410',
                style: TextStyle(fontSize: 5, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _chip('3 km', AppTheme.primaryColor),
              const SizedBox(width: 2),
              _chip('5 km', AppTheme.textSecondary),
              const SizedBox(width: 2),
              _chip('10 km', AppTheme.textSecondary),
            ],
          ),
          const SizedBox(height: 5),
          _nearbyCard(Icons.storefront_rounded, 'Toko Test', '250 m',
              delivery: true),
          _nearbyCard(Icons.storefront_rounded, 'Gerobak Test', '400 m',
              delivery: false),
          _nearbyCard(Icons.storefront_rounded, 'Warung Test', '1,2 km',
              delivery: true),
        ],
      ),
    );
  }

  Widget _nearbyCard(IconData icon, String name, String distance,
      {required bool delivery}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 9, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 5.8,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  distance,
                  style: const TextStyle(
                    fontSize: 4.8,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _chip(delivery ? 'Diantar' : 'Ambil', AppTheme.successColor),
        ],
      ),
    );
  }

  Widget _buyerCatalog() {
    return _pad(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Katalog Toko Test'),
          const SizedBox(height: 5),
          _field('Cari produk di toko ini...'),
          const SizedBox(height: 5),
          _buyerProductRow(Icons.rice_bowl_rounded, 'Beras 5 kg', 'Rp62.000'),
          _buyerProductRow(Icons.local_cafe_rounded, 'Kopi Sachet', 'Rp2.000'),
          _buyerProductRow(
            Icons.bakery_dining_rounded,
            'Roti Bakar',
            'Rp12.000',
          ),
        ],
      ),
    );
  }

  Widget _buyerProductRow(IconData icon, String name, String price) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 9, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 5.6,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 5,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'Tambah',
              style: TextStyle(
                fontSize: 4.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buyerCart() {
    return Column(
      children: [
        _pad(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('Keranjang'),
              _sub('1 toko per transaksi'),
              const SizedBox(height: 5),
              _line('Beras 5 kg', 'x1', 'Rp62.000'),
              _line('Kopi Sachet', 'x2', 'Rp4.000'),
              const Divider(height: 7, color: AppTheme.borderColor),
              Row(
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 5.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Rp66.000',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(top: BorderSide(color: AppTheme.borderColor)),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'Lanjut ke Checkout',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 6,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buyerCheckout() {
    return Column(
      children: [
        _pad(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('Checkout'),
              _sub('Bayar tunai atau QRIS saat pesanan diterima'),
              const SizedBox(height: 5),
              _field('Nama', icon: Icons.person_rounded),
              const SizedBox(height: 3),
              _field('No. WhatsApp', icon: Icons.phone_rounded),
              const SizedBox(height: 5),
              _line('Total + kode unik', '', 'Rp66.140'),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(top: BorderSide(color: AppTheme.borderColor)),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'Buat Pesanan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.6),
                  ),
                ),
                child: const Text(
                  'area navigasi HP',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 4.5, color: AppTheme.warningColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buyerTracking() {
    return _pad(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Lacak Pesanan'),
          _sub('Kode ORD2610...'),
          const SizedBox(height: 6),
          _trackStep(0, 'Pesanan dibuat', true),
          _trackStep(1, 'Sedang diproses', true),
          _trackStep(2, 'Pesanan siap / dikirim', false),
        ],
      ),
    );
  }

  Widget _trackStep(int i, String label, bool done) {
    final color = done ? AppTheme.successColor : AppTheme.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: done ? AppTheme.successColor : AppTheme.surfaceColor,
                shape: BoxShape.circle,
                border: Border.all(color: color),
              ),
              child: done
                  ? const Icon(Icons.check_rounded,
                      size: 6, color: Colors.white)
                  : null,
            ),
            if (i < 2)
              Container(
                width: 1,
                height: 14,
                color: done
                    ? AppTheme.successColor
                    : AppTheme.borderColor,
              ),
          ],
        ),
        const SizedBox(width: 5),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 5.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
