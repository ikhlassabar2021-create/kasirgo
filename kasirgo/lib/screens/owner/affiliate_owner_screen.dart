import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/centennial_background.dart';

/// Layar Afiliasi untuk owner: kode & link referral otomatis per outlet,
/// laporan komisi (closing), rekening pembayaran komisi, dan panduan singkat.
class AffiliateOwnerScreen extends ConsumerStatefulWidget {
  const AffiliateOwnerScreen({super.key, this.service});

  final SupabaseService? service;

  @override
  ConsumerState<AffiliateOwnerScreen> createState() =>
      _AffiliateOwnerScreenState();
}

class _AffiliateOwnerScreenState extends ConsumerState<AffiliateOwnerScreen> {
  late final _service = widget.service ?? SupabaseService();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _closings = const [];

  final _bankNameCtrl = TextEditingController();
  final _bankAccountNameCtrl = TextEditingController();
  final _bankAccountNumberCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _bankAccountNameCtrl.dispose();
    _bankAccountNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Outlet tidak ditemukan.';
      });
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final res = await _service.rpc('affiliate_owner_me',
          params: {'p_outlet_id': outletId}) as Map<String, dynamic>? ??
          const {};
      if (!mounted) return;
      if (res['found'] == true) {
        final profile = (res['profile'] as Map?)?.cast<String, dynamic>();
        _bankNameCtrl.text = profile?['bank_name']?.toString() ?? '';
        _bankAccountNameCtrl.text =
            profile?['bank_account_name']?.toString() ?? '';
        _bankAccountNumberCtrl.text =
            profile?['bank_account_number']?.toString() ?? '';
        setState(() {
          _profile = profile;
          _summary = (res['summary'] as Map?)?.cast<String, dynamic>();
          _closings = ((res['closings'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Profil afiliasi belum tersedia.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _saveBank() async {
    final outletId = ref.read(currentUserProvider)?.outletId ?? '';
    if (outletId.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _service.rpc('affiliate_owner_update', params: {
        'p_outlet_id': outletId,
        'p_bank_name': _bankNameCtrl.text.trim(),
        'p_bank_account_name': _bankAccountNameCtrl.text.trim(),
        'p_bank_account_number': _bankAccountNumberCtrl.text.trim(),
      });
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Rekening pembayaran komisi disimpan.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Gagal menyimpan: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String get _referralCode => _profile?['referral_code']?.toString() ?? '';

  String get _referralLink {
    final code = _referralCode;
    if (code.isEmpty) return '';
    return 'https://ikhlassabar2021-create.github.io/kasirgo/#/register?ref=$code';
  }

  String _fmtRp(dynamic v) {
    final value = (v is num) ? v : 0;
    return 'Rp ${NumberFormat('#,##0', 'id_ID').format(value)}';
  }

  String _fmtDate(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (dt == null) return '-';
    return DateFormat('d MMM yyyy', 'id_ID').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Afiliasi KasirGo',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: CentennialBackground(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppTheme.formMaxWidth),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            child: Column(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppTheme.errorColor, size: 32),
                const SizedBox(height: 8),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                TextButton(onPressed: _load, child: const Text('Coba lagi')),
              ],
            ),
          ),
        ],
      );
    }

    final isActive = _profile?['is_active'] == true;
    final commission = _profile?['commission_percent'];
    final summary = _summary ?? const {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status banner.
        _card(
          child: Row(
            children: [
              const Icon(Icons.verified_rounded,
                  color: AppTheme.successColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Outlet Anda sudah otomatis menjadi afiliasi KasirGo. '
                  'Bagikan kode di bawah — Anda dapat komisi ketika usaha baru '
                  'bergabung memakai kode ini.',
                  style: GoogleFonts.inter(
                      fontSize: 12.5, height: 1.45,
                      color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Kode & link referral.
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.link_rounded,
                      size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  Text('Kode & Link Referral',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const Spacer(),
                  if (!isActive)
                    _chip('Nonaktif', AppTheme.warningColor),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMutedColor,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _referralCode,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Salin kode',
                      icon: const Icon(Icons.copy_rounded,
                          size: 18, color: AppTheme.textSecondary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _referralCode));
                        _snack('Kode "$_referralCode" disalin.');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMutedColor,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _referralLink,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Salin link',
                      icon: const Icon(Icons.copy_rounded,
                          size: 18, color: AppTheme.textSecondary),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _referralLink));
                        _snack('Link referral disalin.');
                      },
                    ),
                  ],
                ),
              ),
              if (commission != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Komisi Anda: ${_fmtRp(0).replaceAll('0', commission.toString())}% per usaha baru yang bergabung.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Ringkasan komisi.
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Total Komisi',
                _fmtRp(summary['commission_total']),
                Icons.payments_rounded,
                AppTheme.successColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                'Belum Cair',
                _fmtRp(summary['unpaid_total']),
                Icons.schedule_rounded,
                AppTheme.warningColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                'Jumlah Closing',
                '${(summary['closing_count'] as num?)?.toInt() ?? 0}',
                Icons.handshake_rounded,
                AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Riwayat closing.
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Riwayat Closing',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 10),
              if (_closings.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Belum ada closing. Sebarkan kode referral Anda untuk mulai mendapat komisi.',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.4,
                        color: AppTheme.textSecondary),
                  ),
                )
              else
                ..._closings.map(_closingTile),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Rekening pembayaran komisi.
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_rounded,
                      size: 16, color: AppTheme.accentColor),
                  const SizedBox(width: 6),
                  Text('Rekening Pembayaran Komisi',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bankNameCtrl,
                decoration:
                    _deco('Nama Bank (mis. BCA / BRI / Mandiri)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bankAccountNameCtrl,
                decoration: _deco('Nama Pemilik Rekening'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bankAccountNumberCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: _deco('Nomor Rekening'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  onPressed: _saving ? null : _saveBank,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_saving ? 'Menyimpan...' : 'Simpan Rekening',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Panduan singkat.
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded,
                      size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  Text('Cara Kerja Komisi Afiliasi',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                ],
              ),
              const SizedBox(height: 10),
              _guideStep('1',
                  'Setiap outlet KasirGo otomatis mendapat kode afiliasi unik.'),
              _guideStep('2',
                  'Bagikan kode atau link referral ke sesama pelaku usaha.'),
              _guideStep('3',
                  'Bila usaha baru mendaftar memakai kode Anda dan berlangganan, Anda mendapat komisi.'),
              _guideStep('4',
                  'Komisi dicatat pada riwayat closing dan dibayar ke rekening Anda.'),
              const SizedBox(height: 8),
              Text(
                'Panduan lengkap (PDF) dan video tutorial: hubungi tim KasirGo '
                'atau lihat di Portal Afiliasi (web admin).',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    height: 1.4,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _closingTile(Map<String, dynamic> c) {
    final status = c['status']?.toString() ?? 'unpaid';
    final paid = status == 'paid';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMutedColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['referred_outlet_name']?.toString() ?? 'Usaha baru',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  _fmtDate(c['created_at']),
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmtRp(c['amount']),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.successColor)),
              _chip(paid ? 'Dibayar' : 'Belum Cair',
                  paid ? AppTheme.successColor : AppTheme.warningColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guideStep(String no, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Text(no,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10.5, color: AppTheme.textSecondary)),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  InputDecoration _deco(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppTheme.surfaceMutedColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: child,
    );
  }
}
