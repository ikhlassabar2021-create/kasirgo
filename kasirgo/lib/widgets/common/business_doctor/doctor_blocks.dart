import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_theme.dart';
import '../app_button.dart';

class DoctorBlocks extends StatelessWidget {
  final List blocks;
  final void Function(String value)? onChoice;
  final void Function(String actionKey, String label)? onAction;
  final void Function(
      Map<String, dynamic> block, Map<String, dynamic> step, int index)? onPrescription;
  final void Function(Map<String, dynamic> block, int index)?
      onTogglePrescription;

  const DoctorBlocks({
    super.key,
    required this.blocks,
    this.onChoice,
    this.onAction,
    this.onPrescription,
    this.onTogglePrescription,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final raw in blocks) {
      if (raw is! Map) continue;
      final block = raw.cast<String, dynamic>();
      final widget = _buildBlock(context, block);
      if (widget == null) continue;
      if (children.isNotEmpty) children.add(const SizedBox(height: 10));
      children.add(widget);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget? _buildBlock(BuildContext context, Map<String, dynamic> b) {
    switch (b['type']) {
      case 'text':
        return Text(
          _s(b['text']),
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.45,
            color: AppTheme.textPrimary,
          ),
        );
      case 'card':
        return _card(b);
      case 'gauge':
        return _gauge(b);
      case 'checklist':
        return _checklist(b);
      case 'choices':
        return _choices(b);
      case 'action':
        return _action(b);
      case 'prescription':
        return _prescription(b);
      default:
        return null;
    }
  }

  Widget _card(Map<String, dynamic> b) {
    final color = _tone(b['tone']?.toString());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_s(b['title']).isNotEmpty)
            Text(
              _s(b['title']),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          if (_s(b['body']).isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: _s(b['title']).isEmpty ? 0 : 4),
              child: Text(
                _s(b['body']),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gauge(Map<String, dynamic> b) {
    final value = ((b['value'] as num?)?.toDouble() ?? 0).clamp(0.0, 100.0);
    final color = value >= 70
        ? AppTheme.successColor
        : (value >= 40 ? AppTheme.warningColor : AppTheme.errorColor);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMutedColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _s(b['label']).isEmpty
                      ? 'Skor Kesehatan Usaha'
                      : _s(b['label']),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                value.round().toString(),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 8,
              backgroundColor: AppTheme.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (_s(b['hint']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _s(b['hint']),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _checklist(Map<String, dynamic> b) {
    final items = (b['items'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_s(b['title']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _s(b['title']),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        for (final raw in items)
          if (raw is Map)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    raw['done'] == true
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: raw['done'] == true
                        ? AppTheme.successColor
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _s(raw['text']),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.35,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _choices(Map<String, dynamic> b) {
    final options = (b['options'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_s(b['prompt']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _s(b['prompt']),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final raw in options)
              if (raw is Map)
                OutlinedButton(
                  onPressed: onChoice == null
                      ? null
                      : () => onChoice!(_s(raw['value']).isEmpty
                          ? _s(raw['label'])
                          : _s(raw['value'])),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  child: Text(
                    _s(raw['label']),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }

  Widget _action(Map<String, dynamic> b) {
    final label = _s(b['label']);
    return AppButton(
      label: label.isEmpty ? 'Lanjutkan' : label,
      icon: Icons.arrow_forward_rounded,
      height: AppTheme.touchTargetMedium,
      onPressed: onAction == null
          ? null
          : () => onAction!(_s(b['action_key']), label),
    );
  }

  Widget _prescription(Map<String, dynamic> b) {
    final items = ((b['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final due = DateTime.tryParse(_s(b['due_at']));
    final target = (b['target_days'] as num?)?.toInt() ?? 7;
    final now = DateTime.now();
    final allDone =
        items.isNotEmpty && items.every((e) => e['done'] == true);
    final overdue = due != null && due.isBefore(now) && !allDone;
    final accent = allDone
        ? AppTheme.successColor
        : (overdue ? AppTheme.errorColor : AppTheme.primaryColor);
    final remaining = due == null ? '' : _remainingLabel(due, now);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: allDone
                  ? LinearGradient(colors: [
                      AppTheme.successColor.withValues(alpha: 0.9),
                      AppTheme.successColor,
                    ])
                  : AppTheme.aiBadgeGradient,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLarge - 1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.medication_liquid_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _s(b['title']).isEmpty
                        ? 'Resep Perbaikan'
                        : _s(b['title']),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    allDone ? 'SELESAI' : 'RESEP AKTIF',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      overdue
                          ? Icons.warning_amber_rounded
                          : Icons.schedule_rounded,
                      size: 14,
                      color: accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Masa target $target hari'
                      '${remaining.isEmpty ? '' : ' • $remaining'}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < items.length; i++) ...[
                  _prescriptionStep(b, items[i], i, accent),
                  if (i < items.length - 1) const SizedBox(height: 8),
                ],
                if (overdue)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Resep ini belum tuntas padahal masa target sudah lewat. '
                      'Ayo jalankan langkah yang tersisa.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        height: 1.35,
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _prescriptionStep(
      Map<String, dynamic> block, Map<String, dynamic> step, int index, Color accent) {
    final done = step['done'] == true;
    final key = _s(step['action_key']);
    final hasFeature = key.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done
                ? AppTheme.successColor
                : AppTheme.primaryColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _s(step['text']),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.35,
                  color: done
                      ? AppTheme.textSecondary
                      : AppTheme.textPrimary,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
              if (hasFeature)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _featureLabel(key),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
              // DUA aksi jelas: [Jalankan] membuka fitur, [Tandai] checklist.
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (hasFeature && !done)
                      _stepButton(
                        label: 'Jalankan',
                        icon: Icons.play_arrow_rounded,
                        onTap: onPrescription == null
                            ? null
                            : () => onPrescription!(block, step, index),
                        filled: true,
                        color: accent,
                      ),
                    _stepButton(
                      label: done ? 'Sudah Dijalankan' : 'Tandai Selesai',
                      icon: done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      onTap: done || onTogglePrescription == null
                          ? null
                          : () => onTogglePrescription!(block, index),
                      filled: done,
                      color: done ? AppTheme.successColor : accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required bool filled,
    required Color color,
  }) {
    return Material(
      color: filled ? color : color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: filled ? Colors.white : color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _remainingLabel(DateTime due, DateTime now) {
    final diff = due.difference(now);
    if (diff.isNegative) {
      final d = -diff.inDays + (diff.inHours % 24 == 0 ? 0 : 1);
      return 'Lewat ${d < 1 ? 1 : d} hari';
    }
    final d = (diff.inHours / 24).ceil();
    return 'Sisa $d hari';
  }

  String _featureLabel(String key) {
    const labels = {
      'sidak_bos': 'Laporan ke Bos',
      'progress_tracker': 'Laporan & Progres',
      'dynamic_pricing': 'Atur Harga Produk',
      'bundling': 'Bundling Produk',
      'cross_sell': 'Produk Terkait',
      'wa_marketing': 'WA Marketing',
      'catat_promosi': 'Catat Hasil Promosi',
      'health_score': 'Skor Kesehatan Usaha',
      'online_catalog': 'Katalog Online',
      'qr_table': 'QR Meja',
      'multi_outlet': 'Multi Outlet',
      'recipe': 'Resep & HPP',
    };
    return labels[key] ?? 'Fitur KasirGo';
  }

  Color _tone(String? tone) {
    switch (tone) {
      case 'success':
        return AppTheme.successColor;
      case 'warning':
        return AppTheme.warningColor;
      case 'danger':
        return AppTheme.errorColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _s(dynamic v) => v?.toString().trim() ?? '';
}
