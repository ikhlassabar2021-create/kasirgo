import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/fintech_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

/// Modal Usaha (Fintech Lead) - Phase 10 / ST10-1.
///
/// Estimasi plafon dihitung dari arus kas (AI engine lokal). Pengajuan
/// kirim AGREGAT ANONIM (tanpa identitas pelanggan) sesuai UU PDP.
class FintechScreen extends ConsumerStatefulWidget {
  const FintechScreen({super.key});

  @override
  ConsumerState<FintechScreen> createState() => _FintechScreenState();
}

class _FintechScreenState extends ConsumerState<FintechScreen> {
  final SupabaseService _service = SupabaseService();
  final FintechService _fintech = FintechService();

  bool _loading = true;
  FintechConfig _cfg = FintechConfig.fallback;
  CashFlowProfile _profile = CashFlowProfile.empty;
  List<Map<String, dynamic>> _leads = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = ref.read(currentUserProvider);
    final cfg = await _fintech.loadConfig();

    CashFlowProfile profile = CashFlowProfile.empty;
    List<Map<String, dynamic>> leads = [];
    if (user?.outletId != null && user!.outletId!.isNotEmpty) {
      final start = DateTime.now().subtract(const Duration(days: 90));
      final txs = await _service.getTransactions(user.outletId!,
          limit: 2000, startDate: start);
      profile = _fintech.computeCashFlow(txs);
      leads = await _fintech.getLeads(user.outletId!);
    }
    if (!mounted) return;
    setState(() {
      _cfg = cfg;
      _profile = profile;
      _leads = leads;
      _loading = false;
    });
  }

  Future<void> _apply() async {
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId ?? '';
    if (outletId.isEmpty || user == null) return;
    if (_profile.txCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Belum ada transaksi 90 hari. Catat penjualan dulu agar '
                  'skor kelayakan bisa dihitung.'),
          backgroundColor: AppTheme.warningColor));
      return;
    }

    final amountCtl = TextEditingController(
        text: _profile.suggestedPlafon.toStringAsFixed(0));
    int tenor = 6;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
          title: Text('Ajukan Modal Usaha',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Dikirim ke ${_cfg.partnerName} beserta ringkasan arus kas '
                  'AGREGAT ANONIM (tanpa data pelanggan).',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(
                    fontSize: 15, color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Jumlah diajukan (Rp)',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 10),
              Text('TENOR',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              Row(
                children: [3, 6, 12].map((t) {
                  final selected = tenor == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$t bln'),
                      selected: selected,
                      selectedColor:
                          AppTheme.primaryColor.withValues(alpha: 0.2),
                      labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary),
                      onSelected: (_) => setDialog(() => tenor = t),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Batal',
                    style: GoogleFonts.inter(color: AppTheme.textSecondary))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Ajukan',
                    style: GoogleFonts.inter(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final amount = double.tryParse(
            amountCtl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Jumlah tidak valid'),
          backgroundColor: AppTheme.errorColor));
      return;
    }

    final sent = await _fintech.submitLead(
      outletId: outletId,
      userId: user.id,
      partner: _cfg.partnerName,
      amountRequested: amount,
      tenorMonths: tenor,
      profile: _profile,
    );

    // Buka channel partner (link / fallback wa.me) setelah lead tercatat.
    final channel = _cfg.applyChannel;
    if (sent && channel != null) {
      final url = channel.startsWith('https://wa.me/')
          ? _fintech.buildWaLink(_cfg.waNumber, _cfg.partnerName,
              user.name ?? user.email, amount, tenor)
          : channel;
      try {
        await launchUrl(Uri.parse(url),
            mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('FintechScreen.launch error: $e');
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sent
            ? (channel == null
                ? 'Pengajuan tercatat. Link partner belum diatur superadmin.'
                : 'Pengajuan tercatat & diteruskan ke ${_cfg.partnerName}.')
            : 'Gagal menyimpan pengajuan.'),
        backgroundColor: sent
            ? AppTheme.successColor
            : AppTheme.errorColor));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Modal Usaha',
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
                  _buildPlafonCard(),
                  const SizedBox(height: 14),
                  _buildPrivacyNote(),
                  const SizedBox(height: 20),
                  Text('RIWAYAT PENGAJUAN',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  if (_leads.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Text('Belum ada pengajuan modal.',
                          style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary)),
                    )
                  else
                    ..._leads.map(_leadCard),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildPlafonCard() {
    final hasData = _profile.txCount > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), AppTheme.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, size: 18, color: Colors.white70),
              const SizedBox(width: 6),
              Text('ESTIMASI PLAFON (${_cfg.partnerName})',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasData
                ? Formatters.currency(_profile.suggestedPlafon)
                : 'Belum cukup data',
            style: GoogleFonts.inter(
                fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            'Skor kelayakan: ${_profile.score.toStringAsFixed(0)}/100 '
            '(dari arus kas ${_profile.windowDays} hari)',
            style: GoogleFonts.inter(
                fontSize: 11.5, color: Colors.white.withValues(alpha: 0.9)),
          ),
          if (hasData) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _profile.score / 100,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _statMini('Omzet/bulan', Formatters.currency(_profile.monthlyOmzet)),
                _statMini('Rata-rata belanja', Formatters.currency(_profile.avgBasket)),
                _statMini('Transaksi', '${_profile.txCount}'),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.trending_up_rounded, size: 18),
              label: Text('Ajukan Modal',
                  style: GoogleFonts.inter(
                      fontSize: 13.5, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('Estimasi indikatif - keputusan akhir oleh mitra pembiayaan.',
              style: GoogleFonts.inter(
                  fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _statMini(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, color: Colors.white70)),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_rounded,
              size: 18, color: AppTheme.successColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Privasi (UU PDP): yang dikirim hanya ringkasan agregat '
              '(omzet, jumlah transaksi, rata-rata belanja). Tidak ada data '
              'pribadi pelanggan yang dibagikan.',
              style: GoogleFonts.inter(
                  fontSize: 11.5, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leadCard(Map<String, dynamic> lead) {
    final status = lead['status']?.toString() ?? 'lead';
    final statusColor = switch (status) {
      'approved' => AppTheme.successColor,
      'rejected' => AppTheme.errorColor,
      'apply' => AppTheme.primaryColor,
      _ => AppTheme.warningColor,
    };
    double d(dynamic v) =>
        v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);
    final createdAt = lead['created_at'] != null
        ? DateTime.parse(lead['created_at'])
        : DateTime.now();
    final tenor = lead['tenor_months'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: const Icon(Icons.account_balance_rounded,
            size: 22, color: AppTheme.textSecondary),
        title: Text(Formatters.currency(d(lead['amount_requested'])),
            style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${lead['partner'] ?? '-'} - ${lead['ref'] ?? '-'}'
            '${tenor != null ? ' - tenor $tenor bln' : ''}'
            ' - ${createdAt.day}/${createdAt.month}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppTheme.textSecondary),
          ),
        ),
        trailing: Text(status.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: statusColor)),
      ),
    );
  }
}
