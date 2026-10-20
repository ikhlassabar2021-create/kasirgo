import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../services/delegation_service.dart';

/// Daftar tugas yang didelegasikan owner kepada staf yang sedang login.
///
/// Dipakai di beranda Kasir/Admin/Koki. Staf hanya bisa mengubah status
/// (lewat RPC `delegation_set_status`), bukan isi tugas.
class DelegationTasksCard extends StatefulWidget {
  const DelegationTasksCard({
    super.key,
    this.service,
    this.onChanged,
  });

  final DelegationService? service;
  final VoidCallback? onChanged;

  @override
  State<DelegationTasksCard> createState() => _DelegationTasksCardState();
}

class _DelegationTasksCardState extends State<DelegationTasksCard> {
  late final DelegationService _service =
      widget.service ?? DelegationService();
  List<DoctorDelegation> _items = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _service.listMine();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _advance(DoctorDelegation item) async {
    setState(() => _busy = true);
    final next = item.isWorking ? 'selesai' : 'dikerjakan';
    final res = await _service.setStatus(item.id, next);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res['ok'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['error']?.toString() ?? 'Gagal memperbarui tugas.',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    await _load();
    widget.onChanged?.call();
    if (!mounted) return;
    final xp = res['xp'];
    final gained = xp is Map ? xp['gained'] : xp;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          next == 'selesai'
              ? (gained == null
                  ? 'Tugas selesai. Terima kasih!'
                  : 'Tugas selesai. Anda mendapat $gained XP.')
              : 'Tugas ditandai sedang dikerjakan.',
        ),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  String _dueLabel(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(due.year, due.month, due.day);
    final diff = target.difference(today).inDays;
    if (diff < 0) return 'Lewat ${-diff} hari';
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Besok';
    return '$diff hari lagi';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      );
    }
    if (_items.isEmpty) return const SizedBox.shrink();

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
              const Icon(Icons.assignment_turned_in_rounded,
                  size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tugas dari Owner',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_items.length}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const Divider(height: 18, color: AppTheme.borderColor),
            _taskRow(_items[i]),
          ],
        ],
      ),
    );
  }

  Widget _taskRow(DoctorDelegation item) {
    final overdue = item.isOverdue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                item.isWorking
                    ? Icons.timelapse_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: item.isWorking
                    ? AppTheme.warningColor
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.3,
                ),
              ),
            ),
            if (item.priority == 'tinggi')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Penting',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.errorColor,
                  ),
                ),
              ),
          ],
        ),
        if (item.body.isNotEmpty) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              item.body,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                height: 1.35,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 22),
          child: Row(
            children: [
              if (item.dueAt != null) ...[
                Icon(
                  overdue ? Icons.alarm_rounded : Icons.event_available_rounded,
                  size: 14,
                  color:
                      overdue ? AppTheme.errorColor : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  _dueLabel(item.dueAt!),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        overdue ? AppTheme.errorColor : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: item.isWorking
                        ? AppTheme.successColor
                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _busy ? null : () => _advance(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isWorking
                                  ? Icons.check_circle_rounded
                                  : Icons.play_arrow_rounded,
                              size: 14,
                              color: item.isWorking
                                  ? Colors.white
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.isWorking ? 'Selesai' : 'Kerjakan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: item.isWorking
                                    ? Colors.white
                                    : AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
