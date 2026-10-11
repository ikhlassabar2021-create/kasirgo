import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../models/app_mode.dart';
import '../../providers/app_mode_provider.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/centennial_background.dart';

/// ST17-4 (Phase 17 - Ekosistem Hyper-Local): pemilih mode ganda (Penjual/Pembeli).
/// Ditampilkan sekali saat pertama buka; pilihan disimpan lokal.
/// Perpindahan layar ditangani [ModeGate] secara reaktif.
class ModeSelectScreen extends ConsumerStatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  ConsumerState<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends ConsumerState<ModeSelectScreen> {
  bool _busy = false;

  Future<void> _choose(AppMode mode) async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(appModeProvider.notifier).select(mode);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CentennialBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppTheme.formMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBrand(),
                    const SizedBox(height: 28),
                    Text(
                      'Mau pakai KasirGo untuk apa?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pilih satu. Anda bisa ganti mode kapan saja di Pengaturan.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ModeCard(
                      icon: Icons.storefront_rounded,
                      mode: AppMode.seller,
                      title: 'Saya Penjual',
                      subtitle: AppMode.seller.tagline,
                      enabled: !_busy,
                      onTap: () => _choose(AppMode.seller),
                    ),
                    const SizedBox(height: 14),
                    _ModeCard(
                      icon: Icons.shopping_bag_rounded,
                      mode: AppMode.buyer,
                      title: 'Saya Pembeli',
                      subtitle: AppMode.buyer.tagline,
                      enabled: !_busy,
                      onTap: () => _choose(AppMode.buyer),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Satu aplikasi, dua peran. Data pembeli terpisah dari data toko.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        Container(
          height: 76,
          width: 76,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          'KasirGo',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Warung lebih untung, pembeli lebih mudah',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final AppMode mode;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBuyer = mode == AppMode.buyer;
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(18),
      onTap: enabled ? onTap : null,
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              gradient: isBuyer ? AppTheme.aiBadgeGradient : AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}
