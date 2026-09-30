import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/hyperlocal_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

/// Hyperlocal Data - Phase 10 / ST10-2.
///
/// Tren wilayah dari AGREGAT ANONIM (tanpa data pelanggan, UU PDP).
/// Owner opt-in (consent) sebelum data dikirim ke jaringan wilayah.
class HyperlocalScreen extends ConsumerStatefulWidget {
  const HyperlocalScreen({super.key});

  @override
  ConsumerState<HyperlocalScreen> createState() => _HyperlocalScreenState();
}

class _HyperlocalScreenState extends ConsumerState<HyperlocalScreen> {
  final SupabaseService _service = SupabaseService();
  final HyperlocalService _hyperlocal = HyperlocalService();

  bool _loading = true;
  bool _consent = false;
  bool _sending = false;
  final TextEditingController _regionCtl = TextEditingController();
  RegionInsights _insights = const RegionInsights(region: '', period: '');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _regionCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId ?? '';
    if (outletId.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    final consent = await _hyperlocal.getConsent(outletId);
    final insights =
        await _hyperlocal.getRegionInsights(_regionCtl.text.trim());
    if (!mounted) return;
    setState(() {
      _consent = consent;
      _insights = insights;
      _loading = false;
    });
  }

  Future<void> _toggleConsent(bool value) async {
    final outletId = ref.read(currentUserProvider)?.outletId ?? '';
    if (outletId.isEmpty) return;
    if (value) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
          title: Text('Izin Bagikan Data Anonim',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          content: Text(
              'Kamu setuju KasirGo mengirim RINGKASAN ANONIM toko ini '
              '(jumlah transaksi, omzet, produk terlaris, jam ramai) untuk '
              'insight wilayah?\n\nTIDAK ADA nama, nomor, atau identitas '
              'pelanggan yang dikirim (sesuai UU PDP). Bisa dimatikan '
              'kapan saja.',
              style: GoogleFonts.inter(
                  fontSize: 12.5, color: AppTheme.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Tidak',
                    style:
                        GoogleFonts.inter(color: AppTheme.textSecondary))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Setuju',
                    style: GoogleFonts.inter(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w800))),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _hyperlocal.setConsent(outletId, value);
    if (!mounted) return;
    setState(() => _consent = value);
  }

  /// Bangun agregat bulan ini + kirim (opt-in).
  Future<void> _submitReport() async {
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId ?? '';
    final region = _regionCtl.text.trim();
    if (outletId.isEmpty || user == null) return;
    if (region.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Isi wilayah dulu (cth: Kec. Larangan).'),
          backgroundColor: AppTheme.warningColor));
      return;
    }

    setState(() => _sending = true);
    final start = DateTime.now().subtract(const Duration(days: 45));
    final txs = await _service.getTransactions(outletId,
        limit: 2000, startDate: start);
    final payload = _hyperlocal.buildAggregate(txs);
    final ok = await _hyperlocal.submit(
        outletId: outletId, region: region, payload: payload);
    final insights = await _hyperlocal.getRegionInsights(region);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _insights = insights;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Laporan anonim terkirim. Terima kasih!'
            : 'Gagal mengirim laporan.'),
        backgroundColor:
            ok ? AppTheme.successColor : AppTheme.errorColor));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Tren Wilayah',
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
                _buildConsentCard(),
                const SizedBox(height: 14),
                _buildRegionCard(),
                const SizedBox(height: 14),
                _buildInsightsCard(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildConsentCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
            color: _consent
                ? AppTheme.successColor.withValues(alpha: 0.5)
                : AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(
            _consent
                ? Icons.verified_user_rounded
                : Icons.privacy_tip_rounded,
            size: 22,
            color:
                _consent ? AppTheme.successColor : AppTheme.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bagikan Data Anonim (Opt-in)',
                    style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  'Hanya agregat: omzet, transaksi, produk terlaris. '
                  'Tanpa identitas pelanggan (UU PDP).',
                  style: GoogleFonts.inter(
                      fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: _consent,
            activeThumbColor: AppTheme.successColor,
            onChanged: _toggleConsent,
          ),
        ],
      ),
    );
  }

  Widget _buildRegionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WILAYAH TOKO',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: _regionCtl,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.inter(
                fontSize: 14, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'cth: Kec. Larangan, Kel. Cengkareng',
              hintStyle: GoogleFonts.inter(
                  fontSize: 12.5, color: AppTheme.textSecondary),
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_consent && !_sending) ? _submitReport : null,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_rounded, size: 18),
              label: Text(
                  _sending ? 'Mengirim...' : 'Kirim Laporan Bulan Ini',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.borderColor,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium)),
              ),
            ),
          ),
          if (!_consent) ...[
            const SizedBox(height: 6),
            Text('Aktifkan izin dulu untuk bisa mengirim.',
                style: GoogleFonts.inter(
                    fontSize: 10.5, color: AppTheme.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightsCard() {
    final hasData = _insights.txCount > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF06B6D4), AppTheme.primaryColor],
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
              const Icon(Icons.travel_explore_rounded,
                  size: 18, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    'INSIGHT WILAYAH'
                    '${_insights.region.isEmpty ? '' : ' - ${_insights.region.toUpperCase()}'}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasData)
            Text(
              'Belum ada data wilayah. Kirim laporan anonim, lalu insight '
              'akan muncul saat toko lain di wilayah yang sama ikut berbagi.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
            )
          else ...[
            Text(
                '${_insights.participantStores} toko berpartisipasi (anonim) - '
                'periode ${_insights.period}',
                style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white70)),
            const SizedBox(height: 10),
            Row(
              children: [
                _statMini('Transaksi', '${_insights.txCount}'),
                _statMini('Rata-rata belanja',
                    Formatters.currency(_insights.avgBasket)),
              ],
            ),
            const SizedBox(height: 10),
            Text('PRODUK TERLARIS WILAYAH',
                style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white70)),
            const SizedBox(height: 4),
            ..._insights.topProducts.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    const Icon(Icons.chevron_right_rounded,
                        size: 14, color: Colors.white70),
                    Expanded(
                      child: Text(p,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
            if (_insights.busyHours.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('JAM RAMAI (gabungan wilayah)',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70)),
              const SizedBox(height: 4),
              Text(
                _busyHoursLabel(_insights.busyHours),
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white),
              ),
            ],
          ],
          const SizedBox(height: 6),
          Text('Data agregat anonim - tidak ada data pelanggan.',
              style: GoogleFonts.inter(
                  fontSize: 10, color: Colors.white.withValues(alpha: 0.75))),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      ),
    );
  }

  String _busyHoursLabel(Map<int, int> hours) {
    if (hours.isEmpty) return '-';
    final sorted = hours.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).map((e) => '${e.key}:00').join(', ');
    return top;
  }
}
