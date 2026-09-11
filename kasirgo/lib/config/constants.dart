class AppConstants {
  static const String appName = 'KasirGo';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Aplikasi Kasir UMKM Indonesia';

  static const List<String> businessTypes = [
    'Warung Sembako',
    'Warung Madura',
    'Kelontong',
    'Retail',
    'Cafe',
    'Restoran',
    'Kedai Kopi',
    'Minimarket',
    'Toko Baju',
    'Apotek',
    'Lainnya',
  ];

  static const List<String> paymentMethods = [
    'Tunai',
    'QRIS',
    'Transfer',
    'GoPay',
    'OVO',
    'DANA',
    'ShopeePay',
  ];

  static const List<String> subscriptionTiers = [
    'free',
    'basic_25',
    'pro_50',
  ];

  static const List<String> userRoles = [
    'owner',
    'admin',
    'cashier',
    'customer',
  ];

  static const int syncIntervalSeconds = 30;
  static const int freeTierMaxProducts = 500;
  static const int freeTierMaxTransactions = 500;
}