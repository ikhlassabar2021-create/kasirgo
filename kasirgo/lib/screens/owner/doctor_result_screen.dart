import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/app_theme.dart';
import '../../utils/doctor_vitals.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/centennial_background.dart';

/// Layar HASIL diagnosa (BAGIAN 13.21A) - ramah gaptek, Design System v2.
/// Menampilkan: header + tanggal, skor kesehatan (gauge), kartu vonis,
/// peta resep (checklist bernomor), target/timeline, dan footer aksi.
class DoctorResultScreen extends StatefulWidget {
  const DoctorResultScreen({
    super.key,
    this.verdictTitle = 'Hasil Pemeriksaan',
    this.verdictBody = '',
    this.score,
    this.scoreHint = '',
    this.targetDays,
    this.dueDate,
    this.steps = const [],
    this.vitalsFuture,
    this.onRunStep,
    this.onToggleStep,
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

  /// Tiga tanda vital (Detak Kas, Napas Stok, Imun Pelanggan) dimuat async
  /// agar layar tetap terbuka cepat.
  final Future<DoctorVitals?>? vitalsFuture;
  final void Function(int index, Map<String, dynamic> step)? onRunStep;
  final void Function(int index, Map<String, dynamic> step)? onToggleStep;
  final VoidCallback? onStart;
  final VoidCallback? onShare;
  final VoidCallback? onAsk;

  @override
  State<DoctorResultScreen> createState() => _DoctorResultScreenState();
}

class _DoctorResultScreenState extends State<DoctorResultScreen> {
  late List<Map<String, dynamic>> _steps;
  final _awardedSteps = <int>{};
  int _bonus = 0;
  bool _showBonus = false;

  String get verdictTitle => widget.verdictTitle;
  String get verdictBody => widget.verdictBody;
  int? get score => widget.score;
  String get scoreHint => widget.scoreHint;
  int? get targetDays => widget.targetDays;
  DateTime? get dueDate => widget.dueDate;
  void Function(int, Map<String, dynamic>)? get onRunStep => widget.onRunStep;
  void Function(int, Map<String, dynamic>)? get onToggleStep =>
      widget.onToggleStep;
  VoidCallback? get onStart => widget.onStart;
  VoidCallback? get onShare => widget.onShare;
  VoidCallback? get onAsk => widget.onAsk;

  @override
  void initState() {
    super.initState();
    // Salin agar perubahan (tercoret) langsung tampil tanpa menunggu parent.
    _steps = widget.steps
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _toggle(int i) {
    if (i < 0 || i >= _steps.length) return;
    final wasDone = _steps[i]['done'] == true;
    setState(() => _steps[i]['done'] = !wasDone);
    if (!wasDone) _bumpScore(i);
    widget.onToggleStep?.call(i, _steps[i]);
  }

  void _run(int i) {
    if (i < 0 || i >= _steps.length) return;
    final wasDone = _steps[i]['done'] == true;
    setState(() => _steps[i]['done'] = true);
    if (!wasDone) _bumpScore(i);
    widget.onRunStep?.call(i, _steps[i]);
  }

  /// Skor naik +5 sekali per langkah (gamifikasi). Animasi badge singkat
  /// agar owner langsung melihat dampaknya.
  void _bumpScore(int i) {
    if (!_awardedSteps.add(i)) return;
    setState(() {
      _bonus += 5;
      _showBonus = true;
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showBonus = false);
    });
  }

  int get _displayScore {
    final base = score ?? 0;
    return (base + _bonus).clamp(0, 100);
  }

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
                  if (widget.vitalsFuture != null) ...[
                    _vitalsSection(),
                    const SizedBox(height: 16),
                  ],
                  _verdictCard(),
                  if (_steps.isNotEmpty) ...[
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                    .format(DateTime.now()),
                style: GoogleFonts.plusJakartaSans(
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
    final s = _displayScore;
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
            style: GoogleFonts.plusJakartaSans(
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: _scoreColor,
                        ),
                      ),
                      Text(
                        _verdictTone,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
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
          if (_bonus > 0) ...[
            const SizedBox(height: 10),
            AnimatedOpacity(
              opacity: _showBonus ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.successColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up_rounded,
                        size: 15, color: AppTheme.successColor),
                    const SizedBox(width: 6),
                    Text(
                      'Skor naik +$_bonus dari langkah yang dijalankan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (scoreHint.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              scoreHint,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Tiga tanda vital usaha (Detak Kas, Napas Stok, Imun Pelanggan).
  Widget _vitalsSection() {
    return FutureBuilder<DoctorVitals?>(
      future: widget.vitalsFuture,
      builder: (context, snap) {
        final vitals = snap.data;
        if (vitals == null) return const SizedBox.shrink();
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
              Row(
                children: [
                  const Icon(Icons.monitor_heart_outlined,
                      size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'TANDA VITAL USAHA',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${vitals.average}/100',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final v in vitals.all) ...[
                _vitalRow(v),
                if (v != vitals.all.last) const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _vitalRow(DoctorVital v) {
    final color = v.isGood
        ? AppTheme.successColor
        : (v.isWarning ? AppTheme.warningColor : AppTheme.errorColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                v.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              '${v.score}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (v.score / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppTheme.surfaceMutedColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          v.hint,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
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
                  style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          if (verdictBody.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              verdictBody,
              style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kerjakan satu per satu, tidak perlu sekaligus.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (_steps.isNotEmpty) ...[
            _priorityAction(),
            if (_steps.length > 1) ...[
              const SizedBox(height: 10),
              _otherStepsAccordion(),
            ],
          ],
        ],
      ),
    );
  }

  /// Estimasi durasi (menit) per jenis tindakan.
  int _minutesFor(String actionKey) {
    switch (actionKey) {
      case 'progress_tracker':
      case 'health_score':
      case 'catat_promosi':
        return 5;
      case 'cross_sell':
        return 10;
      case 'dynamic_pricing':
      case 'qr_table':
        return 15;
      case 'wa_marketing':
      case 'online_catalog':
      case 'multi_outlet':
      case 'recipe':
        return 20;
      case 'bundling':
      case 'sidak_bos':
        return 30;
      default:
        return 15;
    }
  }

  /// Tindakan prioritas hari ini: langkah pertama yang belum selesai dengan
  /// dampak kas tercepat. Langkah 2-8 disembunyikan di accordion agar owner
  /// tidak kewalahan.
  Widget _priorityAction() {
    var index = _steps.indexWhere((s) => s['done'] != true);
    if (index < 0) index = 0;
    final step = _steps[index];
    final actionKey = step['action_key']?.toString() ?? '';
    final minutes = _minutesFor(actionKey);
    final gap = (100 - (score ?? 0)).clamp(0, 100);
    final potential = ((gap * 500) / 5000).ceil() * 5000;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.10),
            AppTheme.aiBadgeGradient.colors.last.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'TINDAKAN PRIORITAS HARI INI',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _stepTile(index, highlighted: true),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip(Icons.schedule_rounded, '± $minutes menit'),
              if (potential > 0)
                _infoChip(
                  Icons.savings_outlined,
                  'Potensi +${Formatters.currency(potential)}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _otherStepsAccordion() {
    final remaining = _steps.length - 1;
    final doneCount = _steps.skip(1).where((s) => s['done'] == true).length;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        iconColor: AppTheme.primaryColor,
        collapsedIconColor: AppTheme.textSecondary,
        title: Text(
          'Langkah lainnya ($doneCount/$remaining selesai)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        children: [
          for (var i = 1; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _stepTile(i),
            ),
        ],
      ),
    );
  }

  Widget _stepTile(int i, {bool highlighted = false}) {
    final step = _steps[i];
    final done = step['done'] == true;
    final hasAction = (step['action_key']?.toString() ?? '').isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? AppTheme.successColor : AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : Text(
                  '${i + 1}',
                  style: GoogleFonts.plusJakartaSans(
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: highlighted ? 15 : 14,
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                  height: 1.4,
                  color: AppTheme.textPrimary,
                  decoration:
                      done ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (hasAction && !done)
                    SizedBox(
                      height: AppTheme.touchTargetMedium,
                      child: AppButton(
                        label: 'Jalankan',
                        icon: Icons.play_arrow_rounded,
                        expanded: false,
                        onPressed: onRunStep == null ? null : () => _run(i),
                      ),
                    ),
                  SizedBox(
                    height: AppTheme.touchTargetMedium,
                    child: AppButton(
                      label: done ? 'Sudah Dijalankan' : 'Tandai Selesai',
                      icon: done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      variant: done
                          ? AppButtonVariant.outline
                          : AppButtonVariant.secondary,
                      expanded: false,
                      onPressed:
                          done || onToggleStep == null ? null : () => _toggle(i),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
                  style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
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
