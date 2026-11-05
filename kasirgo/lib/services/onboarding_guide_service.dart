import 'package:shared_preferences/shared_preferences.dart';

/// Satu langkah panduan bersuara untuk pendaftar baru.
///
/// [scene] menunjuk ke simulasi layar `GuideMock`, [spoken] adalah teks yang
/// dibacakan robot pemandu lewat `VoiceService`.
class OnboardingGuideStep {
  final String title;
  final String body;
  final String scene;
  final String spoken;

  const OnboardingGuideStep({
    required this.title,
    required this.body,
    required this.scene,
    required this.spoken,
  });
}

/// Data + penanda penyelesaian panduan bersuara "selamat datang".
///
/// Panduan ini muncul otomatis sekali setelah pemilik pertama kali masuk
/// (pasca KYC) dan bisa dibuka ulang dari kartu "Langkah Awal Berjualan".
class OnboardingGuideService {
  static const _doneKey = 'kasirgo_onboarding_guide_seen_v1';

  static const steps = <OnboardingGuideStep>[
    OnboardingGuideStep(
      title: 'Kenalan dulu',
      body:
          'Selamat datang di KasirGo! Aku robot pemandu yang akan menemanimu '
          'menyiapkan toko langkah demi langkah. Setiap langkah akan kubacakan '
          'dengan suara.',
      scene: 'dashboard',
      spoken:
          'Halo Bos! Selamat datang di KasirGo. Saya robot pemandu yang akan '
          'menemani kamu menyiapkan toko, langkah demi langkah. Tenang saja, '
          'kita mulai pelan-pelan ya.',
    ),
    OnboardingGuideStep(
      title: 'Kenali beranda',
      body:
          'Di beranda ada kartu omzet hari ini, jumlah transaksi, grafik '
          'penjualan 7 hari terakhir, dan tombol cepat untuk membuka fitur '
          'utama seperti Kasir, Produk, Pesanan, dan Laporan.',
      scene: 'dashboard',
      spoken:
          'Ini berandamu. Di sini kamu bisa lihat omzet hari ini, jumlah '
          'transaksi, dan grafik penjualan tujuh hari terakhir. Semua fitur '
          'utama bisa dibuka dari tombol cepat di bawah.',
    ),
    OnboardingGuideStep(
      title: 'Pilih tipe usaha',
      body:
          'Agar fitur yang tampil sesuai usahamu, pilih tipe usaha dulu di '
          'kartu "Langkah Awal Berjualan". Tekan tombol Pilih, lalu pilih yang '
          'paling cocok, misalnya Warung Sembako atau Cafe.',
      scene: 'settings',
      spoken:
          'Sekarang, pilih tipe usahamu. Buka kartu Langkah Awal Berjualan, '
          'tekan tombol Pilih, lalu pilih yang paling cocok, misalnya Warung '
          'Sembako atau Cafe. Fitur yang tampil akan menyesuaikan usahamu.',
    ),
    OnboardingGuideStep(
      title: 'Tambahkan produk',
      body:
          'Buka menu Produk, tekan tombol Tambah, lalu isi nama, harga jual, '
          'dan stok awal. Setelah disimpan, produk langsung bisa dijual di '
          'kasir.',
      scene: 'products',
      spoken:
          'Selanjutnya, tambahkan produk pertamamu. Buka menu Produk, tekan '
          'tombol tambah, isi nama, harga jual, dan stok awal. Setelah '
          'disimpan, produk langsung bisa dijual di kasir.',
    ),
    OnboardingGuideStep(
      title: 'Coba transaksi pertama',
      body:
          'Buka Kasir, ketuk produk untuk menambahkannya ke keranjang, atur '
          'jumlahnya, lalu tekan Bayar. Pilih tunai atau QRIS. Stok berkurang '
          'dan omzet tercatat otomatis.',
      scene: 'pos',
      spoken:
          'Terakhir, coba transaksi pertamamu. Buka Kasir, ketuk produk untuk '
          'memasukkannya ke keranjang, lalu tekan Bayar. Pilih tunai atau '
          'QRIS. Stok berkurang dan omzet tercatat otomatis.',
    ),
    OnboardingGuideStep(
      title: 'Siap berjualan',
      body:
          'Mantap, tokomu sudah siap! Pantau omzet di menu Laporan, dan bila '
          'butuh bantuan buka Bantuan & Tutorial atau hubungi tim support.',
      scene: 'reports',
      spoken:
          'Selesai! Tokomu sudah siap berjualan. Kamu bisa pantau omzet kapan '
          'saja di menu Laporan. Kalau butuh bantuan, buka Bantuan dan '
          'Tutorial, atau hubungi tim support. Selamat berjualan, Bos!',
    ),
  ];

  /// Apakah panduan bersuara sudah pernah dilihat / diselesaikan.
  Future<bool> isDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_doneKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Tandai panduan sudah dilihat agar tidak muncul otomatis lagi.
  Future<void> markDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_doneKey, true);
    } catch (_) {}
  }

  /// Reset penanda (dipakai untuk pengujian / QA).
  Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_doneKey);
    } catch (_) {}
  }
}