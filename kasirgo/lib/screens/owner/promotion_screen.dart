import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/dm_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../utils/wa_helper.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/centennial_background.dart';

class PromotionScreen extends ConsumerStatefulWidget {
  const PromotionScreen({super.key});

  @override
  ConsumerState<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends ConsumerState<PromotionScreen> {
  final DmService _service = DmService();

  bool _loading = true;
  bool _busy = false;

  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _assets = [];
  Map<String, dynamic> _settings = {};
  List<int> _bestHours = [];
  String _modePromo = 'manual';

  static const _channels = <String, String>{
    'wa_status': 'WhatsApp Status',
    'wa_broadcast': 'WA Broadcast',
    'fb': 'Facebook',
    'fb_group': 'Grup Facebook',
    'ig': 'Instagram',
    'tiktok': 'TikTok',
    'shopee': 'Shopee',
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
        _service.listPosts(outletId),
        _service.listAssets(outletId, limit: 60),
        _service.getSettings(outletId),
        _service.suggestBestHours(outletId),
      ]);
      if (!mounted) return;
      setState(() {
        _posts = results[0] as List<Map<String, dynamic>>;
        _assets = results[1] as List<Map<String, dynamic>>;
        _settings = results[2] as Map<String, dynamic>;
        _modePromo = (_settings['mode_promo'] ?? 'manual').toString();
        _bestHours = results[3] as List<int>;
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _saveMode() async {
    final outletId = _outletId;
    if (outletId == null) return;
    try {
      await _service.saveSettings(outletId, {'mode_promo': _modePromo});
      _snack('Pengaturan tim promosi disimpan.');
    } catch (e) {
      _snack('Gagal menyimpan: $e');
    }
  }

  String _captionOf(Map<String, dynamic> post) {
    final c = post['caption']?.toString();
    if (c != null && c.isNotEmpty) return c;
    final asset = post['dm_assets'];
    if (asset is Map) return (asset['title'] ?? '').toString();
    return '';
  }

  Future<void> _addPost() async {
    final outletId = _outletId;
    if (outletId == null) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewPostSheet(
        assets: _assets,
        bestHours: _bestHours,
      ),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      final channel = result['channel'] as String;
      await _service.savePost(
        outletId: outletId,
        channel: channel,
        assetId: result['asset_id'] as String?,
        caption: result['caption'] as String?,
        scheduledAt: result['scheduled_at'] as DateTime?,
        status: channel == 'fb_group' ? 'draft' : 'queued',
      );
      await _load();
    } catch (e) {
      _snack('Gagal menjadwalkan: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _autoSchedule() async {
    final outletId = _outletId;
    if (outletId == null) return;
    final scheduledAssetIds = _posts
        .map((p) => p['asset_id']?.toString())
        .whereType<String>()
        .toSet();
    final pending = _assets.where((a) {
      final id = a['id']?.toString();
      final status = (a['status'] ?? 'draft').toString();
      return id != null &&
          !scheduledAssetIds.contains(id) &&
          (status == 'approved' || status == 'draft');
    }).toList();
    if (pending.isEmpty) {
      _snack('Semua aset sudah punya jadwal.');
      return;
    }
    if (_bestHours.isEmpty) {
      _snack('Belum ada data jam ramai. Tambah jadwal manual dulu ya.');
      return;
    }
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      for (var i = 0; i < pending.length; i++) {
        final hour = _bestHours[i % _bestHours.length];
        var day = now.add(Duration(days: (i ~/ _bestHours.length) + 1));
        final when = DateTime(day.year, day.month, day.day, hour, 0);
        await _service.savePost(
          outletId: outletId,
          channel: 'wa_status',
          assetId: pending[i]['id']?.toString(),
          caption: (pending[i]['caption'] ?? pending[i]['title'] ?? '').toString(),
          scheduledAt: when,
          status: 'queued',
        );
      }
      _snack('${pending.length} konten dijadwalkan otomatis.');
      await _load();
    } catch (e) {
      _snack('Gagal menjadwalkan otomatis: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _markPosted(Map<String, dynamic> post) async {
    try {
      await _service.updatePost(post['id'].toString(), {
        'status': 'posted',
        'posted_at': DateTime.now().toIso8601String(),
        'error': null,
      });
      await _load();
    } catch (e) {
      _snack('Gagal menandai: $e');
    }
  }

  Future<void> _markFailed(Map<String, dynamic> post) async {
    try {
      await _service.updatePost(post['id'].toString(), {
        'status': 'failed',
        'error': 'Ditandai gagal oleh owner',
      });
      await _load();
    } catch (e) {
      _snack('Gagal menandai: $e');
    }
  }

  Future<void> _shift(Map<String, dynamic> post, int days) async {
    final raw = post['scheduled_at']?.toString();
    if (raw == null) return;
    final current = DateTime.tryParse(raw);
    if (current == null) return;
    try {
      await _service.updatePost(post['id'].toString(), {
        'scheduled_at': current.add(Duration(days: days)).toIso8601String(),
      });
      await _load();
    } catch (e) {
      _snack('Gagal menggeser: $e');
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    try {
      await _service.deletePost(post['id'].toString());
      await _load();
    } catch (e) {
      _snack('Gagal menghapus: $e');
    }
  }

  Future<void> _publish(Map<String, dynamic> post) async {
    final channel = (post['channel'] ?? '').toString();
    final caption = _captionOf(post);
    if (channel == 'wa_status' || channel == 'wa_broadcast') {
      await _sendToOwnerWa(caption, channel == 'wa_broadcast');
      return;
    }
    await Clipboard.setData(ClipboardData(text: caption));
    _snack('Caption disalin. Membuka aplikasi kanal...');
    await _openChannel(channel);
  }

  Future<void> _sendToOwnerWa(String message, bool broadcast) async {
    final outletId = _outletId;
    if (outletId == null) return;
    try {
      final outlet = await SupabaseService().getOutlet(outletId);
      final phone = outlet?.phone;
      if (phone == null || phone.isEmpty) {
        _snack('Nomor WA toko belum diatur. Tambahkan di Pengaturan.');
        return;
      }
      final text = broadcast
          ? WaHelper.formatBroadcastPromo(
              storeName: outlet?.businessName ?? 'Toko Kami',
              promoTitle: 'Promo Spesial',
              promoDescription: message,
            )
          : message;
      final ok = await WaHelper.sendWhatsAppMessage(phone: phone, message: text);
      if (!ok) _snack('Tidak bisa membuka WhatsApp.');
    } catch (e) {
      _snack('Gagal membuka WhatsApp: $e');
    }
  }

  Future<void> _openChannel(String channel) async {
    final uri = switch (channel) {
      'fb' || 'fb_group' => Uri.parse('https://facebook.com'),
      'ig' => Uri.parse('https://instagram.com'),
      'tiktok' => Uri.parse('https://tiktok.com'),
      'shopee' => Uri.parse('https://shopee.co.id'),
      _ => Uri.parse('https://wa.me'),
    };
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _snack('Tidak bisa membuka aplikasi kanal.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Studio Promosi',
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
                    _buildSummary(),
                    const SizedBox(height: 12),
                    _buildControls(),
                    const SizedBox(height: 16),
                    ..._buildCalendar(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummary() {
    final posted = _posts.where((p) => p['status'] == 'posted').length;
    final queued = _posts.where((p) => p['status'] == 'queued').length;
    final failed = _posts.where((p) => p['status'] == 'failed').length;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Laporan Posting',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('Sukses', posted, AppTheme.successColor),
              _stat('Terjadwal', queued, AppTheme.primaryColor),
              _stat('Gagal', failed, AppTheme.errorColor),
            ],
          ),
          if (_bestHours.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Jam ramai pelanggan: ${_bestHours.map((h) => '${h.toString().padLeft(2, '0')}:00').join(', ')}',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppTheme.textSecondary)),
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
                  initialValue: _modePromo,
                  decoration: const InputDecoration(
                    labelText: 'Mode tim promosi',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'manual', child: Text('Manual')),
                    DropdownMenuItem(value: 'auto', child: Text('Otomatis')),
                  ],
                  onChanged: (v) => setState(() => _modePromo = v ?? 'manual'),
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
            label: 'Jadwalkan Konten',
            icon: Icons.add_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: _busy ? null : _addPost,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Jadwalkan Otomatis (AI)',
            icon: Icons.auto_awesome_rounded,
            isLoading: _busy,
            onPressed: _busy ? null : _autoSchedule,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCalendar() {
    if (_posts.isEmpty) {
      return [
        AppCard(
          child: Text(
            'Belum ada jadwal konten. Buat konten di Studio Desain lalu jadwalkan di sini.',
            style: GoogleFonts.inter(color: AppTheme.textSecondary),
          ),
        ),
      ];
    }
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final p in _posts) {
      final raw = p['scheduled_at']?.toString();
      final dt = raw == null ? null : DateTime.tryParse(raw);
      final key = dt == null
          ? 'Tanpa jadwal'
          : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(p);
    }
    final keys = groups.keys.toList()..sort();
    final widgets = <Widget>[];
    for (final key in keys) {
      final list = groups[key]!;
      final firstRaw = list.first['scheduled_at']?.toString();
      final firstDt = firstRaw == null ? null : DateTime.tryParse(firstRaw);
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          firstDt == null
              ? key
              : '${Formatters.date(firstDt)} (${_weekday(firstDt.weekday)})',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
      ));
      widgets.addAll(list.map(_buildPostCard));
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  String _weekday(int day) => const [
        'Senin',
        'Selasa',
        'Rabu',
        'Kamis',
        'Jumat',
        'Sabtu',
        'Minggu',
      ][(day - 1).clamp(0, 6)];

  Widget _buildPostCard(Map<String, dynamic> post) {
    final channel = (post['channel'] ?? '').toString();
    final status = (post['status'] ?? 'draft').toString();
    final raw = post['scheduled_at']?.toString();
    final dt = raw == null ? null : DateTime.tryParse(raw);
    final asset = post['dm_assets'];
    final assetTitle = asset is Map ? (asset['title'] ?? '').toString() : '';
    final statusColor = switch (status) {
      'posted' => AppTheme.successColor,
      'failed' => AppTheme.errorColor,
      'queued' => AppTheme.primaryColor,
      _ => AppTheme.textSecondary,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_channelIcon(channel), color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_channels[channel] ?? channel,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status.toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (dt != null)
              Text('${Formatters.date(dt)} - ${Formatters.time(dt)}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary)),
            if (assetTitle.isNotEmpty)
              Text('Aset: $assetTitle',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary)),
            if ((post['caption'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(post['caption'].toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppTheme.textPrimary)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                if (status != 'posted')
                  TextButton.icon(
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 18),
                    label: const Text('Buka & Tandai'),
                    onPressed: () => _publish(post),
                  ),
                if (status == 'queued')
                  TextButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Sukses'),
                    onPressed: () => _markPosted(post),
                  ),
                if (status == 'queued' || status == 'failed')
                  TextButton.icon(
                    icon: const Icon(Icons.report_gmailerrorred_rounded,
                        size: 18),
                    label: const Text('Gagal'),
                    onPressed: () => _markFailed(post),
                  ),
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  tooltip: 'Mundur 1 hari',
                  onPressed: () => _shift(post, -1),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  tooltip: 'Maju 1 hari',
                  onPressed: () => _shift(post, 1),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppTheme.errorColor),
                  tooltip: 'Hapus',
                  onPressed: () => _deletePost(post),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _channelIcon(String channel) => switch (channel) {
        'wa_status' || 'wa_broadcast' => Icons.chat_rounded,
        'fb' || 'fb_group' => Icons.facebook_rounded,
        'ig' => Icons.camera_alt_rounded,
        'tiktok' => Icons.music_note_rounded,
        'shopee' => Icons.shopping_bag_rounded,
        _ => Icons.public_rounded,
      };
}

class _NewPostSheet extends StatefulWidget {
  const _NewPostSheet({required this.assets, required this.bestHours});

  final List<Map<String, dynamic>> assets;
  final List<int> bestHours;

  @override
  State<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<_NewPostSheet> {
  String _channel = 'wa_status';
  String? _assetId;
  final TextEditingController _caption = TextEditingController();
  DateTime _when = DateTime.now().add(const Duration(hours: 1));

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    if (date == null) return;
    setState(() {
      _when = DateTime(date.year, date.month, date.day, _when.hour, 0);
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null) return;
    setState(() {
      _when = DateTime(_when.year, _when.month, _when.day, time.hour, 0);
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
            Text('Jadwalkan Konten',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _channel,
              decoration: const InputDecoration(
                  labelText: 'Kanal', border: OutlineInputBorder()),
              items: _PromotionChannels.all
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _channel = v ?? 'wa_status'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _assetId,
              decoration: const InputDecoration(
                  labelText: 'Aset (opsional)', border: OutlineInputBorder()),
              items: widget.assets
                  .map((a) => DropdownMenuItem(
                        value: a['id'].toString(),
                        child: Text(
                          '${(a['title'] ?? '-')} (${(a['kind'] ?? 'copy')})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _assetId = v;
                  final asset =
                      widget.assets.where((a) => a['id'].toString() == v).firstOrNull;
                  if (asset != null) {
                    final caption = (asset['caption'] ?? '').toString();
                    _caption.text = caption.isEmpty
                        ? (asset['title'] ?? '').toString()
                        : caption;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caption,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Caption', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event_rounded),
                    label: Text(Formatters.date(_when)),
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time_rounded),
                    label: Text(Formatters.time(_when)),
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            if (widget.bestHours.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: widget.bestHours
                    .map((h) => ActionChip(
                          label: Text('${h.toString().padLeft(2, '0')}:00'),
                          onPressed: () => setState(() {
                            _when = DateTime(_when.year, _when.month,
                                _when.day, h, 0);
                          }),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: 'Simpan Jadwal',
              icon: Icons.event_available_rounded,
              onPressed: () => Navigator.pop(context, {
                'channel': _channel,
                'asset_id': _assetId,
                'caption': _caption.text.trim(),
                'scheduled_at': _when,
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromotionChannels {
  static const all = <MapEntry<String, String>>[
    MapEntry('wa_status', 'WhatsApp Status'),
    MapEntry('wa_broadcast', 'WA Broadcast'),
    MapEntry('fb', 'Facebook'),
    MapEntry('fb_group', 'Grup Facebook'),
    MapEntry('ig', 'Instagram'),
    MapEntry('tiktok', 'TikTok'),
    MapEntry('shopee', 'Shopee'),
  ];
}
