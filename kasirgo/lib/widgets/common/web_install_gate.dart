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

/// Info tipe APK: label ramah, deskripsi spek HP, dan ABI.
class _AbiOption {
  final String abi;
  final String title;
  final String spec;
  final bool recommended;

  const _AbiOption({
    required this.abi,
    required this.title,
    required this.spec,
    this.recommended = false,
  });
}

const List<_AbiOption> _abiOptions = [
  _AbiOption(
    abi: 'arm64',
    title: 'APK untuk HP Terbaru',
    spec: 'Direkomendasikan. Untuk hampir semua HP Android keluaran 2019 ke atas '
        '(prosesor 64-bit: Snapdragon, MediaTek, Dimensity, Exynos).',
    recommended: true,
  ),
  _AbiOption(
    abi: 'armeabi_v7a',
    title: 'APK untuk HP Lama',
    spec: 'Untuk HP Android lama dengan spesifikasi rendah (prosesor 32-bit, '
        'biasanya Android 5–8 atau RAM < 2 GB).',
  ),
  _AbiOption(
    abi: 'x86_64',
    title: 'APK untuk Emulator / Intel',
    spec: 'Untuk emulator Android di PC atau perangkat berprosesor Intel x86_64 '
        '(jarang dipakai di HP biasa).',
  ),
];

class _WebInstallGateState extends State<WebInstallGate> {
  final _service = AppUpdateService();

  // Fallback bila belum ada rilis `app_releases` yang dipublikasikan.
  static const String _releaseBase =
      'https://github.com/ikhlassabar2021-create/kasirgo/releases/download/'
      'v1.0.10-signed-20261102/';
  static const Map<String, String> _fallbackFiles = {
    'arm64': '${_releaseBase}kasirgo-1.0.10-arm64-v8a.apk',
    'armeabi_v7a': '${_releaseBase}kasirgo-1.0.10-armeabi-v7a.apk',
    'x86_64': '${_releaseBase}kasirgo-1.0.10-x86_64.apk',
  };

  Map<String, String> _urls = _fallbackFiles;
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
    for (final opt in _abiOptions) {
      final fromRelease = rel?.fileUrlFor(opt.abi);
      urls[opt.abi] = (fromRelease != null && fromRelease.trim().isNotEmpty)
          ? fromRelease.trim()
          : (_fallbackFiles[opt.abi] ?? '');
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
                    constraints: const BoxConstraints(maxWidth: 560),
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
                          'Android KasirGo. Unduh dan pasang APK yang sesuai dengan '
                          'HP Anda, lalu masuk dengan akun yang sama dan selesaikan '
                          'verifikasi.',
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
                          onPressed: () => _download('arm64'),
                        ),
                        const SizedBox(height: 20),
                        ..._buildAbiCards(),
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

  List<Widget> _buildAbiCards() {
    return _abiOptions.map((opt) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: AppTheme.shadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    opt.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (opt.recommended)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Direkomendasikan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              opt.spec,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Download',
                icon: Icons.download_rounded,
                variant: opt.recommended
                    ? AppButtonVariant.primary
                    : AppButtonVariant.outline,
                height: AppTheme.touchTargetLarge,
                onPressed: () => _download(opt.abi),
              ),
            ),
          ],
        ),
      );
    }).toList();
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