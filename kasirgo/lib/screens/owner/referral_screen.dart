import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/growth_service.dart';
import '../../services/supporter_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/centennial_background.dart';

/// ST15-3 (13.25.6): Referral berjenjang — kode pembawa + hadiah teman.
/// Tracking konversi + laporan + bagikan via wa.me.
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final GrowthService _service = GrowthService();
  bool _loading = true;
  List<Map<String, dynamic>> _codes = [];
  List<Map<String, dynamic>> _stats = [];

  String? get _outletId {
    final id = ref.read(currentUserProvider)?.outletId;
    return (id == null || id.isEmpty) ? null : id;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final outletId = _outletId;
    if (outletId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final codes = await _service.listReferralCodes(outletId);
      final stats = await _service.referralStats(outletId);
      if (mounted) {
        setState(() {
          _codes = codes;
          _stats = stats;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _shareCode(Map<String, dynamic> code) async {
    final outletId = _outletId;
    final outletName = ref.read(currentUserProvider)?.name ?? 'Toko kami';
    final kode = code['code']?.toString() ?? '';
    final reward = (code['friend_reward_amount'] as num?)?.toDouble() ?? 0;
    final msg = 'Halo! Dapatkan potongan '
        '${reward > 0 ? Formatters.currency(reward) : 'spesial'} '
        'di $outletName dengan kode *$kode*. '
        'Sebutkan kode ini saat belanja ya!';

    // Ambil nomor WA owner (KYC) sebagai pengirim default.
    String? phone;
    if (outletId != null) {
      try {
        phone = await SupporterService().getOwnerWa(outletId);
      } catch (_) {}
    }
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
      digits.isEmpty
          ? 'https://wa.me/?text=${Uri.encodeComponent(msg)}'
          : 'https://wa.me/$digits?text=${Uri.encodeComponent(msg)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: msg));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teks promosi disalin ke clipboard')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Program Referral',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: CentennialBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummary(),
                    const SizedBox(height: 16),
                    if (_codes.isEmpty)
                      _buildEmpty()
                    else
                      ..._codes.map((c) => _buildCodeCard(c)),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'ref_add',
        onPressed: _openForm,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kode Baru'),
      ),
    );
  }

  Widget _buildSummary() {
    final total = _codes.fold<int>(
        0, (s, c) => s + ((c['redeemed_count'] as num?)?.toInt() ?? 0));
    final converted =
        _stats.fold<int>(0, (s, st) => s + ((st['converted'] as int?) ?? 0));
    final spend = _stats.fold<double>(
        0, (s, st) => s + ((st['spend'] as num?)?.toDouble() ?? 0));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.aiBadgeGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Row(
        children: [
          _stat('Kode Aktif', '${_codes.where((c) => c['is_active'] == true).length}'),
          _stat('Diklaim', '$total'),
          _stat('Konversi', '$converted'),
          _stat('Omzet', Formatters.currency(spend)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.card_giftcard_rounded,
              size: 44, color: AppTheme.primaryColor),
          const SizedBox(height: 12),
          Text('Belum Ada Kode Referral',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'Buat kode berjenjang: pembawa dapat hadiah, teman yang diajak juga dapat potongan. Bagikan lewat WhatsApp.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(Map<String, dynamic> code) {
    final kode = code['code']?.toString() ?? '';
    final title = code['title']?.toString() ?? '';
    final reward = (code['reward_amount'] as num?)?.toDouble() ?? 0;
    final friend = (code['friend_reward_amount'] as num?)?.toDouble() ?? 0;
    final isActive = code['is_active'] == true;
    final redeemed = (code['redeemed_count'] as num?)?.toInt() ?? 0;
    final stat = _stats.firstWhere(
      (s) => s['referral_code_id'] == code['id'],
      orElse: () => const {},
    );
    final converted = (stat['converted'] as int?) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  kode,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppTheme.primaryColor),
                ),
              ),
              const SizedBox(width: 10),
              if (title.isNotEmpty)
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                )
              else
                const Spacer(),
              Switch(
                value: isActive,
                onChanged: (v) async {
                  await _service.toggleReferralCode(code['id'], v);
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _rewardChip('Pembawa', reward, AppTheme.successColor),
              const SizedBox(width: 8),
              _rewardChip('Diajak', friend, AppTheme.primaryColor),
              const Spacer(),
              Text('Diklaim $redeemed · Konversi $converted',
                  style: const TextStyle(
                      fontSize: 10.5, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareCode(code),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Bagikan via WA', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    side: const BorderSide(color: Color(0xFF25D366)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rewardChip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: ${Formatters.currency(amount)}',
        style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Future<void> _openForm() async {
    final outletId = _outletId;
    if (outletId == null) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ReferralFormSheet(),
    );
    if (result != null) {
      await _service.saveReferralCode(
        outletId: outletId,
        code: result['code'],
        title: result['title'],
        rewardAmount: result['reward_amount'],
        friendRewardAmount: result['friend_reward_amount'],
        minSpend: result['min_spend'],
        maxRedemptions: result['max_redemptions'],
      );
      _load();
    }
  }
}

class _ReferralFormSheet extends StatefulWidget {
  const _ReferralFormSheet();

  @override
  State<_ReferralFormSheet> createState() => _ReferralFormSheetState();
}

class _ReferralFormSheetState extends State<_ReferralFormSheet> {
  final _codeCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _rewardCtrl = TextEditingController();
  final _friendCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    _titleCtrl.dispose();
    _rewardCtrl.dispose();
    _friendCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kode Referral Baru',
                style: GoogleFonts.inter(
                    fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Kode (mis. HEMAT10)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Judul kampanye (opsional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rewardCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Hadiah pembawa (Rp)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _friendCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Potongan teman (Rp)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min. belanja (Rp)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Batas klaim (0=∞)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor),
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Buat Kode'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kode wajib diisi')));
      return;
    }
    Navigator.pop(context, {
      'code': code,
      'title': _titleCtrl.text.trim(),
      'reward_amount': double.tryParse(_rewardCtrl.text.trim()) ?? 0,
      'friend_reward_amount': double.tryParse(_friendCtrl.text.trim()) ?? 0,
      'min_spend': double.tryParse(_minCtrl.text.trim()) ?? 0,
      'max_redemptions': int.tryParse(_maxCtrl.text.trim()) ?? 0,
    });
  }
}
