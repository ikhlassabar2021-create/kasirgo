import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../services/app_update_service.dart';
import 'app_button.dart';
import 'centennial_background.dart';

/// Layar pemblokir khusus WEB: pemilik belum terverifikasi KYC.
///
/// Pemilik wajib memasang APK Android dan menyelesaikan verifikasi di sana.
/// Tidak ada fitur lain yang bisa diklik selain unduh APK, cek status, dan
/// keluar — memaksa klien memakai aplikasi, bukan web.
class WebInstallGate extends StatefulWidget {
  final VoidCallback onCheckStatus;
  final VoidCallback onLogout;

  const WebInstallGate({
    super.key,
    required this.onCheckStatus,
    required this.onLogout,
  });

  @override
  State<WebInstallGate> createState() => _WebInstallGateState();
}

class _WebInstallGateState extends State<WebInstallGate> {
  final _service = AppUpdateService();

  String _fallbackBase = 'https://dokterbisnis.web.id/updates/';
  Map<String, String> _urls = const {};
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    AppReleaseInfo? rel;
    try {
      rel = await _service.latestAndroid();
    } catch (_) {}
    if (!mounted) return;
    final urls = <String, String>{};
    const abis = {
      'arm64': 'kasirgo-arm64.apk',
      'armeabi_v7a': 'kasirgo-armeabi-v7a.apk',
      'x86_64': 'kasirgo-x86_64.apk',
    };
    for (final e in abis.entries) {
      final fromRelease = rel?.fileUrlFor(e.key);
      urls[e.key] = (fromRelease != null && fromRelease.trim().isNotEmpty)
          ? fromRelease.trim()
          : '${_fallbackBase}${e.value}';
    }
    setState(() => _urls = urls);
  }

  Future<void> _download(String abi) async {
    final url = _urls[abi];
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  }

  Future<void> _checkStatus() async {
    if (_checking) return;
    setState(() => _checking = true);
    await _load();
    if (!mounted) return;
    setState(() => _checking = false);
    widget.onCheckStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CentennialBackground(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        color: AppTheme.warningColor, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'KasirGo dipakai lewat aplikasi Android',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: const Text('Keluar'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.borderColor),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            height: 72,
                            width: 72,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Icon(Icons.android_rounded,
                                color: Colors.white, size: 40),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Pasang Aplikasi Android',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Verifikasi toko (KYC) hanya bisa dilakukan di aplikasi '
                          'Android KasirGo. Unduh dan pasang APK di bawah, lalu '
                          'masuk dengan akun yang sama dan selesaikan verifikasi.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _StepRow(no: '1', text: 'Unduh & pasang APK Android di bawah.'),
                        _StepRow(
                            no: '2', text: 'Buka aplikasi, masuk dengan akun ini.'),
                        _StepRow(
                            no: '3', text: 'Selesaikan verifikasi toko (KTP & selfie).'),
                        _StepRow(
                            no: '4', text: 'Kembali ke web dan tekan "Cek Kembali".'),
                        const SizedBox(height: 28),
                        AppButton(
                          label: 'Download APK Android',
                          icon: Icons.download_rounded,
                          onPressed: () =>
                              _download(_urls.containsKey('arm64') ? 'arm64' : 'armeabi_v7a'),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: 'ARM64',
                                variant: AppButtonVariant.outline,
                                height: AppTheme.touchTargetLarge,
                                onPressed: () => _download('arm64'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppButton(
                                label: 'armeabi-v7a',
                                variant: AppButtonVariant.outline,
                                height: AppTheme.touchTargetLarge,
                                onPressed: () => _download('armeabi_v7a'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppButton(
                                label: 'x86_64',
                                variant: AppButtonVariant.outline,
                                height: AppTheme.touchTargetLarge,
                                onPressed: () => _download('x86_64'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'Saya sudah terverifikasi — Cek Kembali',
                          icon: Icons.refresh_rounded,
                          variant: AppButtonVariant.secondary,
                          isLoading: _checking,
                          onPressed: _checkStatus,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Butuh bantuan? Hubungi dukungan KasirGo.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String no;
  final String text;

  const _StepRow({required this.no, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              no,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 1.4,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}