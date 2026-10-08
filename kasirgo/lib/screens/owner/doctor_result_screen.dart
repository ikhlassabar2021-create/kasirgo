import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/app_theme.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/centennial_background.dart';

/// Layar HASIL diagnosa (BAGIAN 13.21A) - ramah gaptek, Design System v2.
/// Menampilkan: header + tanggal, skor kesehatan (gauge), kartu vonis,
/// peta resep (checklist bernomor), target/timeline, dan footer aksi.
class DoctorResultScreen extends StatelessWidget {
  const DoctorResultScreen({
    super.key,
    this.verdictTitle = 'Hasil Pemeriksaan',
    this.verdictBody = '',
    this.score,
    this.scoreHint = '',
    this.targetDays,
    this.dueDate,
    this.steps = const [],
    this.onRunStep,
    this.onStart,
    this.onShare,
    this.onAsk,
  });

  final String verdictTitle;
  final String verdictBody;
  final int? score;
  final String scoreHint;
  final int? targetDays;
  final DateTime? dueDate;
  final List<Map<String, dynamic>> steps;
  final void Function(int index, Map<String, dynamic> step)? onRunStep;
  final VoidCallback? onStart;
  final VoidCallback? onShare;
  final VoidCallback? onAsk;

  Color get _scoreColor {
    final s = score ?? 0;
    if (s >= 70) return AppTheme.successColor;
    if (s >= 40) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  String get _verdictTone {
    final s = score ?? 0;
    if (s >= 70) return 'SEHAT';
    if (s >= 40) return 'PERLU PERHATIAN';
    return 'BUTUH PENANGANAN';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CentennialBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppTheme.formMaxWidth),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _header(context),
                  const SizedBox(height: 16),
                  if (score != null) ...[
                    _gaugeCard(),
                    const SizedBox(height: 16),
                  ],
                  _verdictCard(),
                  if (steps.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _recipeCard(),
                  ],
                  if (targetDays != null || dueDate != null) ...[
                    const SizedBox(height: 16),
                    _timelineCard(),
                  ],
                  const SizedBox(height: 24),
                  _footer(context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Container(
            width: AppTheme.touchTargetMedium,
            height: AppTheme.touchTargetMedium,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hasil Pemeriksaan',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                    .format(DateTime.now()),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: AppTheme.aiBadgeGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: const Icon(Icons.medical_services_outlined,
              color: Colors.white, size: 22),
        ),
      ],
    );
  }

  Widget _gaugeCard() {
    final s = (score ?? 0).clamp(0, 100);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: Column(
        children: [
          Text(
            'Skor Kesehatan Usaha',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: s.toDouble()),
            duration: AppTheme.durationSlow,
            curve: AppTheme.curveDefault,
            builder: (context, value, _) => SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: value / 100,
                      strokeWidth: 14,
                      backgroundColor: AppTheme.surfaceMutedColor,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(_scoreColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value.round().toString(),
                        style: GoogleFonts.inter(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: _scoreColor,
                        ),
                      ),
                      Text(
                        _verdictTone,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _scoreColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (scoreHint.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              scoreHint,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _verdictCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _scoreColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: _scoreColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.coronavirus_outlined, color: _scoreColor, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'VONIS DOKTER',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: _scoreColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            verdictTitle,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          if (verdictBody.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              verdictBody,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recipeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Peta Resep',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kerjakan satu per satu, tidak perlu sekaligus.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(steps.length, (i) {
            final step = steps[i];
            final done = step['done'] == true;
            final hasAction = (step['action_key']?.toString() ?? '').isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: done
                          ? AppTheme.successColor
                          : AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: done
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text(
                            '${i + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['text']?.toString() ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.4,
                            color: AppTheme.textPrimary,
                            decoration: done
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: AppTheme.touchTargetMedium,
                          child: AppButton(
                            label: done
                                ? 'Sudah dilakukan'
                                : (hasAction ? 'Kerjakan' : 'Sudah Saya Lakukan'),
                            icon: done
                                ? Icons.check_circle
                                : (hasAction
                                    ? Icons.play_arrow_rounded
                                    : Icons.done),
                            variant: done
                                ? AppButtonVariant.outline
                                : AppButtonVariant.primary,
                            expanded: false,
                            onPressed: done || onRunStep == null
                                ? null
                                : () => onRunStep!(i, step),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _timelineCard() {
    final due = dueDate;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMutedColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined,
              color: AppTheme.primaryColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target & Waktu',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (targetDays != null) 'Selesaikan dalam $targetDays hari',
                    if (due != null)
                      'batas ${DateFormat('d MMM yyyy', 'id_ID').format(due)}',
                  ].join(' | '),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Column(
      children: [
        if (onStart != null)
          SizedBox(
            height: AppTheme.touchTargetLarge,
            child: AppButton(
              label: 'Mulai Jalankan',
              icon: Icons.rocket_launch_outlined,
              onPressed: onStart,
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (onShare != null)
              Expanded(
                child: SizedBox(
                  height: AppTheme.touchTargetLarge,
                  child: AppButton(
                    label: 'Simpan / Bagikan',
                    icon: Icons.share_outlined,
                    variant: AppButtonVariant.outline,
                    onPressed: onShare,
                  ),
                ),
              ),
            if (onShare != null && onAsk != null) const SizedBox(width: 10),
            if (onAsk != null)
              Expanded(
                child: SizedBox(
                  height: AppTheme.touchTargetLarge,
                  child: AppButton(
                    label: 'Tanya Dokter',
                    icon: Icons.chat_bubble_outline,
                    variant: AppButtonVariant.secondary,
                    onPressed: onAsk,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
