import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_theme.dart';
import '../../services/sidak_service.dart';
import '../../utils/formatters.dart';

/// Layar hitung stok fisik satu per satu. Mengembalikan daftar baris terbaru
/// lewat `Navigator.pop(context, rows)`.
class SidakStockCountScreen extends StatefulWidget {
  final List<SidakCountRow> rows;

  const SidakStockCountScreen({super.key, required this.rows});

  @override
  State<SidakStockCountScreen> createState() => _SidakStockCountScreenState();
}

class _SidakStockCountScreenState extends State<SidakStockCountScreen> {
  final _searchCtrl = TextEditingController();
  final Map<String, TextEditingController> _ctrls = {};
  String _query = '';
  bool _onlyDiff = false;

  @override
  void initState() {
    super.initState();
    for (final r in widget.rows) {
      _ctrls[r.productId] = TextEditingController(text: _fmt(r.physical));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  void _apply(String productId, String raw) {
    final row = widget.rows.firstWhere((r) => r.productId == productId);
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    row.physical = parsed ?? 0;
    setState(() {});
  }

  List<SidakCountRow> get _visible {
    final q = _query.trim().toLowerCase();
    return widget.rows.where((r) {
      if (_onlyDiff && r.diff == 0) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q);
    }).toList();
  }

  int get _diffCount =>
      widget.rows.where((r) => !r.isService && r.diff != 0).length;

  double get _diffValue => widget.rows
      .where((r) => !r.isService)
      .fold(0, (sum, r) => sum + r.diffValue);

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Hitung Stok Fisik'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.surfaceColor,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Cari nama produk',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppTheme.surfaceMutedColor,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        label: Text('Hanya selisih ($_diffCount)'),
                        selected: _onlyDiff,
                        onSelected: (v) => setState(() => _onlyDiff = v),
                        selectedColor: AppTheme.warningSoftColor,
                        checkmarkColor: AppTheme.warningTextColor,
                      ),
                    ),
                    Text(
                      'Selisih nilai: ${Formatters.currency(_diffValue)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _diffValue == 0
                            ? AppTheme.successTextColor
                            : AppTheme.warningTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada produk yang cocok.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _buildRow(visible[i]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: AppTheme.touchTargetLarge,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, widget.rows),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  child: const Text('Selesai Menghitung'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(SidakCountRow r) {
    final diff = r.diff;
    final hasDiff = diff != 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: hasDiff ? AppTheme.warningSoftBorderColor : AppTheme.borderColor,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sistem: ${_fmt(r.stockSystem)} ${r.unit}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (hasDiff)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Selisih ${diff > 0 ? '+' : ''}${_fmt(diff)} ${r.unit}'
                      ' (${Formatters.currency(r.diffValue)})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warningTextColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            child: TextField(
              controller: _ctrls[r.productId],
              onChanged: (v) => _apply(r.productId, v),
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: hasDiff
                    ? AppTheme.warningSoftColor
                    : AppTheme.surfaceMutedColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
