import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/supporter_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/centennial_background.dart';

class SupporterScreen extends ConsumerStatefulWidget {
  const SupporterScreen({super.key});

  @override
  ConsumerState<SupporterScreen> createState() => _SupporterScreenState();
}

class _SupporterScreenState extends ConsumerState<SupporterScreen> {
  bool _loading = true;
  bool _busy = false;
  Entitlements? _ent;
  Map<String, dynamic> _billing = SupporterService.fallbackBilling;
  bool _autoRenew = true;

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
    final svc = SupporterService();
    final billing = await svc.getBillingConfig();
    final ent = await svc.getEntitlements(outletId);
    if (mounted) {
      setState(() {
        _billing = billing;
        _ent = ent;
        _loading = false;
      });
    }
  }

  Future<void> _support() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    final price =
        (_billing['supporter_price'] as num?)?.toDouble() ?? 50000;

    setState(() => _busy = true);
    try {
      final result = await SupporterService()
          .checkout(outletId: outletId, amount: price);
      if (!mounted) return;
      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: ${result.error ?? "-"}'),
          backgroundColor: AppTheme.errorColor,
        ));
        return;
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Terima kasih! Status Pendukung aktif.'),
          backgroundColor: AppTheme.successColor,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleAutoRenew(bool v) async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    setState(() => _autoRenew = v);
    await SupporterService().setAutoRenew(outletId, v);
  }

  @override
  Widget build(BuildContext context) {
    final price =
        (_billing['supporter_price'] as num?)?.toDouble() ?? 50000;
    final ent = _ent;
    final hasAccess = ent?.hasAccess ?? false;
    final isSupporter = ent?.isSupporter ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Program Pendukung',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: CentennialBackground(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite,
                          size: 44, color: AppTheme.warningColor),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      'Dukung Ekosistem KasirGo',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fitur inti tetap gratis selamanya. Program Pendukung '
                    'membuka fitur bonus dan menghilangkan iklan sponsor di '
                    'katalog pelanggan Anda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: hasAccess
                              ? AppTheme.secondaryColor
                              : AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pendukung KasirGo',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary)),
                            if (isSupporter)
                              _chip('PENDUKUNG', AppTheme.secondaryColor)
                            else if (hasAccess)
                              _chip('TRIAL ${ent?.trialDaysLeft ?? 0} HARI',
                                  AppTheme.warningColor),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${Formatters.currency(price)} / bulan',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.secondaryColor),
                        ),
                        const SizedBox(height: 14),
                        ...SupporterService.premiumFeatures
                            .map((k) => _benefit(
                                SupporterService.featureLabels[k] ?? k)),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _busy ? null : _support,
                            icon: const Icon(Icons.favorite_rounded, size: 18),
                            label: Text(
                              isSupporter
                                  ? 'Perpanjang Dukungan'
                                  : 'Dukung KasirGo Sekarang',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        if (isSupporter) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Perpanjang otomatis tiap bulan',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary)),
                              Switch(
                                value: _autoRenew,
                                activeThumbColor: AppTheme.primaryColor,
                                onChanged: _toggleAutoRenew,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color)),
      );

  Widget _benefit(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.check_circle, size: 15, color: AppTheme.successColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppTheme.textPrimary)),
            ),
          ],
        ),
      );
}
