import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../services/app_update_service.dart';
import '../../utils/device_abi.dart';
import '../../utils/web_reload_stub.dart'
    if (dart.library.html) '../../utils/web_reload_web.dart' as platform;

/// Layar pembaruan aplikasi. Menampilkan versi baru + changelog dan tombol
/// download (Android) / muat ulang (web). Update tidak pernah menyentuh
/// database lokal (SQLite) — aplikasi hanya di-upgrade di sisi aplikasi.
class AppUpdateScreen extends StatelessWidget {
  const AppUpdateScreen({super.key, required this.release});

  final AppReleaseInfo release;

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
          'Pembaruan Aplikasi',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
              ),
              borderRadius: BorderRadius.circular(18),
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
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.system_update_alt_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Versi ${release.version} tersedia',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Versi saat ini ${AppConstants.appVersion} '
                            '(build ${AppConstants.appBuildNumber})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (release.forceUpdate) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Pembaruan wajib',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (release.changelog.trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yang baru',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    release.changelog,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, AppTheme.touchTargetLarge),
                backgroundColor: AppTheme.primaryColor,
              ),
              onPressed: () => _onPrimaryAction(context),
              icon: Icon(
                kIsWeb
                    ? Icons.refresh_rounded
                    : Icons.download_rounded,
                size: 18,
              ),
              label: Text(
                kIsWeb ? 'Muat Ulang Sekarang' : 'Unduh Pembaruan (APK)',
              ),
            ),
          ),
          if (release.hasGuide) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppTheme.touchTargetLarge),
                ),
                onPressed: () => _openGuide(context),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: const Text('Buka Panduan'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Data toko (produk, transaksi, pengaturan) aman dan tidak akan '
            'terhapus saat pembaruan.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _onPrimaryAction(BuildContext context) async {
    if (kIsWeb) {
      platform.webReload();
      return;
    }
    String? url;
    try {
      final abi = await deviceAbi();
      url = abi == null ? null : release.fileUrlFor(abi);
    } catch (_) {
      url = release.fileUrlFor('arm64');
    }
    if (url == null || url.trim().isEmpty) {
      _snack(context, 'Belum ada APK yang cocok untuk perangkat Anda.');
      return;
    }
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        _snack(context, 'Tidak bisa membuka tautan unduhan.');
      }
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'Gagal mengunduh APK. Silakan coba lagi.');
      }
    }
  }

  void _openGuide(BuildContext context) async {
    final url = release.guideUrl;
    if (url == null || url.trim().isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'Gagal membuka panduan.');
      }
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}