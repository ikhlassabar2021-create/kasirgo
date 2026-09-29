import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../services/guide_service.dart';
import '../../widgets/common/centennial_background.dart';

/// Panduan penggunaan aplikasi: PDF (offline-cached) + video YouTube.
/// Konten dikelola superadmin lewat `guide_items` (Control Plane).
class GuideScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  final String? initialQuery;

  const GuideScreen({super.key, this.initialCategory, this.initialQuery});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  final _guide = GuideService();
  final _searchController = TextEditingController();

  List<GuideItem> _all = [];
  bool _loading = true;
  String _query = '';
  String _category = 'semua';
  String _role = 'semua';
  String? _busyId;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) _category = widget.initialCategory!;
    if (widget.initialQuery != null) {
      _query = widget.initialQuery!;
      _searchController.text = widget.initialQuery!;
    }
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    final items = await _guide.loadItems(force: force);
    if (mounted) {
      setState(() {
        _all = items;
        _loading = false;
      });
    }
  }

  List<String> get _categories {
    final set = _all.map((e) => e.category).where((c) => c.isNotEmpty).toSet().toList()
      ..sort();
    return ['semua', ...set];
  }

  List<String> get _roles {
    final set = _all.map((e) => e.role).where((r) => r.isNotEmpty).toSet().toList()
      ..sort();
    return ['semua', ...set];
  }

  List<GuideItem> get _filtered {
    final q = _query.toLowerCase();
    return _all.where((item) {
      final matchQuery = q.isEmpty || item.title.toLowerCase().contains(q);
      final matchCategory = _category == 'semua' || item.category == _category;
      final matchRole = _role == 'semua' ||
          item.role == _role ||
          item.role == 'all' ||
          item.role == 'semua';
      return matchQuery && matchCategory && matchRole;
    }).toList();
  }

  Future<void> _open(GuideItem item) async {
    final url = item.sourceUrl;
    if (url == null || url.isEmpty) {
      _snack('Konten belum tersedia.', AppTheme.warningColor);
      return;
    }

    setState(() => _busyId = item.id);
    try {
      if (item.kind == GuideKind.pdf) {
        final cached = await _guide.cachedPdfPath(item);
        final path = cached ?? await _guide.downloadPdf(item);
        final target = path ?? url;
        final uri = Uri.parse(target.startsWith('http') ? target : 'file://$target');
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok) _snack('Tidak bisa membuka PDF.', AppTheme.errorColor);
      } else {
        final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!ok) _snack('Tidak bisa membuka video.', AppTheme.errorColor);
      }
    } catch (e) {
      _snack('Gagal membuka: $e', AppTheme.errorColor);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Panduan',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : () => _load(force: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: CentennialBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildFilters(),
                  Expanded(
                    child: _filtered.isEmpty ? _buildEmpty() : _buildList(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cari panduan...',
              filled: true,
              fillColor: AppTheme.surfaceColor,
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._categories.map((c) => _chip(
                      label: _categoryLabel(c),
                      selected: _category == c,
                      onTap: () => setState(() => _category = c),
                    )),
                if (_roles.length > 1) const SizedBox(width: 8),
                ..._roles.where((r) => r != 'semua').map((r) => _chip(
                      label: _roleLabel(r),
                      selected: _role == r,
                      onTap: () => setState(() => _role = _role == r ? 'semua' : r),
                      roleChip: true,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool roleChip = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: roleChip
            ? AppTheme.accentColor.withValues(alpha: 0.18)
            : AppTheme.primaryColor.withValues(alpha: 0.15),
        backgroundColor: AppTheme.surfaceColor,
        side: BorderSide(
          color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
        ),
        labelStyle: TextStyle(
          color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  String _categoryLabel(String c) =>
      c == 'semua' ? 'Semua' : c[0].toUpperCase() + c.substring(1);

  String _roleLabel(String r) {
    switch (r.toLowerCase()) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      case 'cashier':
      case 'kasir':
        return 'Kasir';
      case 'customer':
      case 'pelanggan':
        return 'Pelanggan';
      default:
        return r[0].toUpperCase() + r.substring(1);
    }
  }

  Widget _buildEmpty() {
    final hasAny = _all.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 56, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              hasAny ? 'Tidak ada panduan cocok' : 'Belum ada panduan',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              hasAny
                  ? 'Coba ubah kata kunci atau filter.'
                  : 'Panduan akan muncul di sini setelah ditambahkan oleh admin.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _buildCard(_filtered[i]),
      ),
    );
  }

  Widget _buildCard(GuideItem item) {
    final isVideo = item.kind == GuideKind.video;
    final isPdf = item.kind == GuideKind.pdf;
    final busy = _busyId == item.id;

    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: busy ? null : () => _open(item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (isVideo ? AppTheme.errorColor : AppTheme.primaryColor)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isVideo
                      ? Icons.play_circle_fill_rounded
                      : isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.article_rounded,
                  color: isVideo ? AppTheme.errorColor : AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _tag(_categoryLabel(item.category)),
                        const SizedBox(width: 6),
                        _tag(isVideo ? 'Video' : isPdf ? 'PDF' : 'Artikel',
                            color: isVideo ? AppTheme.errorColor : AppTheme.primaryColor),
                        if (item.role != 'all') ...[
                          const SizedBox(width: 6),
                          _tag(_roleLabel(item.role)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              busy
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      isVideo ? Icons.ondemand_video_rounded : Icons.download_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, {Color? color}) {
    final c = color ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c)),
    );
  }
}