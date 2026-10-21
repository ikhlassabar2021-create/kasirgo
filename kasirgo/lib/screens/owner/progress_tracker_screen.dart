import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/progress_tracker_service.dart';
import '../../utils/formatters.dart';
import '../../utils/progress_tracker.dart';

/// Progress Tracker (13.24 #6): memantau apakah usaha sedang membaik.
///
/// Menampilkan progress bar + indikator tren (panah naik/turun) + teks
/// "membaik / masih sama / menurun", plus progres resep, target, dan aksi.
class ProgressTrackerScreen extends ConsumerStatefulWidget {
  final ProgressTrackerService? service;
  const ProgressTrackerScreen({super.key, this.service});

  @override
  ConsumerState<ProgressTrackerScreen> createState() =>
      _ProgressTrackerScreenState();
}

class _ProgressTrackerScreenState extends ConsumerState<ProgressTrackerScreen> {
  late final ProgressTrackerService _service;
  ProgressTrackerReport? _report;
  bool _loading = true;
  bool _saving = false;
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProgressTrackerService();
    _load();
  }

  String? get _outletId => ref.read(currentUserProvider)?.outletId;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final outletId = _outletId;
      if (outletId != null && outletId.isNotEmpty) {
        final report = await _service.load(outletId);
        if (mounted) setState(() => _report = report);
      }
    } catch (_) {
      // Tampilkan keadaan kosong bila data gagal dimuat.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logProgress() async {
    final outletId = _outletId;
    final report = _report;
    if (outletId == null || outletId.isEmpty || report == null) return;
    setState(() => _saving = true);
    try {
      await _service.logProgress(outletId: outletId, report: report);
      if (mounted) {
        setState(() => _logged = true);
        _snack('Progres hari ini tersimpan di catatan Dokter Bisnis.');
      }
    } catch (_) {
      if (mounted) _snack('Gagal menyimpan progres. Coba lagi.');
    }
    if (mounted) setState(() => _saving = false);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Laporan & Progres'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
            tooltip: 'Segarkan',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : report == null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _buildTrendHero(report),
                      const SizedBox(height: 16),
                      if (!report.hasData)
                        _buildEmptyState()
                      else ...[
                        _buildSectionTitle(
                          'Resep & Target',
                          '${(((report.prescriptionProgress +
                                          report.targetProgress) /
                                      2) *
                                  100)
                              .round()}% rata-rata',
                        ),
                        const SizedBox(height: 10),
                        _buildPrescriptionCard(report),
                        const SizedBox(height: 12),
                        _buildTargetCard(report),
                        const SizedBox(height: 20),
                        _buildSectionTitle(
                          'Omzet 7 Hari Terakhir',
                          Formatters.currency(report.salesTrend.current),
                        ),
                        const SizedBox(height: 10),
                        _buildWeeklyChart(report),
                        const SizedBox(height: 20),
                        _buildActionCard(report),
                      ],
                      const SizedBox(height: 20),
                      _buildSaveButton(report),
                      const SizedBox(height: 10),
                      _buildFooterNote(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 44, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'Data progres belum bisa dimuat',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Periksa koneksi internet Anda lalu coba lagi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: AppTheme.touchTargetLarge,
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.infoSoftColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: const Icon(Icons.insights_rounded,
                color: AppTheme.accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Belum ada data untuk diukur. Mulai catat penjualan dan pasang '
              'target omzet agar progres bisa dipantau.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _trendColor(ProgressTrend trend) => switch (trend) {
        ProgressTrend.up => AppTheme.successTextColor,
        ProgressTrend.flat => AppTheme.warningTextColor,
        ProgressTrend.down => AppTheme.errorColor,
      };

  IconData _trendIcon(ProgressTrend trend) => switch (trend) {
        ProgressTrend.up => Icons.trending_up_rounded,
        ProgressTrend.flat => Icons.trending_flat_rounded,
        ProgressTrend.down => Icons.trending_down_rounded,
      };

  Widget _buildTrendHero(ProgressTrackerReport report) {
    final trend = report.salesTrend.trend;
    final color = _trendColor(trend);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Progres Usaha Anda',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Text(
                  'Skor ${report.score}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(_trendIcon(trend), color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.verdict,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.trendText,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (report.salesTrend.hasData) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: LinearProgressIndicator(
                value: (report.score / 100).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Omzet 7 hari: ${Formatters.currency(report.salesTrend.current)} '
              '(sebelumnya ${Formatters.currency(report.salesTrend.previous)})',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_trendIcon(trend), size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Tren ${report.trendLabel}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildProgressBar(double value, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 10,
        backgroundColor: AppTheme.surfaceMutedColor,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  Widget _buildPrescriptionCard(ProgressTrackerReport report) {
    final percent = report.prescriptionPercent;
    final color = percent >= 100
        ? AppTheme.successColor
        : percent >= 50
            ? AppTheme.warningColor
            : AppTheme.accentColor;
    return _buildCard(
      children: [
        Row(
          children: [
            Icon(Icons.checklist_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Langkah Resep Dokter',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              report.hasPrescription
                  ? '${report.prescriptionDone}/${report.prescriptionTotal}'
                  : 'Belum ada',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildProgressBar(report.prescriptionProgress, color),
        const SizedBox(height: 8),
        Text(
          report.hasPrescription
              ? '$percent% langkah resep sudah dijalankan.'
              : 'Belum ada resep aktif. Tanya Dokter Bisnis untuk memulai.',
          style: const TextStyle(
            fontSize: 11,
            height: 1.35,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTargetCard(ProgressTrackerReport report) {
    final percent = report.targetPercent;
    final color = percent >= 100
        ? AppTheme.successColor
        : percent >= 50
            ? AppTheme.accentColor
            : AppTheme.warningColor;
    final periodLabel =
        report.targetPeriod == 'month' ? 'bulan ini' : 'hari ini';
    return _buildCard(
      children: [
        Row(
          children: [
            Icon(Icons.flag_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Target Omzet',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              report.hasTarget ? '$percent%' : 'Belum diatur',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildProgressBar(report.targetProgress, color),
        const SizedBox(height: 8),
        Text(
          report.hasTarget
              ? '${Formatters.currency(report.targetSales)} dari '
                  '${Formatters.currency(report.targetAmount)} ($periodLabel).'
              : 'Pasang target omzet di beranda agar progres bisa diukur.',
          style: const TextStyle(
            fontSize: 11,
            height: 1.35,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(ProgressTrackerReport report) {
    final max = report.maxDaily;
    return _buildCard(
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in report.last7Days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: max <= 0
                                  ? 4
                                  : (day.amount / max) * 78 + 4,
                              decoration: BoxDecoration(
                                color: day.amount > 0
                                    ? AppTheme.accentColor
                                    : AppTheme.surfaceMutedColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _dayLabel(day.date),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Total ${Formatters.currency(report.salesTrend.current)} · '
          '${report.salesTrend.label} dibanding minggu sebelumnya',
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  String _dayLabel(DateTime date) {
    const names = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return names[date.weekday - 1];
  }

  Widget _buildActionCard(ProgressTrackerReport report) {
    final total = report.actionsTotal;
    final color = report.actionsDone > 0
        ? AppTheme.successColor
        : AppTheme.textSecondary;
    return _buildCard(
      children: [
        Row(
          children: [
            Icon(Icons.task_alt_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Aksi Perbaikan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              total > 0 ? '${report.actionsDone}/$total selesai' : 'Belum ada',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        if (total > 0) ...[
          const SizedBox(height: 10),
          _buildProgressBar(
            report.actionsDone / total,
            color,
          ),
          const SizedBox(height: 8),
          Text(
            '${report.actionsRunning} sedang jalan · '
            '${report.actionsPlanned} belum dimulai',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Belum ada aksi yang dicatat. Mulai dari resep Dokter Bisnis.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSaveButton(ProgressTrackerReport report) {
    return SizedBox(
      height: AppTheme.touchTargetLarge,
      child: FilledButton.icon(
        onPressed: _saving || _logged || !report.hasData ? null : _logProgress,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(_logged ? Icons.check_rounded : Icons.save_rounded),
        label: Text(
          _logged
              ? 'Progres hari ini sudah dicatat'
              : 'Catat Progres Hari Ini',
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return const Text(
      'Angka dihitung dari transaksi yang sudah dibayar. Progres resep '
      'mengikuti langkah yang Anda tandai selesai.',
      style: TextStyle(
        fontSize: 11,
        height: 1.4,
        color: AppTheme.textSecondary,
      ),
    );
  }
}
