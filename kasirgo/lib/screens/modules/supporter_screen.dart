import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/payment_service.dart';
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
  Map<String, dynamic>? _pending;

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
    final pending = await svc.loadPendingCheckout(outletId);
    if (mounted) {
      setState(() {
        _billing = billing;
        _ent = ent;
        _pending = pending;
        _loading = false;
      });
    }
  }

  Future<void> _startTrial() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    setState(() => _busy = true);
    try {
      final ent = await SupporterService().ensureTrial(outletId);
      if (mounted) setState(() => _ent = ent);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Trial gratis aktif. Semua fitur premium terbuka.'),
          backgroundColor: AppTheme.successColor,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gagal mengaktifkan trial. Coba lagi.'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _support() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    final price =
        (_billing['supporter_price'] as num?)?.toDouble() ?? 50000;

    setState(() => _busy = true);
    SupporterCheckoutResult result;
    try {
      result = await SupporterService()
          .checkout(outletId: outletId, amount: price);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal: ${result.error ?? "-"}'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    await _showPaymentSheet(result);
    await _load();
  }

  /// Sheet pembayaran QRIS: scan pakai aplikasi bank/e-wallet, lalu konfirmasi.
  /// Aktivasi menunggu verifikasi admin (maks 1x24 jam).
  Future<void> _showPaymentSheet(SupporterCheckoutResult result) async {
    if (result.hasDynamicQr) {
      final paid = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _DynamicQrisSheet(result: result),
      );
      if (paid == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pembayaran diterima. Program Pendukung Anda aktif.'),
          backgroundColor: AppTheme.successColor,
        ));
      }
      await _load();
      return;
    }

    final payload = (_billing['qris_static_payload'] ?? '').toString();
    final transfer = _billing['manual_transfer'];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Pembayaran QRIS',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text('Order: ${result.orderId}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    Text(Formatters.currency(result.amount),
                        style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.secondaryColor)),
                    const SizedBox(height: 4),
                    Text('Program Pendukung - ${result.periodDays} hari',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    if (payload.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: QrImageView(
                          data: payload,
                          size: 190,
                          backgroundColor: Colors.white,
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.qr_code_2_rounded,
                            size: 120, color: AppTheme.textSecondary),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      payload.isNotEmpty
                          ? 'Scan QRIS di atas dengan aplikasi bank/e-wallet apa pun (GOJEK, OVO, DANA, BCA, dll).'
                          : 'QRIS belum tersedia. Gunakan transfer manual di bawah, lalu konfirmasi.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                          height: 1.4),
                    ),
                    if (transfer is Map && (transfer['bank'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceMutedColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Transfer: ${transfer['bank']} ${transfer['account']} a.n. ${transfer['name']}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final outletId =
                        ref.read(currentUserProvider)?.outletId ?? '';
                    final ok = await SupporterService()
                        .confirmPaymentSent(outletId, result.orderId);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok
                          ? 'Terima kasih! Pembayaran Anda menunggu verifikasi admin (maks 1x24 jam).'
                          : 'Gagal mengonfirmasi. Coba lagi.'),
                      backgroundColor: ok
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ));
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Saya Sudah Bayar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () async {
                  final outletId =
                      ref.read(currentUserProvider)?.outletId ?? '';
                  await SupporterService()
                      .cancelCheckout(outletId, result.orderId);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Batalkan',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingCard() {
    final status = (_pending?['status'] ?? '').toString();
    final amount = (_pending?['amount'] as num?)?.toDouble() ?? 0;
    final ref = (_pending?['pg_reference_id'] ?? '-').toString();
    final isWaitingVerify = status == 'pending_verification';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isWaitingVerify ? AppTheme.warningColor : AppTheme.primaryColor)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isWaitingVerify
                ? AppTheme.warningColor
                : AppTheme.primaryColor),
      ),
      child: Row(
        children: [
          Icon(
            isWaitingVerify ? Icons.hourglass_top_rounded : Icons.qr_code_2_rounded,
            color: isWaitingVerify ? AppTheme.warningColor : AppTheme.primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isWaitingVerify
                  ? 'Pembayaran $ref (${Formatters.currency(amount)}) menunggu verifikasi admin, maks 1x24 jam.'
                  : 'Ada pembayaran belum diselesaikan ($ref). Buka lagi lewat tombol dukung di bawah.',
              style: GoogleFonts.inter(
                  fontSize: 12, height: 1.35, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
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
                  if (!hasAccess && _pending != null) _pendingCard(),
                  if (!hasAccess)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.secondaryColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.rocket_launch_rounded,
                                  color: AppTheme.secondaryColor, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Coba dulu gratis, tanpa kartu kredit.',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : _startTrial,
                              icon: const Icon(Icons.rocket_launch_rounded,
                                  size: 18),
                              label: const Text('Coba Trial Gratis',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (hasAccess && !isSupporter) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.successColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded,
                              color: AppTheme.successColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Trial gratis aktif - sisa ${ent?.trialDaysLeft ?? 0} hari. '
                              'Semua fitur premium terbuka tanpa biaya.',
                              style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

/// Sheet QRIS dinamis (Midtrans) dengan polling status pembayaran otomatis.
class _DynamicQrisSheet extends StatefulWidget {
  final SupporterCheckoutResult result;
  const _DynamicQrisSheet({required this.result});

  @override
  State<_DynamicQrisSheet> createState() => _DynamicQrisSheetState();
}

class _DynamicQrisSheetState extends State<_DynamicQrisSheet> {
  Timer? _timer;
  late String _status;

  bool get _paid => _status == 'PAID';

  @override
  void initState() {
    super.initState();
    _status = widget.result.status.toUpperCase();
    if (_status != 'PAID') _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    final orderId = widget.result.providerOrderId;
    if (orderId == null) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final status = await PaymentService().checkStatus(orderId);
      if (!mounted) return;
      if (status == 'PAID' || status == 'SUCCESS' || status == 'SETTLEMENT') {
        timer.cancel();
        await PaymentService().confirmPaid(orderId);
        if (mounted) setState(() => _status = 'PAID');
      } else if (status == 'EXPIRED' || status == 'FAILED') {
        timer.cancel();
        if (mounted) setState(() => _status = status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final qrisString = widget.result.qrisString ?? '';
    final qrisUrl = widget.result.qrisUrl ?? '';
    final paymentUrl = widget.result.paymentUrl ?? '';
    final total = widget.result.totalAmount > 0
        ? widget.result.totalAmount
        : widget.result.amount;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(_paid ? 'Pembayaran Berhasil' : 'Pembayaran QRIS',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('Order: ${widget.result.providerOrderId ?? widget.result.orderId}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _paid ? AppTheme.successColor : AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  Text(Formatters.currency(total),
                      style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.secondaryColor)),
                  const SizedBox(height: 4),
                  Text('Program Pendukung - ${widget.result.periodDays} hari',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  if (_paid)
                    const Icon(Icons.check_circle_rounded,
                        size: 110, color: AppTheme.successColor)
                  else if (qrisString.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: QrImageView(
                        data: qrisString,
                        size: 190,
                        backgroundColor: Colors.white,
                      ),
                    )
                  else if (qrisUrl.isNotEmpty)
                    Image.network(qrisUrl,
                        width: 190,
                        height: 190,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.qr_code_2_rounded, size: 110))
                  else
                    const Icon(Icons.qr_code_2_rounded,
                        size: 110, color: AppTheme.textSecondary),
                  const SizedBox(height: 10),
                  if (!_paid)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Menunggu pembayaran...',
                            style: TextStyle(
                                fontSize: 11.5, color: AppTheme.textSecondary)),
                      ],
                    )
                  else
                    Text('Terima kasih! Program Pendukung Anda sudah aktif.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (!_paid && paymentUrl.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(paymentUrl),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Buka Halaman Bayar'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (!_paid) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _paid),
                icon: Icon(_paid ? Icons.check_rounded : Icons.close_rounded,
                    size: 18),
                label: Text(_paid ? 'Selesai' : 'Tutup',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _paid ? AppTheme.successColor : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
