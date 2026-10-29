import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../widgets/common/centennial_background.dart';
import '../../widgets/guide/guide_mock.dart';

/// Panduan bergambar untuk Pembeli (radar -> katalog -> checkout -> lacak).
/// Dibuat dari simulasi layar (widget) + tombol buka fitur, bekerja offline.
class BuyerHelpScreen extends StatelessWidget {
  const BuyerHelpScreen({super.key});

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
          'Panduan Pembeli',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: CentennialBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shopping_bag_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Belanja di Warung Terdekat',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Temukan warung di dekatmu, pilih produk, lalu pesan untuk '
                    'diantar atau diambil sendiri. Semua langkah bergambar di bawah.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                      ),
                      onPressed: () => context.go('/buyer'),
                      icon: const Icon(Icons.storefront_rounded, size: 17),
                      label: const Text('Buka Beranda Pembeli'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final t in _BuyerTopicData.topics) _TopicCard(topic: t),
          ],
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});

  final _BuyerTopic topic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _BuyerTopicScreen(topic: topic)),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: topic.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(topic.icon, color: topic.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        topic.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          height: 1.35,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${topic.steps.length} langkah bergambar',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: topic.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BuyerTopicScreen extends StatelessWidget {
  const _BuyerTopicScreen({required this.topic});

  final _BuyerTopic topic;

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
          topic.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        itemCount: topic.steps.length,
        itemBuilder: (context, i) {
          final step = topic.steps[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
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
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: topic.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  step.body,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    height: 1.55,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                GuideMock(scene: step.scene, height: 232),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/buyer'),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(step.actionLabel),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BuyerTopic {
  const _BuyerTopic({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.steps,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_BuyerStep> steps;
}

class _BuyerStep {
  const _BuyerStep({
    required this.title,
    required this.body,
    required this.scene,
    required this.actionLabel,
  });

  final String title;
  final String body;
  final String scene;
  final String actionLabel;
}

class _BuyerTopicData {
  static const topics = <_BuyerTopic>[
    _BuyerTopic(
      title: 'Cari Warung Terdekat',
      subtitle: 'Aktifkan lokasi, atur radius, lalu pilih warung.',
      icon: Icons.near_me_rounded,
      color: Color(0xFF0284C7),
      steps: [
        _BuyerStep(
          title: 'Aktifkan lokasi',
          body:
              'Izinkan akses lokasi agar aplikasi bisa menampilkan warung dan '
              'gerobak di sekitarmu. Bisa diubah di pengaturan HP kapan saja.',
          scene: 'buyer_radar',
          actionLabel: 'Buka Radar Pembeli',
        ),
        _BuyerStep(
          title: 'Pilih radius',
          body:
              'Pilih 3, 5, atau 10 km. Cukup ketuk chip radius pada bagian atas '
              'daftar untuk memperluas atau mempersempit pencarian.',
          scene: 'buyer_radar',
          actionLabel: 'Coba Cari Warung',
        ),
      ],
    ),
    _BuyerTopic(
      title: 'Katalog & Keranjang',
      subtitle: 'Lihat produk warung, tambah ke keranjang.',
      icon: Icons.storefront_rounded,
      color: Color(0xFF10B981),
      steps: [
        _BuyerStep(
          title: 'Buka katalog warung',
          body:
              'Ketuk salah satu warung untuk melihat produknya. Cari produk '
              'lewat kolom pencarian bila daftarnya panjang.',
          scene: 'buyer_catalog',
          actionLabel: 'Lihat Katalog',
        ),
        _BuyerStep(
          title: 'Tambah ke keranjang',
          body:
              'Ketuk tombol Tambah pada produk. Satu keranjang hanya untuk satu '
              'warung agar ongkos dan totalnya jelas.',
          scene: 'buyer_cart',
          actionLabel: 'Buka Keranjang',
        ),
      ],
    ),
    _BuyerTopic(
      title: 'Checkout & Pembayaran',
      subtitle: 'Isi data, pilih diantar atau ambil, lalu buat pesanan.',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFF59E0B),
      steps: [
        _BuyerStep(
          title: 'Isi nama & nomor WA',
          body:
              'Nomor WhatsApp dipakai warung untuk konfirmasi pesanan. Pastikan '
              'nomornya aktif dan benar.',
          scene: 'buyer_checkout',
          actionLabel: 'Buka Checkout',
        ),
        _BuyerStep(
          title: 'Buat pesanan',
          body:
              'Tekan Buat Pesanan. Tombol ini selalu berada di atas area '
              'navigasi HP sehingga mudah ditekan. Bayar tunai atau QRIS saat '
              'pesanan diterima.',
          scene: 'buyer_checkout',
          actionLabel: 'Coba Buat Pesanan',
        ),
      ],
    ),
    _BuyerTopic(
      title: 'Lacak Pesanan',
      subtitle: 'Pantau status dari dibuat sampai siap/diantar.',
      icon: Icons.local_shipping_rounded,
      color: Color(0xFF4F46E5),
      steps: [
        _BuyerStep(
          title: 'Buka tab Pesanan',
          body:
              'Semua pesananmu ada di tab Pesanan. Ketuk salah satu untuk '
              'melihat status terbaru.',
          scene: 'buyer_tracking',
          actionLabel: 'Buka Pesanan Saya',
        ),
        _BuyerStep(
          title: 'Pantau status',
          body:
              'Status bergerak dari Dibuat, Diproses, sampai Siap / Diantar. '
              'Warung akan menghubungi lewat WhatsApp bila perlu.',
          scene: 'buyer_tracking',
          actionLabel: 'Lihat Lacak Pesanan',
        ),
      ],
    ),
  ];
}