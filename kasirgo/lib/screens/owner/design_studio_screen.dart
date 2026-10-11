import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imglib;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
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
  List<Map<String, dynamic>> _cardBlocks = [];
  Map<String, dynamic>? _videoResult;
  Map<String, dynamic>? _generatedImage;
  String? _generatedImageLocalPath;
  String? _videoGifLocalPath;
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
        _cardBlocks = [];
        _generatedImage = null;
        if (video) {
          _videoResult = null;
          _videoGifLocalPath = null;
          for (final b in blocks) {
            if (b is Map && b['type'] == 'video') _videoResult = b.cast<String, dynamic>();
            if (b is Map && b['type'] == 'text') _tips = b['text']?.toString();
            if (b is Map && b['type'] == 'card') _cardBlocks.add(b.cast<String, dynamic>());
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
            if (b is Map && b['type'] == 'image') _generatedImage = b.cast<String, dynamic>();
            if (b is Map && b['type'] == 'card') _cardBlocks.add(b.cast<String, dynamic>());
          }
          if (_copyResults.isEmpty && _generatedImage == null) _snack('Konten belum siap, coba lagi.');
        }
      });
      // Render video scenes as animated GIF
      if (video && _videoResult != null) {
        final rawScenes = (_videoResult!['scenes'] as List?) ?? const [];
        final scenes = rawScenes
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        if (scenes.isNotEmpty) {
          final gifPath = await _renderScenesToGif(
            scenes: scenes,
            title: _videoResult!['title']?.toString() ?? 'Video Promo',
          );
          if (mounted && gifPath != null) setState(() => _videoGifLocalPath = gifPath);
        }
      }
      // Download generated image to local storage
      if (!video && _generatedImage != null) {
        final url = _generatedImage!['image_url']?.toString() ?? '';
        final b64 = _generatedImage!['image_b64']?.toString() ?? '';
        if (url.isNotEmpty || b64.isNotEmpty) {
          final localPath = await _downloadImageToLocal(url: url, b64: b64);
          if (mounted && localPath != null) setState(() => _generatedImageLocalPath = localPath);
        }
      }
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
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Buat Konten',
                icon: Icons.auto_awesome_rounded,
                isLoading: _busy,
                onPressed: _busy ? null : () => _generate(video: false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: 'Buat Gambar AI',
                icon: Icons.image_rounded,
                isLoading: _busy,
                variant: AppButtonVariant.outline,
                onPressed: _busy ? null : _generateImageStandalone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Upload Gambar',
          icon: Icons.upload_rounded,
          isLoading: _busy,
          variant: AppButtonVariant.outline,
          onPressed: _busy ? null : _pickImage,
        ),
        if (_tips != null) ...[
          const SizedBox(height: 16),
          _buildTipsCard(_tips!),
        ],
        if (_cardBlocks.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._cardBlocks.map((b) => _buildCardBlock(b)),
        ],
        if (_generatedImage != null || _generatedImageLocalPath != null) ...[
          const SizedBox(height: 16),
          _buildGeneratedImageCard(),
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
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Buat Naskah Video',
                icon: Icons.movie_creation_rounded,
                isLoading: _busy,
                onPressed: _busy ? null : () => _generate(video: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: 'Upload Video',
                icon: Icons.upload_rounded,
                isLoading: _busy,
                variant: AppButtonVariant.outline,
                onPressed: _busy ? null : _pickVideo,
              ),
            ),
          ],
        ),
        if (_tips != null) ...[
          const SizedBox(height: 16),
          _buildTipsCard(_tips!),
        ],
        if (_cardBlocks.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._cardBlocks.map((b) => _buildCardBlock(b)),
        ],
        if (_videoResult != null || _videoGifLocalPath != null) ...[
          const SizedBox(height: 16),
          _buildVideoResultWithPreview(_videoResult ?? <String, dynamic>{}),
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
        final filePath = a['file_path']?.toString() ?? a['filePath']?.toString() ?? '';
        final thumb = kind == 'image' ? _mediaThumb(filePath) : null;
        return AppCard(
          child: Row(
            children: [
              // Thumbnail for image (video: icon)
              if (thumb != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: thumb,
                )
              else
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
                            fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text('${kind.toUpperCase()} - ${a['status'] ?? 'draft'}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
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

  Widget _buildCardBlock(Map<String, dynamic> block) {
    final tone = (block['tone'] ?? 'info').toString();
    final title = (block['title'] ?? '').toString();
    final body = (block['body'] ?? '').toString();
    final disclaimer = (block['disclaimer'] ?? '').toString();
    final isWarning = tone == 'warning';
    final color = isWarning ? AppTheme.errorColor : AppTheme.warningColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isWarning ? Icons.warning_rounded : Icons.info_rounded,
                    color: color, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(body.isNotEmpty ? body : '-'),
            if (disclaimer.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                disclaimer,
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (picked == null) return;
    try {
      final outletId = _outletId;
      if (outletId == null) return;
      final stored = await _persistPicked(picked, 'img');
      final res = await _service.saveAsset(
        outletId: outletId,
        kind: 'image',
        title: _fileName(picked),
        filePath: stored,
        source: 'upload',
      );
      if (res != null) {
        await _load();
        _snack('Gambar berhasil diupload ke Aset.');
      } else {
        _snack('Gagal menyimpan gambar.');
      }
    } catch (e) {
      _snack('Error upload gambar: $e');
    }
  }

  Future<void> _pickVideo() async {
    final XFile? picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final outletId = _outletId;
      if (outletId == null) return;
      final stored = await _persistPicked(picked, 'vid');
      final res = await _service.saveAsset(
        outletId: outletId,
        kind: 'video',
        title: _fileName(picked),
        filePath: stored,
        source: 'upload',
      );
      if (res != null) {
        await _load();
        _snack('Video berhasil diupload ke Aset.');
      } else {
        _snack('Gagal menyimpan video.');
      }
    } catch (e) {
      _snack('Error upload video: $e');
    }
  }

  String _fileName(XFile picked) {
    final name = picked.name.trim();
    if (name.isNotEmpty) return name;
    final parts = picked.path.split('/');
    return parts.isNotEmpty ? parts.last : 'media';
  }

  /// Simpan berkas terpilih. Di HP: salin ke Documents (path lokal, sesuai
  /// kebijakan foto lokal). Di web (tanpa filesystem): simpan sebagai data URL
  /// base64 di kolom teks `dm_assets.file_path`.
  Future<String> _persistPicked(XFile picked, String prefix) async {
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      final mime = _mimeFor(picked.name.isNotEmpty ? picked.name : picked.path);
      return 'data:$mime;base64,${base64Encode(bytes)}';
    }
    return _copyToDocuments(picked.path, prefix);
  }

  String _mimeFor(String nameOrPath) {
    final lower = nameOrPath.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'application/octet-stream';
  }

  Future<String> _copyToDocuments(String sourcePath, String prefix) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = sourcePath.contains('.') ? '.${sourcePath.split('.').last}' : '';
    final dest = File('${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }

  /// Pratinjau media tersimpan: data URL (web) atau file lokal (HP).
  Widget? _mediaThumb(String stored, {double size = 56}) {
    if (stored.isEmpty) return null;
    if (stored.startsWith('data:')) {
      try {
        final b64 = stored.substring(stored.indexOf(',') + 1);
        return Image.memory(base64Decode(b64),
            width: size, height: size, fit: BoxFit.cover);
      } catch (_) {
        return null;
      }
    }
    if (!kIsWeb && File(stored).existsSync()) {
      return Image.file(File(stored), width: size, height: size, fit: BoxFit.cover);
    }
    return null;
  }

  Future<String?> _downloadImageToLocal({String url = '', String b64 = ''}) async {
    try {
      Uint8List bytes;
      if (b64.isNotEmpty) {
        bytes = base64Decode(b64);
      } else if (url.isNotEmpty) {
        final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
        if (resp.statusCode != 200) return null;
        bytes = resp.bodyBytes;
      } else {
        return null;
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/dm_ai_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _renderScenesToGif({
    required List<Map<String, dynamic>> scenes,
    required String title,
  }) async {
    try {
      const width = 360;
      const height = 640;
      final frames = <imglib.Image>[];
      for (int i = 0; i < scenes.length && i < 6; i++) {
        final text = scenes[i]['text']?.toString() ?? '';
        final frame = imglib.Image(width: width, height: height);
        // Gradient background: primary blue -> darker
        for (int y = 0; y < height; y++) {
          final t = y / height;
          final r = (2 + (10 - 2) * t).toInt().clamp(0, 255);
          final g = (132 + (160 - 132) * t).toInt().clamp(0, 255);
          final b = (199 + (212 - 199) * t).toInt().clamp(0, 255);
          for (int x = 0; x < width; x++) {
            frame.setPixel(x, y, imglib.ColorRgb8(r, g, b));
          }
        }
        // Scene number badge
        imglib.drawString(frame, 'Scene ${i + 1}/${scenes.length}',
            font: imglib.arial14, x: 16, y: 30,
            color: imglib.ColorRgb8(200, 230, 255));
        // Scene text (word wrap)
        final lines = _wrapText(text, 28);
        int ty = (height ~/ 3).clamp(0, height - 100);
        for (final line in lines.take(6)) {
          imglib.drawString(frame, line, font: imglib.arial24,
              x: 24, y: ty, color: imglib.ColorRgb8(255, 255, 255));
          ty += 32;
        }
        // Title at bottom
        imglib.drawString(frame, title.substring(0, title.length.clamp(0, 30)),
            font: imglib.arial14, x: 16, y: height - 40,
            color: imglib.ColorRgb8(200, 230, 255));
        frames.add(frame);
      }
      if (frames.isEmpty) return null;
      final encoder = imglib.GifEncoder();
      for (final frame in frames) {
        encoder.addFrame(frame, duration: 1000);
      }
      final gifBytes = encoder.finish();
      if (gifBytes == null || gifBytes.isEmpty) return null;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/dm_video_${DateTime.now().millisecondsSinceEpoch}.gif');
      await file.writeAsBytes(gifBytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  List<String> _wrapText(String text, int maxChars) {
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    String current = '';
    for (final w in words) {
      if ('$current $w'.trim().length > maxChars) {
        if (current.isNotEmpty) lines.add(current.trim());
        current = w;
      } else {
        current = current.isEmpty ? w : '$current $w';
      }
    }
    if (current.isNotEmpty) lines.add(current.trim());
    return lines;
  }

  Future<void> _generateImageStandalone() async {
    final outletId = _outletId;
    if (outletId == null) return;
    final brief = _brief.text.trim();
    if (brief.isEmpty) {
      _snack('Tulis dulu brief promosi kamu ya.');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await _service.generateImage(outletId: outletId, brief: brief);
      if (!mounted) return;
      final blocks = (res['blocks'] as List?) ?? const [];
      setState(() {
        _tips = null;
        _cardBlocks = [];
        _generatedImage = null;
        for (final b in blocks) {
          if (b is Map && b['type'] == 'image') _generatedImage = b.cast<String, dynamic>();
          if (b is Map && b['type'] == 'card') _cardBlocks.add(b.cast<String, dynamic>());
        }
      });
      if (_generatedImage != null) {
        final url = _generatedImage!['image_url']?.toString() ?? '';
        final b64 = _generatedImage!['image_b64']?.toString() ?? '';
        if (url.isNotEmpty || b64.isNotEmpty) {
          final localPath = await _downloadImageToLocal(url: url, b64: b64);
          if (mounted && localPath != null) setState(() => _generatedImageLocalPath = localPath);
        }
      } else if (_cardBlocks.isEmpty) {
        _snack('Gambar belum siap, coba lagi.');
      }
      await _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _busy = false);
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

  Widget _buildGeneratedImageCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Gambar AI',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Generate ulang',
                onPressed: _busy ? null : _generateImageStandalone,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: _generatedImageLocalPath != null && !kIsWeb && File(_generatedImageLocalPath!).existsSync()
                ? Image.file(File(_generatedImageLocalPath!),
                    width: double.infinity, height: 240, fit: BoxFit.cover)
                : (_generatedImage?['image_b64']?.toString().isNotEmpty ?? false)
                    ? Image.memory(
                        base64Decode(_generatedImage!['image_b64'].toString()),
                        width: double.infinity, height: 240, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _imagePlaceholder())
                    : _generatedImage?['image_url'] != null &&
                            _generatedImage!['image_url'].toString().isNotEmpty
                        ? Image.network(_generatedImage!['image_url'].toString(),
                            width: double.infinity, height: 240, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _imagePlaceholder())
                        : _imagePlaceholder(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _generatedImage?['title']?.toString() ?? 'Gambar AI',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
              if (_generatedImageLocalPath != null ||
                  (_generatedImage?['image_b64']?.toString().isNotEmpty ?? false) ||
                  (_generatedImage?['image_url']?.toString().isNotEmpty ?? false))
                IconButton(
                  icon: const Icon(Icons.save_rounded, size: 20, color: AppTheme.primaryColor),
                  tooltip: 'Simpan ke Aset',
                  onPressed: () => _saveGeneratedImage(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 240,
      color: AppTheme.primaryColor.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(Icons.image_rounded, size: 56, color: AppTheme.primaryColor),
      ),
    );
  }

  Future<void> _saveGeneratedImage() async {
    final outletId = _outletId;
    if (outletId == null) return;
    String? stored = _generatedImageLocalPath;
    if (stored == null) {
      final b64 = _generatedImage?['image_b64']?.toString() ?? '';
      final url = _generatedImage?['image_url']?.toString() ?? '';
      if (b64.isNotEmpty) {
        stored = 'data:image/png;base64,$b64';
      } else if (url.isNotEmpty) {
        stored = url;
      }
    }
    if (stored == null || stored.isEmpty) return;
    try {
      final res = await _service.saveAsset(
        outletId: outletId,
        kind: 'image',
        title: _generatedImage?['title']?.toString() ?? 'Gambar AI',
        filePath: stored,
        source: 'ai_generated',
      );
      if (res != null) {
        _snack('Gambar disimpan ke Aset.');
        await _load();
      }
    } catch (e) {
      _snack('Gagal menyimpan: $e');
    }
  }

  Widget _buildVideoResultWithPreview(Map<String, dynamic> v) {
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
                        fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Animated GIF preview from scenes
          if (_videoGifLocalPath != null && !kIsWeb && File(_videoGifLocalPath!).existsSync()) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Image.file(
                File(_videoGifLocalPath!),
                width: double.infinity,
                height: 320,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(height: 4),
            Text('Pratinjau animasi dari naskah scene (tersimpan lokal)',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
          ],
          Text(
            '${v['duration'] ?? _duration} detik - musik: ${v['music'] ?? '-'}',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          // Scene list
          ...((v['scenes'] as List?) ?? const []).asMap().entries.map((e) {
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
                            fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${s['text'] ?? ''} (${s['duration'] ?? 4} dtk)',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
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
                    fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text(v['voiceover'].toString(),
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary)),
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
