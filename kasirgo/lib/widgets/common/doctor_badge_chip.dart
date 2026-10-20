import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';

/// Chip badge apresiasi staf dari papan peringkat delegasi Dokter Bisnis.
///
/// Kode badge berasal dari RPC `delegation_leaderboard`:
/// `juara`, `selalu_tepat`, `konsisten`, `perlu_bantuan`, `pekerja_keras`.
class DoctorBadgeChip extends StatelessWidget {
  const DoctorBadgeChip({super.key, required this.badge, this.compact = false});

  final String badge;
  final bool compact;

  static const _labels = <String, String>{
    'juara': 'Juara',
    'selalu_tepat': 'Selalu Tepat Waktu',
    'konsisten': 'Konsisten',
    'perlu_bantuan': 'Perlu Bantuan',
    'pekerja_keras': 'Pekerja Keras',
  };

  static String label(String badge) => _labels[badge] ?? 'Apresiasi';

  static IconData icon(String badge) {
    switch (badge) {
      case 'juara':
        return Icons.emoji_events_rounded;
      case 'selalu_tepat':
        return Icons.verified_rounded;
      case 'konsisten':
        return Icons.timeline_rounded;
      case 'perlu_bantuan':
        return Icons.support_rounded;
      case 'pekerja_keras':
        return Icons.bolt_rounded;
      default:
        return Icons.military_tech_rounded;
    }
  }

  static Color _bg(String badge) {
    switch (badge) {
      case 'juara':
        return AppTheme.warningSoftColor;
      case 'selalu_tepat':
        return AppTheme.successChipColor;
      case 'konsisten':
        return AppTheme.infoSoftColor;
      case 'perlu_bantuan':
        return AppTheme.errorSoftColor;
      case 'pekerja_keras':
        return AppTheme.violetSoftColor;
      default:
        return AppTheme.surfaceMutedColor;
    }
  }

  static Color _fg(String badge) {
    switch (badge) {
      case 'juara':
        return AppTheme.warningTextColor;
      case 'selalu_tepat':
        return AppTheme.successTextColor;
      case 'konsisten':
        return AppTheme.secondaryColor;
      case 'perlu_bantuan':
        return AppTheme.errorColor;
      case 'pekerja_keras':
        return AppTheme.moduleAccentViolet;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = _fg(badge);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: _bg(badge),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon(badge), size: compact ? 11 : 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label(badge),
            style: GoogleFonts.plusJakartaSans(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
