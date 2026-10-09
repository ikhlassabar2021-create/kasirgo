import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/dm_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/centennial_background.dart';
import 'business_doctor_screen.dart';

/// ST16-4 (13.28): Studio Iklan - Team Iklan AI.
/// Campaign draft (Meta/Google/TikTok/Shopee Ads) -> approval WAJIB owner ->
/// aktivasi (API bila kanal terhubung, else checklist manual) -> monitor
/// ROAS/CTR/CPC -> rekomendasi geser budget -> masuk chat Dokter Bisnis.
class AdsStudioScreen extends ConsumerStatefulWidget {
  const AdsStudioScreen({super.key});

  @override
  ConsumerState<AdsStudioScreen> createState() => _AdsStudioScreenState();
}

class _AdsStudioScreenState extends ConsumerState<AdsStudioScreen> {
  final DmService _service = DmService();

  bool _loading = true;
  bool _busy = false;

  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _assets = [];
  Map<String, dynamic> _guardrails = {};
  List<Map<String, dynamic>> _channels = [];
  String _modeAds = 'manual';

  static const _adsChannels = <String, String>{
    'meta': 'Meta Ads (FB/IG)',
    'google': 'Google Ads',
    'tiktok': 'TikTok Ads',
    'shopee': 'Shopee Ads',
  };

  static const _channelToAccount = <String, String>{
    'meta': 'meta_ads',
    'google': 'google_ads',
    'tiktok': 'tiktok_ads',
    'shopee': 'shopee_ads',
  };

  static const _objectives = <String, String>{
    'awareness': 'Jangkauan / Awareness',
    'traffic': 'Kunjungan / Traffic',
    'engagement': 'Interaksi / Engagement',
    'leads': 'Chat / Leads (WA)',
    'conversions': 'Penjualan / Konversi',
  };

  static const _platformUrl = <String, String>{
    'meta': 'https://adsmanager.facebook.com/',
    'google': 'https://ads.google.com/',
    'tiktok': 'https://ads.tiktok.com/',
    'shopee': 'https://seller.shopee.co.id/',
  };

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
      final results = await Future.wait([
        _service.listCampaigns(outletId),
        _service.listAssets(outletId),
        _service.getGuardrails(outletId),
        _service.getChannelStatus(outletId),
        _service.getSettings(outletId),
      ]);
      if (!mounted) return;
      setState(() {
        _campaigns = results[0] as List<Map<String, dynamic>>;
        _assets = results[1] as List<Map<String, dynamic>>;
        _guardrails = results[2] as Map<String, dynamic>;
        _channels = results[3] as List<Map<String, dynamic>>;
        final settings = results[4] as Map<String, dynamic>;
        _modeAds = (settings['mode_ads'] ?? 'manual').toString();
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool _isConnected(String channel) {
    final acc = _channelToAccount[channel];
    return _channels.any(
        (c) => c['channel'] == acc && c['is_connected'] == true);
  }

  Future<void> _saveMode() async {
    final outletId = _outletId;
    if (outletId == null) return;
    setState(() => _busy = true);
    try {
      await _service.saveSettings(outletId, {'mode_ads': _modeAds});
      _snack('Pengaturan mode disimpan.');
    } catch (e) {
      _snack('Gagal menyimpan: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _newCampaign() async {
    final outletId = _outletId;
    if (outletId == null) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NewCampaignSheet(
        assets: _assets,
        channels: _adsChannels,
        objectives: _objectives,
      ),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await _service.saveCampaign(
        outletId: outletId,
        channel: result['channel'] as String,
        assetId: result['asset_id'] as String?,
        objective: result['objective'] as String?,
        budgetDaily: result['budget_daily'] as num,
        radiusKm: result['radius_km'] as num,
        startDate: result['start_date'] as DateTime?,
        endDate: result['end_date'] as DateTime?,
      );
      await _service.logAction(outletId, 'campaign.draft', {
        'channel': result['channel'],
        'budget_daily': result['budget_daily'],
      });
      _snack('Draf kampanye dibuat. Setujui untuk mengaktifkan.');
      await _load();
    } catch (e) {
      _snack('Gagal membuat kampanye: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  num _effectiveCap() {
    final owner = _num(_guardrails['owner_daily_limit']);
    final global = _num(_guardrails['global_daily_cap']);
    if (owner > 0 && global > 0) return owner < global ? owner : global;
    if (owner > 0) return owner;
    return global;
  }

  Future<void> _approve(Map<String, dynamic> c) async {
    final outletId = _outletId;
    if (outletId == null) return;
    final budget = _num(c['budget_daily']);
    final cap = _effectiveCap();
    final committed = _num(_guardrails['committed_daily_budget']);
    if (cap > 0 && (committed + budget) > cap) {
      _snack('Budget harian melebihi batas (Rp${Formatters.number(cap.toInt())}/hari, '
          'terpakai Rp${Formatters.number(committed.toInt())}).');
      return;
    }
    final ok = await _confirm(
      'Setujui Kampanye',
      'Kampanye ${_adsChannels[c['channel']] ?? c['channel']} dengan budget '
      'Rp${Formatters.number(budget.toInt())}/hari akan disetujui.\n\n'
      'Biaya iklan ditanggung di platform masing-masing (KasirGo tidak '
      'menampung uang iklan).',
      'Setujui',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await _service.updateCampaign(c['id'].toString(), {
        'status': 'approved',
        'approved_at': DateTime.now().toIso8601String(),
      });
      await _service.logAction(outletId, 'campaign.approve', {
        'campaign_id': c['id'],
        'channel': c['channel'],
        'budget_daily': budget,
      });
      _snack('Kampanye disetujui.');
      await _load();
    } catch (e) {
      _snack('Gagal menyetujui: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _activate(Map<String, dynamic> c) async {
    final outletId = _outletId;
    if (outletId == null) return;
    final channel = c['channel'].toString();
    final connected = _isConnected(channel);
    if (connected) {
      await _service.logAction(outletId, 'campaign.activate_api', {
        'campaign_id': c['id'],
        'channel': channel,
      });
    } else {
      final go = await _showManualChecklist(channel, c);
      if (!go) return;
    }
    setState(() => _busy = true);
    try {
      await _service.updateCampaign(c['id'].toString(), {
        'status': 'active',
        'external_id': c['external_id'] ??
            'KGO-ADS-${DateTime.now().millisecondsSinceEpoch}',
        'paused_reason': null,
      });
      await _service.logAction(outletId, 'campaign.activate', {
        'campaign_id': c['id'],
        'channel': channel,
        'mode': connected ? 'api' : 'manual',
      });
      _snack(connected
          ? 'Kampanye aktif (kanal terhubung).'
          : 'Kampanye aktif. Selesaikan pengaturan di platform iklan.');
      await _load();
    } catch (e) {
      _snack('Gagal mengaktifkan: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pause(Map<String, dynamic> c, {String? reason}) async {
    final outletId = _outletId;
    if (outletId == null) return;
    setState(() => _busy = true);
    try {
      await _service.updateCampaign(c['id'].toString(), {
        'status': 'paused',
        'paused_reason': reason ?? 'Dijeda manual oleh owner',
      });
      await _service.logAction(outletId, 'campaign.pause', {
        'campaign_id': c['id'],
        'channel': c['channel'],
        'reason': reason,
      });
      _snack('Kampanye dijeda.');
      await _load();
    } catch (e) {
      _snack('Gagal menjeda: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await _confirm('Hapus Kampanye',
        'Hapus draf/kampanye ini dari daftar?', 'Hapus');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await _service.deleteCampaign(c['id'].toString());
      await _load();
    } catch (e) {
      _snack('Gagal menghapus: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _monitor(Map<String, dynamic> c) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MetricsSheet(
        current: (c['metrics'] is Map)
            ? (c['metrics'] as Map).cast<String, dynamic>()
            : <String, dynamic>{},
      ),
    );
    if (result == null) return;
    final outletId = _outletId;
    if (outletId == null) return;
    final computed = computeAdMetrics(result);
    final roasTarget = _num(_guardrails['roas_target']);
    final isActive = c['status'] == 'active';
    final autoPause = isActive &&
        computed['roas']! > 0 &&
        roasTarget > 0 &&
        computed['roas']! < roasTarget;
    setState(() => _busy = true);
    try {
      final patch = <String, dynamic>{
        'metrics': {
          ...result,
          'ctr': computed['ctr'],
          'cpc': computed['cpc'],
          'roas': computed['roas'],
          'updated_at': DateTime.now().toIso8601String(),
        },
      };
      if (autoPause) {
        patch['status'] = 'paused';
        patch['paused_reason'] =
            'Pause otomatis: ROAS ${computed['roas']!.toStringAsFixed(2)} '
            '< target ${roasTarget.toStringAsFixed(1)}';
      }
      await _service.updateCampaign(c['id'].toString(), patch);
      await _service.logAction(
        outletId,
        autoPause ? 'campaign.autopause' : 'campaign.metrics',
        {
          'campaign_id': c['id'],
          'channel': c['channel'],
          'roas': computed['roas'],
          'ctr': computed['ctr'],
          'cpc': computed['cpc'],
        },
      );
      _snack(autoPause
          ? 'ROAS di bawah target - kampanye dijeda otomatis.'
          : 'Hasil iklan disimpan.');
      await _load();
    } catch (e) {
      _snack('Gagal menyimpan hasil: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Rekomendasi geser budget berdasarkan ROAS tiap kanal.
  String _recommendation() {
    final withRoas = <MapEntry<String, num>>[];
    for (final c in _campaigns) {
      final m = (c['metrics'] is Map)
          ? (c['metrics'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final roas = _num(m['roas']);
      if (roas > 0 && _num(m['spend']) > 0) {
        withRoas.add(MapEntry(c['channel'].toString(), roas));
      }
    }
    if (withRoas.isEmpty) {
      return 'Isi hasil iklan (klik & omzet) di tiap kampanye agar AI bisa '
          'menyarankan pergeseran budget.';
    }
    withRoas.sort((a, b) => b.value.compareTo(a.value));
    final best = withRoas.first;
    final worst = withRoas.last;
    if (best.key == worst.key || best.value <= worst.value) {
      return 'Semua kanal berjalan seimbang. Pertahankan budget saat ini dan '
          'fokus pada kreatif baru.';
    }
    return 'Geser sekitar 20% budget dari '
        '${_adsChannels[worst.key] ?? worst.key} '
        '(ROAS ${worst.value.toStringAsFixed(2)}) ke '
        '${_adsChannels[best.key] ?? best.key} '
        '(ROAS ${best.value.toStringAsFixed(2)}).';
  }

  Future<void> _askDoctor(String recommendation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessDoctorScreen(
          initialMessage:
              'Saya baru menjalankan iklan berbayar. Hasil: $recommendation '
              'Tolong analisa ROI promosi online vs offline saya dan beri saran.',
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(body, style: GoogleFonts.inter()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return res ?? false;
  }

  Future<bool> _showManualChecklist(
      String channel, Map<String, dynamic> c) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pasang Iklan Manual',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Akun ${_adsChannels[channel] ?? channel} belum terhubung. '
              'Buat kampanye di platform iklan dengan pengaturan berikut:',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            _checklistRow('Tujuan: ${_objectives[c['objective']] ?? c['objective'] ?? '-'}'),
            _checklistRow('Budget harian: Rp${Formatters.number(_num(c['budget_daily']).toInt())}'),
            _checklistRow('Radius area toko: ${_num(c['radius_km']).toInt()} km'),
            _checklistRow('Kreatif: aset dari Studio Desain'),
            _checklistRow('Biaya ditanggung di platform iklan (bukan di KasirGo)'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Buka Platform',
                    icon: Icons.open_in_new_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: () {
                      final url = _platformUrl[channel];
                      if (url != null) launchUrl(Uri.parse(url));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Tandai Aktif',
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return res ?? false;
  }

  Widget _checklistRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Studio Iklan',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: CentennialBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildGuardrail(),
                    const SizedBox(height: 12),
                    _buildControls(),
                    const SizedBox(height: 12),
                    _buildWeeklyReport(),
                    const SizedBox(height: 16),
                    ..._buildCampaigns(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGuardrail() {
    final owner = _num(_guardrails['owner_daily_limit']);
    final global = _num(_guardrails['global_daily_cap']);
    final committed = _num(_guardrails['committed_daily_budget']);
    final roas = _num(_guardrails['roas_target']);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text('Batas Aman Iklan',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Batas harian kamu: ${owner > 0 ? 'Rp${Formatters.number(owner.toInt())}' : 'Belum diatur'}\n'
            'Batas platform: ${global > 0 ? 'Rp${Formatters.number(global.toInt())}' : 'Tanpa batas'}\n'
            'Terpakai (disetujui): Rp${Formatters.number(committed.toInt())}/hari\n'
            'Target ROAS: ${roas > 0 ? roas.toStringAsFixed(1) : '-'} (pause otomatis bila di bawah)',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _modeAds,
                  decoration: const InputDecoration(
                    labelText: 'Mode tim iklan',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'manual', child: Text('Manual')),
                    DropdownMenuItem(value: 'auto', child: Text('Otomatis')),
                  ],
                  onChanged: (v) => setState(() => _modeAds = v ?? 'manual'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.save_rounded),
                tooltip: 'Simpan pengaturan',
                onPressed: _saveMode,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Buat Kampanye Iklan',
            icon: Icons.add_rounded,
            isLoading: _busy,
            onPressed: _busy ? null : _newCampaign,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyReport() {
    num spend = 0, revenue = 0;
    for (final c in _campaigns) {
      final m = (c['metrics'] is Map)
          ? (c['metrics'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      spend += _num(m['spend']);
      revenue += _num(m['revenue']);
    }
    final roas = spend > 0 ? revenue / spend : 0;
    final rec = _recommendation();
    return AppCard(
      gradient: const LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF4F46E5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Laporan Iklan Mingguan',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            'Belanja: Rp${Formatters.number(spend.toInt())}  |  '
            'Omzet: Rp${Formatters.number(revenue.toInt())}  |  '
            'ROAS: ${roas.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
                fontSize: 13, color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(rec,
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.92))),
          const SizedBox(height: 12),
          AppButton(
            label: 'Tanya Dokter Bisnis',
            icon: Icons.medical_services_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => _askDoctor(rec),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCampaigns() {
    if (_campaigns.isEmpty) {
      return [
        AppCard(
          child: Text(
            'Belum ada kampanye iklan. Buat kampanye dari kreatif Studio Desain, '
            'lalu setujui untuk memulai.',
            style: GoogleFonts.inter(color: AppTheme.textSecondary),
          ),
        ),
      ];
    }
    return _campaigns.map(_buildCampaignCard).toList();
  }

  Widget _buildCampaignCard(Map<String, dynamic> c) {
    final channel = c['channel'].toString();
    final status = (c['status'] ?? 'draft').toString();
    final asset = c['dm_assets'];
    final assetTitle = asset is Map ? (asset['title'] ?? '').toString() : '';
    final metrics = (c['metrics'] is Map)
        ? (c['metrics'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final statusColor = switch (status) {
      'active' => AppTheme.successColor,
      'approved' => AppTheme.primaryColor,
      'paused' => AppTheme.warningColor,
      'done' => AppTheme.textSecondary,
      _ => AppTheme.textSecondary,
    };
    final statusLabel = switch (status) {
      'active' => 'AKTIF',
      'approved' => 'DISETUJUI',
      'paused' => 'DIJEDA',
      'done' => 'SELESAI',
      _ => 'DRAF',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_adsChannels[channel] ?? channel,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusLabel,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_objectives[c['objective']] ?? c['objective'] ?? '-'}  |  '
              'Rp${Formatters.number(_num(c['budget_daily']).toInt())}/hari  |  '
              '${_num(c['radius_km']).toInt()} km',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
            if (assetTitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Kreatif: $assetTitle',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
            if (metrics['roas'] != null || metrics['spend'] != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _metricChip('ROAS', _num(metrics['roas']).toStringAsFixed(2)),
                  _metricChip('CTR', '${_num(metrics['ctr']).toStringAsFixed(2)}%'),
                  _metricChip('CPC', 'Rp${Formatters.number(_num(metrics['cpc']).toInt())}'),
                  _metricChip('Belanja', 'Rp${Formatters.number(_num(metrics['spend']).toInt())}'),
                ],
              ),
            ],
            if (status == 'paused' &&
                (c['paused_reason'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(c['paused_reason'].toString(),
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.warningColor)),
            ],
            const SizedBox(height: 10),
            _buildActions(c, status, channel),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Text('$label $value',
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary)),
    );
  }

  Widget _buildActions(
      Map<String, dynamic> c, String status, String channel) {
    final connected = _isConnected(channel);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status == 'draft')
          _smallButton('Setujui', Icons.verified_rounded, AppTheme.primaryColor,
              () => _approve(c)),
        if (status == 'approved')
          _smallButton('Aktifkan', Icons.play_arrow_rounded,
              AppTheme.successColor, () => _activate(c)),
        if (status == 'active')
          _smallButton('Jeda', Icons.pause_rounded, AppTheme.warningColor,
              () => _pause(c)),
        if (status == 'paused')
          _smallButton('Lanjutkan', Icons.play_arrow_rounded,
              AppTheme.successColor, () => _activate(c)),
        if (status != 'draft')
          _smallButton('Input Hasil', Icons.insights_rounded,
              AppTheme.accentColor, () => _monitor(c)),
        _smallButton('Hapus', Icons.delete_outline_rounded, AppTheme.errorColor,
            () => _delete(c)),
        if (connected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Kanal terhubung',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successColor)),
          ),
      ],
    );
  }

  Widget _smallButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label,
          style: GoogleFonts.inter(fontSize: 12, color: color)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, AppTheme.touchTargetMedium),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
    );
  }
}

num _num(dynamic v) {
  if (v is num) return v;
  if (v == null) return 0;
  return num.tryParse(v.toString()) ?? 0;
}

/// Hitung CTR (%) / CPC (Rp) / ROAS dari input manual / report platform.
Map<String, num> computeAdMetrics(Map<String, dynamic> m) {
  final impressions = _num(m['impressions']);
  final clicks = _num(m['clicks']);
  final spend = _num(m['spend']);
  final revenue = _num(m['revenue']);
  final ctr = impressions > 0 ? (clicks / impressions) * 100 : 0;
  final cpc = clicks > 0 ? spend / clicks : 0;
  final roas = spend > 0 ? revenue / spend : 0;
  return {
    'ctr': double.parse(ctr.toStringAsFixed(2)),
    'cpc': double.parse(cpc.toStringAsFixed(2)),
    'roas': double.parse(roas.toStringAsFixed(2)),
  };
}

class _NewCampaignSheet extends StatefulWidget {
  const _NewCampaignSheet({
    required this.assets,
    required this.channels,
    required this.objectives,
  });

  final List<Map<String, dynamic>> assets;
  final Map<String, String> channels;
  final Map<String, String> objectives;

  @override
  State<_NewCampaignSheet> createState() => _NewCampaignSheetState();
}

class _NewCampaignSheetState extends State<_NewCampaignSheet> {
  String _channel = 'meta';
  String _objective = 'awareness';
  String? _assetId;
  final TextEditingController _budget = TextEditingController(text: '10000');
  double _radius = 5;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + padding),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Buat Kampanye Iklan',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _channel,
              decoration: const InputDecoration(
                  labelText: 'Platform', border: OutlineInputBorder()),
              items: widget.channels.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _channel = v ?? 'meta'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _objective,
              decoration: const InputDecoration(
                  labelText: 'Tujuan', border: OutlineInputBorder()),
              items: widget.objectives.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _objective = v ?? 'awareness'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _assetId,
              decoration: const InputDecoration(
                  labelText: 'Kreatif (aset)', border: OutlineInputBorder()),
              items: widget.assets
                  .map((a) => DropdownMenuItem(
                        value: a['id'].toString(),
                        child: Text(
                          '${(a['title'] ?? '-')} (${(a['kind'] ?? 'copy')})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _assetId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _budget,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Budget harian (Rp)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Text('Radius area toko: ${_radius.toInt()} km',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.textSecondary)),
            Slider(
              value: _radius,
              min: 1,
              max: 30,
              divisions: 29,
              label: '${_radius.toInt()} km',
              onChanged: (v) => setState(() => _radius = v),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event_rounded),
                    label: Text('Mulai ${Formatters.shortDate(_start)}'),
                    onPressed: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text('Selesai ${Formatters.shortDate(_end)}'),
                    onPressed: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Simpan Draf',
              icon: Icons.save_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () {
                final budget = num.tryParse(_budget.text.trim()) ?? 0;
                if (budget <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Isi budget harian dulu.')));
                  return;
                }
                Navigator.pop(context, {
                  'channel': _channel,
                  'objective': _objective,
                  'asset_id': _assetId,
                  'budget_daily': budget,
                  'radius_km': _radius,
                  'start_date': _start,
                  'end_date': _end,
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsSheet extends StatefulWidget {
  const _MetricsSheet({required this.current});

  final Map<String, dynamic> current;

  @override
  State<_MetricsSheet> createState() => _MetricsSheetState();
}

class _MetricsSheetState extends State<_MetricsSheet> {
  late final TextEditingController _impressions;
  late final TextEditingController _clicks;
  late final TextEditingController _spend;
  late final TextEditingController _revenue;

  @override
  void initState() {
    super.initState();
    _impressions = TextEditingController(
        text: widget.current['impressions']?.toString() ?? '');
    _clicks =
        TextEditingController(text: widget.current['clicks']?.toString() ?? '');
    _spend =
        TextEditingController(text: widget.current['spend']?.toString() ?? '');
    _revenue =
        TextEditingController(text: widget.current['revenue']?.toString() ?? '');
  }

  @override
  void dispose() {
    _impressions.dispose();
    _clicks.dispose();
    _spend.dispose();
    _revenue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + padding),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hasil Kampanye',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(
              'Masukkan angka dari laporan platform iklan (atau perkiraan). '
              'CTR/CPC/ROAS dihitung otomatis.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            _field(_impressions, 'Tayangan (impressions)'),
            const SizedBox(height: 10),
            _field(_clicks, 'Klik'),
            const SizedBox(height: 10),
            _field(_spend, 'Belanja iklan (Rp)'),
            const SizedBox(height: 10),
            _field(_revenue, 'Omzet dari iklan (Rp)'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Simpan Hasil',
              icon: Icons.save_rounded,
              onPressed: () {
                Navigator.pop(context, {
                  'impressions': num.tryParse(_impressions.text.trim()) ?? 0,
                  'clicks': num.tryParse(_clicks.text.trim()) ?? 0,
                  'spend': num.tryParse(_spend.text.trim()) ?? 0,
                  'revenue': num.tryParse(_revenue.text.trim()) ?? 0,
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }
}
