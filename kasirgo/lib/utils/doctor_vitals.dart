import '../models/customer.dart';
import '../models/product.dart';
import '../models/transaction.dart';

/// Tiga tanda vital usaha untuk layar hasil pemeriksaan Dokter Bisnis.
///
/// Semua perhitungan dilakukan lokal dari data yang sudah dimuat aplikasi
/// (produk, transaksi, pelanggan) sehingga tidak menambah beban server.
class DoctorVital {
  const DoctorVital({
    required this.key,
    required this.label,
    required this.score,
    required this.hint,
  });

  final String key;
  final String label;
  final int score;
  final String hint;

  bool get isGood => score >= 70;
  bool get isWarning => score >= 40 && score < 70;
}

class DoctorVitals {
  const DoctorVitals({
    required this.cashflow,
    required this.stock,
    required this.customer,
  });

  final DoctorVital cashflow;
  final DoctorVital stock;
  final DoctorVital customer;

  List<DoctorVital> get all => [cashflow, stock, customer];

  int get average {
    if (all.isEmpty) return 0;
    final total = all.fold<int>(0, (a, v) => a + v.score);
    return (total / all.length).round();
  }

  static bool _isPaid(Transaction t) {
    final status = t.paymentStatus?.toLowerCase();
    if (status == 'voided' || status == 'batal') return false;
    return true;
  }

  static DoctorVitals build({
    required List<Product> products,
    required List<Transaction> transactions,
    required List<Customer> customers,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final paid = transactions.where(_isPaid).toList();

    int revenueBetween(DateTime from, DateTime to) => paid
        .where((t) => !t.createdAt.isBefore(from) && t.createdAt.isBefore(to))
        .fold<int>(0, (a, t) => a + t.finalAmount.round());

    final last7 = revenueBetween(today.subtract(const Duration(days: 7)), today);
    final prev7 = revenueBetween(
      today.subtract(const Duration(days: 14)),
      today.subtract(const Duration(days: 7)),
    );

    int cashScore;
    String cashHint;
    if (prev7 <= 0 && last7 <= 0) {
      cashScore = 30;
      cashHint = 'Belum ada penjualan minggu ini. Catat transaksi dulu.';
    } else if (prev7 <= 0) {
      cashScore = 75;
      cashHint = 'Penjualan mulai jalan. Jaga ritme harian.';
    } else {
      final ratio = last7 / prev7;
      if (ratio >= 1.2) {
        cashScore = 90;
        cashHint = 'Kas naik dibanding minggu lalu. Pertahankan.';
      } else if (ratio >= 0.95) {
        cashScore = 70;
        cashHint = 'Kas stabil. Dorong sedikit promo untuk naik.';
      } else if (ratio >= 0.7) {
        cashScore = 50;
        cashHint = 'Kas melambat. Cek produk favorit dan jam ramai.';
      } else {
        cashScore = 30;
        cashHint = 'Kas turun tajam. Perlu aksi cepat minggu ini.';
      }
    }

    final sellable = products.where((p) => p.isActive).toList();
    final healthy =
        sellable.where((p) => p.isService || p.stock > 0).length;
    final stockScore = sellable.isEmpty
        ? 40
        : ((healthy / sellable.length) * 100).round().clamp(0, 100);
    final emptyCount = sellable
        .where((p) => !p.isService && p.stock <= 0)
        .length;
    final stockHint = sellable.isEmpty
        ? 'Belum ada produk aktif. Tambahkan produk dulu.'
        : emptyCount == 0
            ? 'Semua produk tersedia. Stok sehat.'
            : '$emptyCount produk kosong. Segera isi ulang.';

    final txWithCustomer =
        paid.where((t) => (t.customerId ?? '').isNotEmpty).length;
    final repeat = customers
        .where((c) => (c.totalTransactions ?? 0) >= 2)
        .length;
    int customerScore;
    String customerHint;
    if (paid.isEmpty) {
      customerScore = 35;
      customerHint = 'Belum ada data pelanggan. Mulai catat nomor WA.';
    } else if (repeat > 0) {
      final ratio = repeat / (customers.isEmpty ? 1 : customers.length);
      customerScore = (55 + ratio * 45).round().clamp(0, 100);
      customerHint =
          '$repeat pelanggan langganan. Beri apresiasi lewat WA.';
    } else {
      final ratio = txWithCustomer / paid.length;
      customerScore = (30 + ratio * 40).round().clamp(0, 100);
      customerHint = txWithCustomer == 0
          ? 'Transaksi belum terhubung pelanggan. Catat nomor WA.'
          : '$txWithCustomer transaksi punya data pelanggan. Ajak kembali.';
    }

    return DoctorVitals(
      cashflow: DoctorVital(
        key: 'detak_kas',
        label: 'Detak Kas',
        score: cashScore,
        hint: cashHint,
      ),
      stock: DoctorVital(
        key: 'napas_stok',
        label: 'Napas Stok',
        score: stockScore,
        hint: stockHint,
      ),
      customer: DoctorVital(
        key: 'imun_pelanggan',
        label: 'Imun Pelanggan',
        score: customerScore,
        hint: customerHint,
      ),
    );
  }
}
