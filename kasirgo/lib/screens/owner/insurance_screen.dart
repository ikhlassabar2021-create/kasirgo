import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/insurance_service.dart';
import '../../utils/formatters.dart';

/// Micro-Insurance Toko - Phase 10 / ST10-3.
/// Produk + premi dari config superadmin; komisi platform tercatat
/// otomatis untuk rekap superadmin.
class InsuranceScreen extends ConsumerStatefulWidget {
  const InsuranceScreen({super.key});

  @override
  ConsumerState<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends ConsumerState<InsuranceScreen> {
  final InsuranceService _insurance = InsuranceService();

  bool _loading = true;
  InsuranceConfig _cfg = InsuranceConfig.fallback;
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _policies = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId ?? '';
    final cfg = await _insurance.loadConfig();
    List<Map<String, dynamic>> leads = [];
    List<Map<String, dynamic>> policies = [];
    if (outletId.isNotEmpty) {
      leads = await _insurance.getLeads(outletId);
      policies = await _insurance.getPolicies(outletId);
    }
    if (!mounted) return;
    setState(() {
      _cfg = cfg;
      _leads = leads;
      _policies = policies;
      _loading = false;
    });
  }

  Future<void> _apply(InsuranceProduct product) async {
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId ?? '';
    if (outletId.isEmpty || user == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Text('Ajukan ${product.name}',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultRow('Premi / tahun', Formatters.currency(product.premi)),
            _resultRow('Perlindungan', Formatters.currency(product.coverage)),
            const SizedBox(height: 6),
            Text(
                'Pengajuan diteruskan ke ${_cfg.partnerName}. '
                'Komisi platform (${_cfg.commissionPercent.toStringAsFixed(0)}%) '
                'tidak dikenakan ke kamu.',
                style: GoogleFonts.inter(
                    fontSize: 11.5, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Icon(Icons.close_rounded, size: 20)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Ajukan',
                  style: GoogleFonts.inter(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final sent = await _insurance.submitLead(
      outletId: outletId,
      userId: user.id,
      product: product,
    );

    final channel = _cfg.applyChannel;
    if (sent && channel != null) {
      final url = channel.startsWith('https://wa.me/')
          ? _insurance.buildWaLink(
              _cfg.waNumber, _cfg.partnerName, product.name)
          : channel;
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('InsuranceScreen.launch error: $e');
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sent
            ? 'Pengajuan tercatat${channel == null ? ' (link partner belum diatur superadmin)' : ' & diteruskan ke partner'}.'
            : 'Gagal menyimpan pengajuan.'),
        backgroundColor: sent ? AppTheme.successColor : AppTheme.errorColor));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Asuransi Mikro',
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_cfg.enabled || _cfg.products.isEmpty)
                  _buildDisabled()
                else ...[
                  ..._cfg.products.map(_productCard),
                  const SizedBox(height: 20),
                  if (_policies.isNotEmpty) ...[
                    Text('POLIS AKTIF',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    ..._policies.map(_policyCard),
                    const SizedBox(height: 16),
                  ],
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
                      child: Text('Belum ada pengajuan asuransi.',
                          style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary)),
                    )
                  else
                    ..._leads.map(_leadCard),
                ],
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildDisabled() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.health_and_safety_rounded,
              size: 40, color: AppTheme.textSecondary),
          const SizedBox(height: 10),
          Text('Produk Asuransi Belum Tersedia',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'Pengelola aplikasi belum mengatur produk asuransi mikro. '
            'Cek kembali nanti.',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _productCard(InsuranceProduct p) {
    final typeLabel = switch (p.type) {
      'toko' => 'Toko',
      'kebakaran' => 'Kebakaran',
      'barang' => 'Barang Dagangan',
      _ => 'Lainnya',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety_rounded,
                  size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(p.name,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(typeLabel,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor)),
              ),
            ],
          ),
          if (p.note != null && p.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(p.note!,
                style: GoogleFonts.inter(
                    fontSize: 11.5, color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Premi / tahun',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppTheme.textSecondary)),
                    Text(Formatters.currency(p.premi),
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Perlindungan s.d.',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppTheme.textSecondary)),
                    Text(Formatters.currency(p.coverage),
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.successColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _apply(p),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text('Ajukan',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700)),
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

  Widget _policyCard(Map<String, dynamic> pol) {
    final started = pol['started_at'] != null
        ? DateTime.parse(pol['started_at'])
        : null;
    final expires = pol['expires_at'] != null
        ? DateTime.parse(pol['expires_at'])
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
            color: AppTheme.successColor.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: const Icon(Icons.verified_rounded,
            size: 22, color: AppTheme.successColor),
        title: Text(pol['product_code']?.toString() ?? 'Polis',
            style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        subtitle: Text(
          '${pol['policy_number'] ?? '-'}'
          '${started != null ? ' - mulai ${started.day}/${started.month}/${started.year}' : ''}'
          '${expires != null ? ' s.d. ${expires.day}/${expires.month}/${expires.year}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
        ),
        trailing: Text(
          (pol['status'] ?? 'active').toString().toUpperCase(),
          style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.successColor),
        ),
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
        leading: const Icon(Icons.description_rounded,
            size: 22, color: AppTheme.textSecondary),
        title: Text(lead['product_name']?.toString() ?? 'Asuransi',
            style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${lead['ref'] ?? '-'} - premi ${Formatters.currency(d(lead['premi']))}'
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

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12.5, color: AppTheme.textSecondary)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
