import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QrisConfig {
  final String merchantName;
  final String nmid;
  final String bankOrWallet;
  final String qrisString;

  /// Gambar QRIS statis yang diupload owner (base64 data, tanpa prefix).
  final String imageBase64;

  const QrisConfig({
    this.merchantName = '',
    this.nmid = '',
    this.bankOrWallet = '',
    this.qrisString = '',
    this.imageBase64 = '',
  });

  bool get hasImage => imageBase64.trim().isNotEmpty;

  bool get isConfigured =>
      merchantName.trim().isNotEmpty &&
      (hasImage || nmid.trim().isNotEmpty || qrisString.trim().isNotEmpty);

  Map<String, dynamic> toJson() => {
        'merchant_name': merchantName,
        'nmid': nmid,
        'bank_or_wallet': bankOrWallet,
        'qris_string': qrisString,
        'image_base64': imageBase64,
      };

  factory QrisConfig.fromJson(Map<String, dynamic> json) => QrisConfig(
        merchantName: json['merchant_name']?.toString() ?? '',
        nmid: json['nmid']?.toString() ?? '',
        bankOrWallet: json['bank_or_wallet']?.toString() ?? '',
        qrisString: json['qris_string']?.toString() ?? '',
        imageBase64: json['image_base64']?.toString() ?? '',
      );

  QrisConfig copyWith({
    String? merchantName,
    String? nmid,
    String? bankOrWallet,
    String? qrisString,
    String? imageBase64,
  }) =>
      QrisConfig(
        merchantName: merchantName ?? this.merchantName,
        nmid: nmid ?? this.nmid,
        bankOrWallet: bankOrWallet ?? this.bankOrWallet,
        qrisString: qrisString ?? this.qrisString,
        imageBase64: imageBase64 ?? this.imageBase64,
      );

  static String keyFor(String outletId) => 'qris_config_$outletId';

  static Future<void> save({required String outletId, required QrisConfig config}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyFor(outletId), jsonEncode(config.toJson()));
    } catch (_) {}
  }

  static Future<QrisConfig> load({required String outletId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(outletId));
      if (raw == null || raw.isEmpty) return const QrisConfig();
      final decoded = jsonDecode(raw) as Map;
      return QrisConfig.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const QrisConfig();
    }
  }
}
