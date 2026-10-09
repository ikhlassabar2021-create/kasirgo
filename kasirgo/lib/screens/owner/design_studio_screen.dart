import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/dm_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/centennial_background.dart';

/// ST16-2 (13.28): Studio Desain - Team Desain AI.
/// Brief -> 3 opsi copy + preview gambar produk; naskah video 15-30 detik.
class DesignStudioScreen extends ConsumerStatefulWidget {
  const DesignStudioScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<DesignStudioScreen> createState() => _DesignStudioScreenState();
}

class _DesignStudioScreenState extends ConsumerState<DesignStudioScreen>
    with SingleTickerProviderStateMixin {
  final DmService _service = DmService();
  late final TabController _tabs = TabController(
      length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));

  bool _loading = true;
  bool _busy = false;

  final TextEditingController _brief = TextEditingController();
  final TextEditingController _goal = TextEditingController();
  String _tone = 'ramah';
  int _duration = 20;
  final Set<String> _selectedProducts = {};

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _assets = [];
  List<Map<String, dynamic>> _copyResults = [];
  Map<String, dynamic>? _videoResult;
  String? _tips;

  Map<String, dynamic> _settings = {};
  String _modeDesign = 'manual';

  static const _tones = ['ramah', 'semangat', 'elegan', 'lucu', 'tegas'];

  String? get _outletId {
    final id = ref.read(currentUserProvider)?.outletId;
    return (id == null || id.isEmpty) ? null : id;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _brief.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final outletId = _outletId;
    if (outletId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _service.getProducts(outletId),
        _service.listAssets(outletId),
        _service.getSettings(outletId),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<Map<String, dynamic>>;
        _assets = results[1] as List<Map<String, dynamic>>;
        _settings = results[2] as Map<String, dynamic>;
        _modeDesign = (_settings['mode_design'] ?? 'manual').toString();
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _generate({required bool video}) async {
    final outletId = _outletId;
    if (outletId == null) return;
    final brief = _brief.text.trim();
    if (brief.isEmpty) {
      _snack('Tulis dulu brief promosi kamu ya.');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = video
          ? await _service.generateVideo(
              outletId: outletId,
              brief: brief,
              tone: _tone,
              goal: _goal.text.trim(),
              duration: _duration,
              productIds: _selectedProducts.toList(),
            )
          : await _service.generateCopy(
              outletId: outletId,
              brief: brief,
              tone: _tone,
              goal: _goal.text.trim(),
              productIds: _selectedProducts.toList(),
            );
      if (!mounted) return;
      final blocks = (res['blocks'] as List?) ?? const [];
      setState(() {
        _tips = null;
        if (video) {
          _videoResult = null;
          for (final b in blocks) {
            if (b is Map && b['type'] == 'video') _videoResult = b.cast<String, dynamic>();
            if (b is Map && b['type'] == 'text') _tips = b['text']?.toString();
          }
          if (_videoResult == null) _snack('Naskah video belum siap, coba lagi.');
        } else {
          _copyResults = [];
          for (final b in blocks) {
            if (b is Map && b['type'] == 'text') _tips = b['text']?.toString();
            if (b is Map && b['type'] == 'assets') {
              final items = (b['items'] as List?) ?? const [];
              _copyResults =
                  items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
            }
          }
          if (_copyResults.isEmpty) _snack('Konten belum siap, coba lagi.');
        }
      });
      await _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _saveCopy(int index) async {
    final item = _copyResults[index];
    final id = item['id']?.toString();
    if (id == null) return;
    try {
      await _service.updateAsset(id, {
        'title': item['title']?.toString() ?? 'Konten Promosi',
        'caption': item['caption']?.toString() ?? '',
        'hashtags': item['hashtags']?.toString() ?? '',
        'status': 'approved',
      });
      _snack('Konten disimpan ke Aset.');
      await _load();
    } catch (e) {
      _snack('Gagal menyimpan: $e');
    }
  }

  Future<void> _saveVideo() async {
    final v = _videoResult;
    if (v == null) return;
    final id = v['asset_id']?.toString();
    if (id == null) {
      _snack('Aset video tidak ditemukan.');
      return;
    }
    try {
      await _service.updateAsset(id, {'status': 'approved'});
      _snack('Naskah video disimpan ke Aset.');
      await _load();
    } catch (e) {
      _snack('Gagal menyimpan: $e');
    }
  }

  Future<void> _deleteAsset(String id) async {
    try {
      await _service.deleteAsset(id);
      await _load();
    } catch (e) {
      _snack('Gagal menghapus: $e');
    }
  }

  Future<void> _saveModes() async {
    final outletId = _outletId;
    if (outletId == null) return;
    try {
      await _service.saveSettings(outletId, {'mode_design': _modeDesign});
      _snack('Pengaturan tim disimpan.');
    } catch (e) {
      _snack('Gagal menyimpan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Studio Desain',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primaryColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Copy & Gambar'),
            Tab(text: 'Video'),
            Tab(text: 'Aset'),
          ],
        ),
      ),
      body: CentennialBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabs,
                children: [_buildCopyTab(), _buildVideoTab(), _buildAssetsTab()],
              ),
      ),
    );
  }

  Widget _buildCopyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBriefForm(),
        const SizedBox(height: 16),
        AppButton(
          label: 'Buat Konten',
          icon: Icons.auto_awesome_rounded,
          isLoading: _busy,
          onPressed: _busy ? null : () => _generate(video: false),
        ),
        if (_tips != null) ...[
          const SizedBox(height: 16),
          _buildTipsCard(_tips!),
        ],
        const SizedBox(height: 16),
        ..._copyResults.asMap().entries.map(
              (e) => _buildCopyResult(e.key, e.value),
            ),
      ],
    );
  }

  Widget _buildVideoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBriefForm(showProducts: false),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Durasi video: $_duration detik',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              Slider(
                value: _duration.toDouble(),
                min: 15,
                max: 30,
                divisions: 3,
                label: '$_duration dtk',
                activeColor: AppTheme.primaryColor,
                onChanged: (v) => setState(() => _duration = v.round()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Buat Naskah Video',
          icon: Icons.movie_creation_rounded,
          isLoading: _busy,
          onPressed: _busy ? null : () => _generate(video: true),
        ),
        if (_tips != null) ...[
          const SizedBox(height: 16),
          _buildTipsCard(_tips!),
        ],
        if (_videoResult != null) ...[
          const SizedBox(height: 16),
          _buildVideoResult(_videoResult!),
        ],
      ],
    );
  }

  Widget _buildAssetsTab() {
    if (_assets.isEmpty) {
      return const Center(child: Text('Belum ada aset tersimpan.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _assets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final a = _assets[i];
        final kind = (a['kind'] ?? 'copy').toString();
        final icon = kind == 'video'
            ? Icons.movie_rounded
            : kind == 'image'
                ? Icons.image_rounded
                : Icons.notes_rounded;
        return AppCard(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Icon(icon, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['title']?.toString() ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text('${kind.toUpperCase()} - ${a['status'] ?? 'draft'}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.errorColor),
                onPressed: () => _deleteAsset(a['id'].toString()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBriefForm({bool showProducts = true}) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Brief promosi',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _brief,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Contoh: promo akhir bulan, diskon kopi susu...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _goal,
            decoration: const InputDecoration(
              labelText: 'Tujuan (opsional)',
              hintText: 'Contoh: tambah pelanggan baru',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text('Gaya bahasa',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: _tones
                .map((t) => ChoiceChip(
                      label: Text(t),
                      selected: _tone == t,
                      onSelected: (_) => setState(() => _tone = t),
                    ))
                .toList(),
          ),
          if (showProducts) ...[
            const SizedBox(height: 12),
            Text('Produk (opsional)',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            if (_products.isEmpty)
              Text('Belum ada produk.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary))
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _products.take(12).map((p) {
                  final id = p['id'].toString();
                  final selected = _selectedProducts.contains(id);
                  return FilterChip(
                    label: Text(p['name']?.toString() ?? '-'),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedProducts.add(id);
                      } else {
                        _selectedProducts.remove(id);
                      }
                    }),
                  );
                }).toList(),
              ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _modeDesign,
                  decoration: const InputDecoration(
                    labelText: 'Mode tim desain',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'manual', child: Text('Manual')),
                    DropdownMenuItem(value: 'auto', child: Text('Otomatis')),
                  ],
                  onChanged: (v) => setState(() => _modeDesign = v ?? 'manual'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.save_rounded),
                tooltip: 'Simpan pengaturan',
                onPressed: _saveModes,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard(String tips) {
    return AppCard(
      color: AppTheme.accentColor.withValues(alpha: 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, color: AppTheme.accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tips,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyResult(int index, Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePreview(index, item),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: item['title']?.toString() ?? '',
              decoration: const InputDecoration(
                  labelText: 'Judul', border: OutlineInputBorder()),
              onChanged: (v) => item['title'] = v,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item['caption']?.toString() ?? '',
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Caption', border: OutlineInputBorder()),
              onChanged: (v) => item['caption'] = v,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item['hashtags']?.toString() ?? '',
              decoration: const InputDecoration(
                  labelText: 'Hashtag', border: OutlineInputBorder()),
              onChanged: (v) => item['hashtags'] = v,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Simpan Konten',
              icon: Icons.save_rounded,
              height: AppTheme.touchTargetMedium,
              onPressed: () => _saveCopy(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(int index, Map<String, dynamic> item) {
    final product = _selectedProducts.isEmpty
        ? (_products.isNotEmpty ? _products.first : null)
        : _products.firstWhere(
            (p) => _selectedProducts.contains(p['id'].toString()),
            orElse: () => _products.isNotEmpty
                ? _products.first
                : <String, dynamic>{},
          );
    final name = product?['name']?.toString() ?? item['title']?.toString() ?? 'Promo';
    final price = (product?['base_price'] as num?)?.toDouble() ?? 0;
    final imagePath = product?['image_local_path']?.toString();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        height: 180,
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imagePath != null && !kIsWeb && File(imagePath).existsSync())
              Image.file(File(imagePath), fit: BoxFit.cover)
            else
              const Center(
                child: Icon(Icons.image_rounded,
                    size: 56, color: Colors.white24),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  if (price > 0)
                    Text(Formatters.currency(price),
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoResult(Map<String, dynamic> v) {
    final scenes = (v['scenes'] as List?) ?? const [];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.movie_rounded, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(v['title']?.toString() ?? 'Video Promo',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${v['duration'] ?? _duration} detik - musik: ${v['music'] ?? '-'}',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          ...scenes.asMap().entries.map((e) {
            final s = e.value is Map ? (e.value as Map) : const {};
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppTheme.accentColor,
                    child: Text('${e.key + 1}',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${s['text'] ?? ''} (${s['duration'] ?? 4} dtk)',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            );
          }),
          if ((v['voiceover']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Voice over',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text(v['voiceover'].toString(),
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.textPrimary)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Regenerate',
                  icon: Icons.refresh_rounded,
                  variant: AppButtonVariant.outline,
                  height: AppTheme.touchTargetMedium,
                  onPressed: _busy ? null : () => _generate(video: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Simpan',
                  icon: Icons.save_rounded,
                  height: AppTheme.touchTargetMedium,
                  onPressed: _saveVideo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
