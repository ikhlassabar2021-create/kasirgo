/// ST17-4 (Phase 17 - Ekosistem Hyper-Local): mode ganda SATU APK.
/// Penjual = owner/admin/kasir/koki (POS). Pembeli = customer shell.
enum AppMode {
  seller,
  buyer;

  String get label => switch (this) {
        AppMode.seller => 'Penjual',
        AppMode.buyer => 'Pembeli',
      };

  String get tagline => switch (this) {
        AppMode.seller => 'Kelola warung: kasir, produk, stok & laporan',
        AppMode.buyer => 'Cari warung sekitar & pesan tanpa antre',
      };

  /// Nilai yang disimpan di penyimpanan lokal.
  String get storageValue => name;

  static AppMode? fromStorage(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final mode in AppMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}
