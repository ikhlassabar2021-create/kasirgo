import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/business_doctor_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/centennial_background.dart';

class DoctorPromotionLogScreen extends ConsumerStatefulWidget {
  const DoctorPromotionLogScreen({super.key, this.service});

  final BusinessDoctorService? service;

  @override
  ConsumerState<DoctorPromotionLogScreen> createState() =>
      _DoctorPromotionLogScreenState();
}

class _DoctorPromotionLogScreenState
    extends ConsumerState<DoctorPromotionLogScreen> {
  final _cost = TextEditingController();
  final _revenue = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'Promo Diskon';
  String _channel = 'WhatsApp';
  String _outcome = 'Berhasil';
  bool _saving = false;

  static const _types = [
    'Promo Diskon',
    'Iklan WA',
    'Bagi Brosur',
    'Endorse',
    'Bundling',
    'Lainnya',
  ];
  static const _channels = ['WhatsApp', 'Instagram', 'Brosur', 'Mulut ke mulut', 'Lainnya'];
  static const _outcomes = ['Berhasil', 'Belum terlihat', 'Gagal'];

  @override
  void initState() {
    super.initState();
    _cost.addListener(() => setState(() {}));
    _revenue.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cost.dispose();
    _revenue.dispose();
    _notes.dispose();
    super.dispose();
  }

  double get _costValue => double.tryParse(_cost.text.trim()) ?? 0;
  double get _revValue => double.tryParse(_revenue.text.trim()) ?? 0;
  double get _roi {
    final net = _revValue - _costValue;
    if (_costValue <= 0) return _revValue > 0 ? net : 0;
    return net / _costValue;
  }

  Future<void> _save() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    setState(() => _saving = true);
    try {
      await (widget.service ?? BusinessDoctorService()).logPromotion(
        outletId: outletId,
        actionType: _type,
        channel: _channel,
        cost: _costValue,
        extraRevenue: _revValue,
        description: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        outcome: _outcome,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Catat Hasil Promosi',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: CentennialBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppTheme.formMaxWidth),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Apa yang Anda lakukan?',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _chips(_types, _type, (v) => setState(() => _type = v)),
                const SizedBox(height: 20),
                Text('Lewat mana?',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _chips(_channels, _channel, (v) => setState(() => _channel = v)),
                const SizedBox(height: 20),
                _numberField('Biaya promosi (Rp)', _cost, 'Misal: 50000'),
                const SizedBox(height: 14),
                _numberField('Omzet tambahan yang terlihat (Rp)', _revenue,
                    'Misal: 150000'),
                const SizedBox(height: 20),
                Text('Hasilnya?',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _chips(_outcomes, _outcome, (v) => setState(() => _outcome = v)),
                const SizedBox(height: 20),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    hintText: 'Misal: banyak yang tanya tapi belum beli',
                  ),
                ),
                const SizedBox(height: 20),
                _roiCard(),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Simpan Catatan',
                  icon: Icons.save_rounded,
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chips(List<String> items, String selected, ValueChanged<String> onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final it in items)
          Material(
            color: it == selected
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              onTap: () => onPick(it),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: it == selected
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor,
                    width: it == selected ? 1.5 : 1,
                  ),
                ),
                child: Text(it,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          it == selected ? FontWeight.w700 : FontWeight.w500,
                      color: it == selected
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary,
                    )),
              ),
            ),
          ),
      ],
    );
  }

  Widget _numberField(String label, TextEditingController c, String hint) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: 'Rp ',
      ),
    );
  }

  Widget _roiCard() {
    final roi = _roi;
    final positive = roi >= 0;
    final pct = (roi * 100).toStringAsFixed(0);
    final color = positive ? AppTheme.successColor : AppTheme.errorColor;
    final text = _costValue <= 0 && _revValue <= 0
        ? 'Isi biaya & omzet tambahan untuk melihat ROI.'
        : positive
            ? 'ROI +$pct% (untung)'
            : 'ROI $pct% (rugi)';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}
