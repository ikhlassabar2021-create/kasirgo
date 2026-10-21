import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/delegation_service.dart';
import '../../utils/formatters.dart';
import '../../utils/receipt_generator.dart';
import '../../widgets/common/centennial_background.dart';
import '../../widgets/common/doctor_badge_chip.dart';
import '../../widgets/common/supporter_gate.dart';

/// Laporan performa staf dari tugas delegasi Dokter Bisnis.
///
/// Menampilkan ringkasan periode, peringkat staf, dan ekspor Excel agar owner
/// bisa menilai kinerja Admin/Kasir/Koki secara objektif.
class StaffPerformanceScreen extends ConsumerStatefulWidget {
  final DelegationService? service;

  const StaffPerformanceScreen({super.key, this.service});

  @override
  ConsumerState<StaffPerformanceScreen> createState() =>
      _StaffPerformanceScreenState();
}

class _StaffPerformanceScreenState
    extends ConsumerState<StaffPerformanceScreen> {
  late final DelegationService _service =
      widget.service ?? DelegationService();

  static const _periods = <int>[7, 30, 90];

  int _days = 30;
  bool _loading = true;
  bool _exporting = false;
  DoctorLeaderboard _board = const DoctorLeaderboard();
  List<DoctorDelegation> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = true);
    final board = await _service.leaderboard(outletId, days: _days);
    final items = await _service.listForOutlet(outletId);
    if (!mounted) return;
    setState(() {
      _board = board;
      _items = items;
      _loading = false;
    });
  }

  Future<void> _setDays(int days) async {
    if (days == _days) return;
    setState(() => _days = days);
    await _load();
  }

  int get _totalSelesai =>
      _board.items.fold(0, (sum, e) => sum + e.selesai);
  int get _totalTepat => _board.items.fold(0, (sum, e) => sum + e.tepatWaktu);
  int get _totalTerlambat =>
      _board.items.fold(0, (sum, e) => sum + e.terlambat);
  int get _totalAktif => _board.items.fold(0, (sum, e) => sum + e.aktif);
  int get _totalXp => _board.items.fold(0, (sum, e) => sum + e.xp);
  int get _tepatPersen =>
      _totalSelesai == 0 ? 0 : (_totalTepat * 100 / _totalSelesai).round();

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'cashier':
        return 'Kasir';
      case 'kitchen':
        return 'Koki';
      case 'owner':
        return 'Owner';
      default:
        return 'Staf';
    }
  }

  Future<void> _toast(String text, {bool error = false}) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppTheme.errorColor : AppTheme.successColor,
      ),
    );
  }

  List<DoctorDelegation> _tasksOf(String userId) {
    final list = _items
        .where((d) => d.assignedUserId == userId)
        .toList()
      ..sort((a, b) {
        final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    return list;
  }

  Future<void> _openDetail(DoctorLeaderboardEntry entry) async {
    final tasks = _tasksOf(entry.userId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${_roleLabel(entry.role)} - ${entry.xp} XP',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metricPill('Selesai', '${entry.selesai}',
                      AppTheme.successColor),
                  _metricPill('Tepat waktu', '${entry.tepatWaktu}',
                      AppTheme.primaryColor),
                  _metricPill('Terlambat', '${entry.terlambat}',
                      AppTheme.errorColor),
                  _metricPill('Aktif', '${entry.aktif}',
                      AppTheme.warningColor),
                  _metricPill('Penyelesaian', '${entry.penyelesaian}%',
                      AppTheme.accentColor),
                ],
              ),
              if (entry.hasBadges) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final badge in entry.badges)
                      DoctorBadgeChip(badge: badge, compact: true),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Riwayat Tugas (${tasks.length})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (tasks.isEmpty)
                Text(
                  'Belum ada tugas untuk staf ini.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 14, color: AppTheme.borderColor),
                    itemBuilder: (_, i) => _taskRow(tasks[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _taskRow(DoctorDelegation task) {
    final (label, color) = switch (task.status) {
      'selesai' => ('Selesai', AppTheme.successColor),
      'dikerjakan' => ('Dikerjakan', AppTheme.warningColor),
      'dilewati' => ('Dilewati', AppTheme.textSecondary),
      _ => ('Menunggu', AppTheme.primaryColor),
    };
    final late = task.isOverdue;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  task.createdAt == null
                      ? null
                      : Formatters.date(task.createdAt!),
                  if (late) 'Terlambat',
                ].whereType<String>().join(' - '),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: late ? AppTheme.errorColor : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Future<void> _exportExcel() async {
    if (!await requireSupporterFeature(context, ref, 'export_excel')) return;
    if (!mounted || _exporting) return;
    if (_board.isEmpty) {
      await _toast('Belum ada data performa staf untuk diexport.',
          error: true);
      return;
    }
    setState(() => _exporting = true);
    try {
      final outletId = ref.read(currentUserProvider)?.outletId ?? '-';
      final excel = xl.Excel.createExcel();
      final summary = excel['Ringkasan'];
      excel.setDefaultSheet('Ringkasan');
      if (excel.tables.containsKey('Sheet1')) excel.delete('Sheet1');

      summary.appendRow([xl.TextCellValue('LAPORAN PERFORMA STAF — KASIRGO')]);
      summary.appendRow([
        xl.TextCellValue('Outlet ID'),
        xl.TextCellValue(outletId),
      ]);
      summary.appendRow([
        xl.TextCellValue('Periode'),
        xl.TextCellValue('$_days hari terakhir'),
      ]);
      summary.appendRow([
        xl.TextCellValue('Tanggal Export'),
        xl.TextCellValue(Formatters.date(DateTime.now())),
      ]);
      summary.appendRow([xl.TextCellValue('')]);
      summary.appendRow([xl.TextCellValue('RINGKASAN')]);
      summary.appendRow([
        xl.TextCellValue('Metrik'),
        xl.TextCellValue('Nilai'),
      ]);
      summary.appendRow([
        xl.TextCellValue('Jumlah Staf'),
        xl.IntCellValue(_board.items.length),
      ]);
      summary.appendRow([
        xl.TextCellValue('Tugas Selesai'),
        xl.IntCellValue(_totalSelesai),
      ]);
      summary.appendRow([
        xl.TextCellValue('Tugas Aktif'),
        xl.IntCellValue(_totalAktif),
      ]);
      summary.appendRow([
        xl.TextCellValue('Tepat Waktu (%)'),
        xl.IntCellValue(_tepatPersen),
      ]);
      summary.appendRow([
        xl.TextCellValue('Terlambat'),
        xl.IntCellValue(_totalTerlambat),
      ]);
      summary.appendRow([
        xl.TextCellValue('Total XP Staf'),
        xl.IntCellValue(_totalXp),
      ]);
      summary.appendRow([xl.TextCellValue('')]);
      summary.appendRow([
        xl.TextCellValue('Catatan'),
        xl.TextCellValue(
          'XP dihitung ${_board.xpPerTugas} XP per tugas selesai. '
          'Tepat waktu dihitung dari tugas selesai sebelum tenggat.',
        ),
      ]);

      final detail = excel['Detail Staf'];
      detail.appendRow([
        xl.TextCellValue('Peringkat'),
        xl.TextCellValue('Nama'),
        xl.TextCellValue('Peran'),
        xl.TextCellValue('Selesai'),
        xl.TextCellValue('Tepat Waktu'),
        xl.TextCellValue('Terlambat'),
        xl.TextCellValue('Aktif'),
        xl.TextCellValue('Penyelesaian (%)'),
        xl.TextCellValue('XP'),
        xl.TextCellValue('Badge'),
      ]);
      for (final entry in _board.items) {
        detail.appendRow([
          xl.IntCellValue(entry.rank),
          xl.TextCellValue(entry.name),
          xl.TextCellValue(_roleLabel(entry.role)),
          xl.IntCellValue(entry.selesai),
          xl.IntCellValue(entry.tepatWaktu),
          xl.IntCellValue(entry.terlambat),
          xl.IntCellValue(entry.aktif),
          xl.IntCellValue(entry.penyelesaian),
          xl.IntCellValue(entry.xp),
          xl.TextCellValue(entry.badges.join(', ')),
        ]);
      }

      final bytes = excel.save(
        fileName: 'Performa_Staf_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      if (bytes == null) {
        await _toast('Gagal membuat berkas Excel.', error: true);
        return;
      }
      final filename =
          'Performa_Staf_${Formatters.date(DateTime.now()).replaceAll('/', '-')}.xlsx';
      await ReceiptGenerator.share(Uint8List.fromList(bytes), filename);
      await _toast('Laporan performa staf berhasil dibuat.');
    } catch (_) {
      await _toast('Gagal export Excel. Silakan coba lagi.', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Performa Staf',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: _exporting ? null : _exportExcel,
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export Excel',
          ),
        ],
      ),
      body: CentennialBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
              child: RefreshIndicator(
                color: AppTheme.primaryColor,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _periodCard(),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 64),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      )
                    else if (_board.isEmpty)
                      _emptyState()
                    else ...[
                      _summaryGrid(),
                      const SizedBox(height: 16),
                      _rankingSection(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _periodCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Performa Staf $_days Hari Terakhir',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Dihitung dari tugas delegasi Dokter Bisnis yang ditugaskan ke staf.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final days in _periods)
                ChoiceChip(
                  label: Text('$days hari'),
                  selected: _days == days,
                  onSelected: (_) => _setDays(days),
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _days == days
                        ? Colors.white
                        : AppTheme.textSecondary,
                  ),
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.surfaceMutedColor,
                  side: BorderSide(
                    color: _days == days
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor,
                  ),
                  showCheckmark: false,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryGrid() {
    final cards = [
      ('Tugas Selesai', '$_totalSelesai', AppTheme.successColor,
          Icons.task_alt_rounded),
      ('Tepat Waktu', '$_tepatPersen%', AppTheme.primaryColor,
          Icons.timer_rounded),
      ('Terlambat', '$_totalTerlambat', AppTheme.errorColor,
          Icons.schedule_rounded),
      ('Total XP', '$_totalXp', AppTheme.accentColor,
          Icons.bolt_rounded),
    ];
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _summaryCard(cards[i])),
        ],
      ],
    );
  }

  Widget _summaryCard(
      (String, String, Color, IconData) data) {
    final (label, value, color, icon) = data;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  size: 20, color: AppTheme.warningColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Peringkat Staf',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                '${_board.items.length} staf',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _board.items.length; i++) ...[
            if (i > 0) const Divider(height: 18, color: AppTheme.borderColor),
            _staffRow(_board.items[i]),
          ],
        ],
      ),
    );
  }

  Widget _staffRow(DoctorLeaderboardEntry entry) {
    final isTop = entry.rank == 1;
    final rankColor = isTop ? AppTheme.warningColor : AppTheme.textSecondary;
    final completion = (entry.penyelesaian / 100).clamp(0.0, 1.0);
    return InkWell(
      onTap: () => _openDetail(entry),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isTop
                    ? AppTheme.warningSoftColor
                    : AppTheme.surfaceMutedColor,
                shape: BoxShape.circle,
              ),
              child: isTop
                  ? Icon(Icons.emoji_events_rounded,
                      size: 16, color: rankColor)
                  : Text(
                      '${entry.rank}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: rankColor,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${entry.xp} XP',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${_roleLabel(entry.role)} - ${entry.selesai} selesai, '
                    '${entry.tepatWaktu} tepat waktu, ${entry.terlambat} terlambat',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: completion,
                      minHeight: 5,
                      backgroundColor: AppTheme.surfaceMutedColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isTop ? AppTheme.warningColor : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Penyelesaian ${entry.penyelesaian}%'
                    '${entry.aktif > 0 ? ' - ${entry.aktif} tugas aktif' : ''}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (entry.hasBadges) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final badge in entry.badges)
                          DoctorBadgeChip(badge: badge, compact: true),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.groups_2_outlined,
              size: 44, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'Belum ada data performa staf',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Delegasikan tugas dari Dokter Bisnis ke staf. Setelah tugas '
            'selesai, laporan performa akan muncul di sini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
