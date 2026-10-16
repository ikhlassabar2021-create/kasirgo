import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/business_doctor_service.dart';
import '../../utils/error_messages.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/centennial_background.dart';

/// Rapor ROI Promosi: agregat dari `doctor_action_logs` (biaya vs omzet
/// tambahan) sehingga owner bisa melihat promosi mana yang menguntungkan.
class DoctorRaporRoiScreen extends ConsumerStatefulWidget {
  const DoctorRaporRoiScreen({super.key, this.service});

  final BusinessDoctorService? service;

  @override
  ConsumerState<DoctorRaporRoiScreen> createState() =>
      _DoctorRaporRoiScreenState();
}

class _DoctorRaporRoiScreenState extends ConsumerState<DoctorRaporRoiScreen> {
  bool _loading = true;
  String? _error;
  String _period = '30';
  List<Map<String, dynamic>> _logs = const [];

  static const _periods = [
    ('30', '30 Hari'),
    ('bulan', 'Bulan Ini'),
    ('semua', 'Semua'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Outlet tidak ditemukan.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs =
          await (widget.service ?? BusinessDoctorService()).getActionLogs(outletId);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e, fallback: 'Gagal memuat rapor ROI.');
      });
    }
  }

  double _cost(Map<String, dynamic> m) {
    final v = m['cost'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  double _revenue(Map<String, dynamic> m) {
    final r = m['result'];
    if (r is Map) {
      final v = r['extra_revenue'];
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  DateTime? _date(Map<String, dynamic> m) {
    final s = m['action_date']?.toString();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_period == 'semua') return _logs;
    final now = DateTime.now();
    return _logs.where((m) {
      final d = _date(m);
      if (d == null) return false;
      if (_period == 'bulan') return d.year == now.year && d.month == now.month;
      return now.difference(d).inDays <= 30;
    }).toList();
  }

  double get _sumCost =>
      _filtered.fold<double>(0, (acc, m) => acc + _cost(m));
  double get _sumRevenue =>
      _filtered.fold<double>(0, (acc, m) => acc + _revenue(m));
  double get _net => _sumRevenue - _sumCost;
  double? get _roi => _sumCost <= 0 ? null : _net / _sumCost;

  Map<String, List<double>> _groupBy(String field) {
    final out = <String, List<double>>{};
    for (final m in _filtered) {
      final key = (m[field]?.toString().trim().isNotEmpty ?? false)
          ? m[field].toString().trim()
          : 'Lainnya';
      final entry = out.putIfAbsent(key, () => [0, 0]);
      entry[0] += _cost(m);
      entry[1] += _revenue(m);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Rapor ROI Promosi',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: CentennialBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppTheme.formMaxWidth),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _periodChips(),
                        const SizedBox(height: 16),
                        if (_error != null) _errorCard()
                        else if (_filtered.isEmpty) _emptyCard()
                        else ...[
                          _heroCard(),
                          const SizedBox(height: 16),
                          _bestCard(),
                          const SizedBox(height: 16),
                          _breakdown('Kanal', _groupBy('channel')),
                          const SizedBox(height: 16),
                          _breakdown('Jenis Promosi', _groupBy('action_type')),
                          const SizedBox(height: 16),
                          _entriesCard(),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _periodChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (key, label) in _periods)
          Material(
            color: key == _period
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              onTap: () => setState(() => _period = key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: key == _period
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor,
                    width: key == _period ? 1.5 : 1,
                  ),
                ),
                child: Text(label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: key == _period
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: key == _period
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary,
                    )),
              ),
            ),
          ),
      ],
    );
  }

  Widget _heroCard() {
    final roi = _roi;
    final positive = _net >= 0;
    final color = positive ? AppTheme.successColor : AppTheme.errorColor;
    final roiText = roi == null
        ? 'Tanpa biaya'
        : '${roi >= 0 ? '+' : ''}${(roi * 100).toStringAsFixed(0)}%';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hasil Promosi',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: color, size: 30),
              const SizedBox(width: 8),
              Text(roiText,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 30, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            roi == null
                ? 'Catat biaya promosi agar ROI bisa dihitung.'
                : (positive
                    ? 'Setiap Rp1 biaya kembali menjadi Rp${(1 + roi).toStringAsFixed(2)}.'
                    : 'Biaya promosi belum tertutup omzet tambahan.'),
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _stat('Biaya', Formatters.currency(_sumCost),
                      AppTheme.errorColor)),
              const SizedBox(width: 12),
              Expanded(
                  child: _stat('Omzet Tambahan',
                      Formatters.currency(_sumRevenue), AppTheme.successColor)),
              const SizedBox(width: 12),
              Expanded(
                  child: _stat(
                      'Untung/Rugi',
                      Formatters.currency(_net),
                      positive ? AppTheme.successColor : AppTheme.errorColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMutedColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _bestCard() {
    final channels = _groupBy('channel');
    if (channels.isEmpty) return const SizedBox.shrink();
    final best = channels.entries.reduce((a, b) {
      final ra = a.value[1] - a.value[0];
      final rb = b.value[1] - b.value[0];
      return rb > ra ? b : a;
    });
    final net = best.value[1] - best.value[0];
    final good = net >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kanal Paling Menguntungkan',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text('${best.key} (${good ? '+' : ''}${Formatters.currency(net)})',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdown(String title, Map<String, List<double>> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    final entries = data.entries.toList()
      ..sort((a, b) => (b.value[1] - b.value[0]).compareTo(a.value[1] - a.value[0]));
    final maxAbs = entries.fold<double>(
        1, (acc, e) => (e.value[1] - e.value[0]).abs() > acc ? (e.value[1] - e.value[0]).abs() : acc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final e in entries) ...[
          _breakdownRow(e.key, e.value[0], e.value[1], maxAbs),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _breakdownRow(String label, double cost, double revenue, double maxAbs) {
    final net = revenue - cost;
    final color = net >= 0 ? AppTheme.successColor : AppTheme.errorColor;
    final frac = (net.abs() / maxAbs).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Text('${net >= 0 ? '+' : ''}${Formatters.currency(net)}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 8,
            backgroundColor: AppTheme.surfaceMutedColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Biaya ${Formatters.currency(cost)} - Omzet ${Formatters.currency(revenue)}',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _entriesCard() {
    final items = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Riwayat (${items.length})',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final m in items) ...[
          _entryRow(m),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _entryRow(Map<String, dynamic> m) {
    final cost = _cost(m);
    final revenue = _revenue(m);
    final net = revenue - cost;
    final color = net >= 0 ? AppTheme.successColor : AppTheme.errorColor;
    final d = _date(m);
    final title = (m['action_type']?.toString().trim().isNotEmpty ?? false)
        ? m['action_type'].toString()
        : 'Promosi';
    final channel = m['channel']?.toString();
    final outcome = m['outcome']?.toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (d != null) Formatters.date(d),
                    if (channel != null && channel.isNotEmpty) channel,
                    if (outcome != null && outcome.isNotEmpty) outcome,
                  ].join(' - '),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${net >= 0 ? '+' : ''}${Formatters.currency(net)}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w800, color: color)),
              Text('Rp${cost.toStringAsFixed(0)} -> Rp${revenue.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.insights_rounded,
              size: 40, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text('Belum ada catatan promosi',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Catat hasil promosi Anda agar ROI-nya bisa dihitung di sini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: AppTheme.errorColor),
          const SizedBox(height: 8),
          Text(_error ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 13)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}
