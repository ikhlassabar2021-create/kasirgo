import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/shift.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});

  @override
  ConsumerState<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends ConsumerState<ShiftScreen> {
  bool _loading = true;
  Shift? _openShift;
  List<Shift> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final outletId = ref.read(currentUserProvider)?.outletId ?? '';
    if (outletId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final open = await SupabaseService().getOpenShift(outletId);
    final history = await SupabaseService().getShiftHistory(outletId);
    if (!mounted) return;
    setState(() {
      _openShift = open;
      _history = history.where((s) => !s.isOpen).toList();
      _loading = false;
    });
  }

  Future<void> _openShiftDialog() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Text('Buka Shift Kasir',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: GoogleFonts.inter(
              fontSize: 15, color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Modal Awal (Cash Di Laci)',
            prefixText: 'Rp ',
            hintText: 'Contoh: 200000',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Batal',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary))),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Buka Shift',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    final opening =
        double.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final user = ref.read(currentUserProvider);
    if (user == null || user.outletId == null || user.outletId!.isEmpty) return;
    final shift = await SupabaseService()
        .openShift(user.outletId!, user.id, opening);
    if (!mounted) return;
    if (shift == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gagal membuka shift'),
          backgroundColor: AppTheme.errorColor));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Shift dibuka. Modal awal ${Formatters.currency(opening)}'),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating));
    _load();
  }

  Future<void> _closeShiftDialog() async {
    final shift = _openShift;
    if (shift == null) return;
    final controller = TextEditingController();
    final noteController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Text('Tutup Shift',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Shift dibuka ${_fmtTime(shift.openedAt)} - modal awal ${Formatters.currency(shift.openingCash)}',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.inter(
                  fontSize: 15, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Uang Cash Fisik Di Laci',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Contoh: laci penuh, setor bos',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Batal',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary))),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Tutup Shift',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    final closing =
        double.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final closed = await SupabaseService()
        .closeShift(shift.id, closing, noteController.text.trim());
    if (!mounted) return;
    if (closed == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gagal menutup shift'),
          backgroundColor: AppTheme.errorColor));
      return;
    }
    final diff = closed.difference ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(diff.abs() <= 1
            ? 'Shift ditutup. Kas pas.'
            : 'Shift ditutup. Selisih: ${diff > 0 ? '+' : ''}${Formatters.currency(diff)}'),
        backgroundColor:
            diff.abs() <= 1 ? AppTheme.successColor : AppTheme.warningColor,
        behavior: SnackBarBehavior.floating));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Shift Kasir',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded,
                  color: AppTheme.textSecondary)),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _openShift == null ? _closedBanner() : _openCard(_openShift!),
                  const SizedBox(height: 16),
                  Text('RIWAYAT SHIFT',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    _emptyNote('Belum ada shift yang ditutup.')
                  else
                    ..._history.map(_historyCard),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _closedBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.storefront_rounded,
              size: 40, color: AppTheme.textSecondary),
          const SizedBox(height: 8),
          Text('Tidak ada shift aktif',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(
              'Buka shift di awal kerja agar cash/qris/transfer tercatat per kasir.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _openShiftDialog,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text('Buka Shift',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _openCard(Shift shift) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
            color: AppTheme.successColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppTheme.successColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('SHIFT AKTIF',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppTheme.successColor)),
              const Spacer(),
              Text('Sejak ${_fmtTime(shift.openedAt)}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          _row('Modal awal', Formatters.currency(shift.openingCash)),
          _row('Total tip', Formatters.currency(shift.totalTip)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _closeShiftDialog,
              icon: const Icon(Icons.stop_circle_rounded, size: 20),
              label: Text('Tutup Shift & Hitung Kas',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard(Shift shift) {
    final diff = shift.difference ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${_fmtTime(shift.openedAt)} - ${shift.closedAt != null ? _fmtTime(shift.closedAt!) : '-'}',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: diff.abs() <= 1
                        ? AppTheme.successColor.withValues(alpha: 0.12)
                        : AppTheme.warningColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    diff.abs() <= 1
                        ? 'KAS PAS'
                        : 'Selisih ${diff > 0 ? '+' : ''}${Formatters.currency(diff)}',
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: diff.abs() <= 1
                            ? AppTheme.successColor
                            : AppTheme.warningColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row('Cash', Formatters.currency(shift.totalCash ?? 0)),
            _row('QRIS', Formatters.currency(shift.totalQris ?? 0)),
            _row('Transfer', Formatters.currency(shift.totalTransfer ?? 0)),
            _row('Tip', Formatters.currency(shift.totalTip)),
            _row('Setoran (hitung fisik)',
                Formatters.currency(shift.closingCash ?? 0)),
            if (shift.note != null && shift.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Catatan: ${shift.note}',
                    style: GoogleFonts.inter(
                        fontSize: 11.5, color: AppTheme.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12.5, color: AppTheme.textSecondary)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _emptyNote(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 12.5, color: AppTheme.textSecondary)),
    );
  }

  String _fmtTime(DateTime dt) =>
      '${dt.day.toStringAsFixed(0).padLeft(2, '0')}/${dt.month.toStringAsFixed(0).padLeft(2, '0')} ${dt.hour.toStringAsFixed(0).padLeft(2, '0')}:${dt.minute.toStringAsFixed(0).padLeft(2, '0')}';
}
