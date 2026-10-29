import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../widgets/common/centennial_background.dart';
import '../../widgets/common/supporter_gate.dart';
import '../../widgets/guide/guide_mock.dart';
import '../cashier/incoming_orders_screen.dart';
import 'business_doctor_screen.dart';
import 'employee_screen.dart';
import 'guide_screen.dart';
import 'pos_screen.dart';
import 'product_list_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'support_tickets_screen.dart';

/// Pusat bantuan owner: Panduan bergambar (simulasi layar) + Tiket Support.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
          title: Text(
            'Bantuan & Tutorial',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          bottom: TabBar(
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryColor,
            labelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
            ),
            tabs: const [
              Tab(text: 'Panduan'),
              Tab(text: 'Tiket Support'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_GuideHomeTab(), SupportTicketsScreen(embedded: true)],
        ),
      ),
    );
  }
}

class _GuideHomeTab extends StatelessWidget {
  const _GuideHomeTab();

  @override
  Widget build(BuildContext context) {
    return CentennialBackground(
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
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Panduan Bergambar',
                        style: GoogleFonts.plusJakartaSans(
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
                  'Lihat simulasi layar dan langkah singkat untuk setiap fitur. '
                  'Cocok untuk pemula, bisa dibuka tanpa internet.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GuideScreen(),
                          ),
                        ),
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 17,
                        ),
                        label: const Text('Panduan PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SupportTicketsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.support_agent_rounded, size: 17),
                        label: const Text('Tanya Tim'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pilih topik',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...HelpTopicData.topics.map((t) => _TopicCard(topic: t)),
          const SizedBox(height: 8),
          Text(
            'Tips: tombol penting selalu diberi jarak dari area navigasi HP '
            'agar tidak terhalang.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});

  final HelpTopic topic;

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
            MaterialPageRoute(builder: (_) => HelpTopicScreen(topic: topic)),
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
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HelpTopicScreen extends StatelessWidget {
  const HelpTopicScreen({super.key, required this.topic});

  final HelpTopic topic;

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
        itemCount: topic.steps.length + 1,
        itemBuilder: (context, i) {
          if (i == topic.steps.length) return _footer(context);
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
                if (step.tip != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.warningColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 16,
                          color: AppTheme.warningColor,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            step.tip!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              height: 1.45,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (step.action != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openAction(context, step.action!),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(step.actionLabel ?? 'Buka fitur'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Masih bingung?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kirim tiket dan lampirkan screenshot. Tim KasirGo siap bantu.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportTicketsScreen()),
              ),
              icon: const Icon(Icons.support_agent_rounded, size: 17),
              label: const Text('Buat Tiket Bantuan'),
            ),
          ),
        ],
      ),
    );
  }

  void _openAction(BuildContext context, String action) {
    Widget? screen;
    switch (action) {
      case 'products':
        screen = const ProductListScreen();
        break;
      case 'pos':
      case 'checkout':
        screen = const PosScreen();
        break;
      case 'orders':
        screen = const IncomingOrdersScreen();
        break;
      case 'reports':
        screen = const ReportScreen();
        break;
      case 'employees':
        screen = const EmployeeScreen();
        break;
      case 'settings':
        screen = const SettingsScreen();
        break;
      case 'tickets':
        screen = const SupportTicketsScreen();
        break;
      case 'doctor':
        screen = const SupporterFeatureGate(
          featureKey: 'business_doctor',
          child: BusinessDoctorScreen(),
        );
        break;
    }
    if (screen == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
  }
}

class HelpTopic {
  const HelpTopic({
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
  final List<HelpStep> steps;
}

class HelpStep {
  const HelpStep({
    required this.title,
    required this.body,
    required this.scene,
    this.tip,
    this.action,
    this.actionLabel,
  });

  final String title;
  final String body;
  final String scene;
  final String? tip;
  final String? action;
  final String? actionLabel;
}

class HelpTopicData {
  static const topics = <HelpTopic>[
    HelpTopic(
      title: 'Mulai & Atur Toko',
      subtitle: 'Kenali beranda, lengkapi profil, dan siapkan produk.',
      icon: Icons.storefront_rounded,
      color: Color(0xFF0284C7),
      steps: [
        HelpStep(
          title: 'Kenali beranda',
          body:
              'Kartu omzet hari ini, transaksi, dan tombol cepat ada di '
              'beranda. Semua fitur utama bisa dibuka dari sini.',
          scene: 'dashboard',
          tip: 'Grafik kecil menunjukkan pola penjualan 7 hari terakhir.',
          action: 'settings',
          actionLabel: 'Buka Pengaturan',
        ),
        HelpStep(
          title: 'Lengkapi profil & KYC',
          body:
              'Isi nama toko, alamat, dan verifikasi KYC. Data ini dipakai '
              'untuk katalog online dan pencairan pembayaran.',
          scene: 'settings',
          tip:
              'KYC hanya perlu sekali. Status verifikasi tampil di Pengaturan.',
          action: 'settings',
          actionLabel: 'Buka Pengaturan',
        ),
        HelpStep(
          title: 'Tambahkan produk',
          body:
              'Tekan tombol +, isi nama, harga, dan stok. Produk jasa bisa '
              'diaktifkan tanpa stok.',
          scene: 'products',
          action: 'products',
          actionLabel: 'Buka Produk',
        ),
      ],
    ),
    HelpTopic(
      title: 'Jualan di Kasir (POS)',
      subtitle: 'Pilih produk, atur jumlah, lalu bayar tunai atau QRIS.',
      icon: Icons.point_of_sale_rounded,
      color: Color(0xFF10B981),
      steps: [
        HelpStep(
          title: 'Pilih produk',
          body:
              'Cari produk lewat kolom pencarian atau ketuk kartu produk. '
              'Badge stok membantu memantau ketersediaan.',
          scene: 'products',
          action: 'pos',
          actionLabel: 'Buka Kasir',
        ),
        HelpStep(
          title: 'Atur keranjang',
          body:
              'Ubah jumlah dengan tombol + / -, tambahkan diskon bila perlu. '
              'Total diperbarui otomatis.',
          scene: 'pos',
          action: 'pos',
          actionLabel: 'Buka Kasir',
        ),
        HelpStep(
          title: 'Selesaikan pembayaran',
          body:
              'Tekan Bayar, pilih metode, lalu konfirmasi. Tombol Buat Pesanan '
              'selalu berada di atas area navigasi HP sehingga tidak terhalang.',
          scene: 'checkout',
          tip:
              'Setelah sukses, struk bisa disimpan sebagai PDF atau dikirim '
              'lewat WhatsApp.',
          action: 'pos',
          actionLabel: 'Coba di Kasir',
        ),
      ],
    ),
    HelpTopic(
      title: 'Pesanan Online & QR Meja',
      subtitle:
          'Tangani pesanan masuk, konfirmasi bayar, lalu proses di dapur.',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFF59E0B),
      steps: [
        HelpStep(
          title: 'Lihat pesanan masuk',
          body:
              'Tab Pesanan menampilkan pesanan Dine-in dan Online. Badge '
              'merah berarti ada pesanan yang menunggu konfirmasi.',
          scene: 'orders',
          action: 'orders',
          actionLabel: 'Buka Pesanan Masuk',
        ),
        HelpStep(
          title: 'Konfirmasi pembayaran',
          body:
              'Periksa nominal, lalu tekan Konfirmasi Bayar setelah uang atau '
              'QRIS diterima. Status berubah menjadi Diproses.',
          scene: 'orders',
          tip: 'Pesanan belum dibayar tidak masuk antrean dapur (KDS).',
          action: 'orders',
          actionLabel: 'Buka Pesanan Masuk',
        ),
        HelpStep(
          title: 'Pantau dari laporan',
          body: 'Semua pesanan yang lunas ikut terhitung di laporan omzet.',
          scene: 'reports',
          action: 'reports',
          actionLabel: 'Buka Laporan',
        ),
      ],
    ),
    HelpTopic(
      title: 'Laporan & Performa',
      subtitle: 'Pantau omzet, laba, produk terlaris, dan progres usaha.',
      icon: Icons.insights_rounded,
      color: Color(0xFF4F46E5),
      steps: [
        HelpStep(
          title: 'Baca ringkasan',
          body:
              'Pilih periode 7 hari, 30 hari, atau rentang tanggal sendiri. '
              'Ringkasan menampilkan omzet, laba kotor, dan jumlah transaksi.',
          scene: 'reports',
          action: 'reports',
          actionLabel: 'Buka Laporan',
        ),
        HelpStep(
          title: 'Ekspor laporan',
          body:
              'Unduh Excel atau PDF format SAK EMKM untuk arsip dan '
              'kebutuhan pembukuan.',
          scene: 'reports',
          tip: 'File terunduh langsung dari HP; tidak perlu email.',
          action: 'reports',
          actionLabel: 'Buka Laporan',
        ),
        HelpStep(
          title: 'Minta saran Dokter Bisnis',
          body:
              'Dokter Bisnis AI menganalisis tren, stok, dan margin, lalu '
              'memberi resep perbaikan yang bisa langsung dijalankan.',
          scene: 'doctor',
          action: 'doctor',
          actionLabel: 'Buka Dokter Bisnis AI',
        ),
      ],
    ),
    HelpTopic(
      title: 'Karyawan & Hak Akses',
      subtitle: 'Buat akun staf, atur peran, dan jaga keamanan data.',
      icon: Icons.people_alt_rounded,
      color: Color(0xFF06B6D4),
      steps: [
        HelpStep(
          title: 'Tambah karyawan',
          body:
              'Pilih peran Admin, Kasir, atau Koki. Kuota gratis 2 akun; '
              'Program Pendukung membuka staf tanpa batas.',
          scene: 'employees',
          action: 'employees',
          actionLabel: 'Buka Karyawan',
        ),
        HelpStep(
          title: 'Batasi akses',
          body:
              'Admin bisa menambah produk dan melihat laporan, tetapi tidak '
              'bisa menghapus produk. Kasir hanya membuat transaksi.',
          scene: 'employees',
          action: 'employees',
          actionLabel: 'Buka Karyawan',
        ),
        HelpStep(
          title: 'Jaga kata sandi',
          body:
              'Minta staf mengganti kata sandi awal. Owner dapat mereset '
              'kata sandi staf dari menu Karyawan.',
          scene: 'settings',
          tip: 'Jangan bagikan akun owner kepada staf.',
          action: 'settings',
          actionLabel: 'Buka Pengaturan',
        ),
      ],
    ),
    HelpTopic(
      title: 'Bantuan, AI & Lampiran',
      subtitle: 'Gunakan panduan, tiket support, dan kirim screenshot.',
      icon: Icons.support_agent_rounded,
      color: Color(0xFFEF4444),
      steps: [
        HelpStep(
          title: 'Buka pusat bantuan',
          body:
              'Semua panduan dan tiket support ada di Bantuan & Tutorial, '
              'bisa dibuka dari menu samping atau Pengaturan.',
          scene: 'settings',
          action: 'tickets',
          actionLabel: 'Buka Tiket Support',
        ),
        HelpStep(
          title: 'Lampirkan bukti',
          body:
              'Saat membuat tiket atau membalas, ketuk ikon klip untuk '
              'melampirkan gambar atau berkas (maksimal 3 berkas, 10 MB).',
          scene: 'tickets',
          tip:
              'Screenshot membantu tim menemukan penyebab masalah lebih cepat.',
          action: 'tickets',
          actionLabel: 'Buat / Buka Tiket',
        ),
        HelpStep(
          title: 'Pantau balasan',
          body:
              'Balasan tim KasirGo muncul di tiket. Owner bisa menutup tiket '
              'atau membukanya kembali bila masalah belum selesai.',
          scene: 'tickets',
          action: 'tickets',
          actionLabel: 'Lihat Tiket',
        ),
      ],
    ),
  ];
}
