import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/business_doctor_service.dart';
import '../../utils/error_messages.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/centennial_background.dart';

/// "Kamera Klinis" - pemeriksaan visual toko ala cek fisik Dokter Bisnis.
///
/// Foto HANYA tersimpan lokal di HP (tidak diunggah). Yang dikirim ke server
/// hanyalah skor hasil rating 1-5 tiap aspek. Skor & XP dihitung di server
/// (RPC doctor_save_vitals) sehingga tidak bisa diakali dari klien.
class DoctorVitalsScreen extends ConsumerStatefulWidget {
  const DoctorVitalsScreen({super.key, this.service});

  final BusinessDoctorService? service;

  @override
  ConsumerState<DoctorVitalsScreen> createState() => _DoctorVitalsScreenState();
}

class _DoctorVitalsScreenState extends ConsumerState<DoctorVitalsScreen> {
  final _notes = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _aktif = true;
  List<Map<String, dynamic>> _aspects = const [];
  final Map<String, int> _ratings = {};
  List<Map<String, dynamic>> _history = const [];

  XFile? _photo;
  Uint8List? _photoBytes;

  BusinessDoctorService get _svc => widget.service ?? BusinessDoctorService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cfg = await _svc.getKameraKlinisConfig();
      final aspek = (cfg['aspek'] as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      if (!mounted) return;
      setState(() {
        _aktif = cfg['aktif'] != false;
        _aspects = aspek;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aspects = const [
          {'key': 'fisik', 'label': 'Kondisi Fisik Toko'},
          {'key': 'tampilan', 'label': 'Tampilan & Kerapian'},
          {'key': 'perilaku', 'label': 'Perilaku Pelayanan'},
        ];
        _loading = false;
      });
    }
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    try {
      final h = await _svc.getVitalsHistory(outletId);
      if (!mounted) return;
      setState(() => _history = h);
    } catch (_) {}
  }

  Future<void> _pickPhoto() async {
    ImageSource? source;
    if (kIsWeb) {
      source = ImageSource.gallery;
    } else {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded,
                    color: AppTheme.primaryColor),
                title: const Text('Ambil Foto Sekarang'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppTheme.primaryColor),
                title: const Text('Pilih dari Galeri'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }
    if (source == null) return;
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = image;
        _photoBytes = bytes;
      });
    } catch (e) {
      if (mounted) _snack(friendlyError(e, fallback: 'Gagal mengambil foto.'));
    }
  }

  bool get _allRated => _aspects.isNotEmpty &&
      _aspects.every((a) => (_ratings[a['key']] ?? 0) > 0);

  int get _average {
    if (_aspects.isEmpty) return 0;
    final total = _aspects.fold<int>(0, (s, a) => s + (_ratings[a['key']] ?? 0));
    return (total / _aspects.length).round();
  }

  Future<void> _save() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    if (!_allRated) {
      _snack('Beri penilaian untuk semua aspek dulu ya.');
      return;
    }
    setState(() => _saving = true);
    try {
      final aspects = [
        for (final a in _aspects)
          {
            'key': a['key'],
            'label': a['label'],
            'rating': _ratings[a['key']] ?? 0,
          },
      ];
      final res = await _svc.saveVitals(
        outletId: outletId,
        aspects: aspects,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(friendlyError(e, fallback: 'Gagal menyimpan pemeriksaan.'));
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Kamera Klinis',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: CentennialBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppTheme.formMaxWidth),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildIntro(),
                      const SizedBox(height: 16),
                      _buildPhotoCard(),
                      const SizedBox(height: 20),
                      Text('Nilai kondisi toko (1 = buruk, 5 = bagus)',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      for (final a in _aspects) ...[
                        _buildAspectRow(a),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: _notes,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Catatan (opsional)',
                          hintText: 'Misal: rak depan perlu dirapikan',
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_allRated) _buildScorePreview(),
                      if (_allRated) const SizedBox(height: 16),
                      AppButton(
                        label: 'Simpan Pemeriksaan',
                        icon: Icons.medical_services_rounded,
                        isLoading: _saving,
                        onPressed: (_saving || !_allRated) ? null : _save,
                      ),
                      if (!_aktif) ...[
                        const SizedBox(height: 10),
                        Text('Fitur Kamera Klinis sedang dinonaktifkan admin.',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text('Riwayat Pemeriksaan',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        for (final h in _history.take(10))
                          _buildHistoryRow(h),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.visibility_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Foto toko hanya disimpan di HP Anda (tidak diunggah). '
              'Yang dikirim ke sistem hanya penilaian kondisi, untuk memantau '
              'kesehatan usaha dari waktu ke waktu.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5, color: AppTheme.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_photoBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Image.memory(
              _photoBytes!,
              height: 190,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        if (_photoBytes != null) const SizedBox(height: 10),
        SizedBox(
          height: AppTheme.touchTargetMedium,
          child: AppButton(
            label: _photo == null ? 'Ambil / Pilih Foto Toko' : 'Ganti Foto',
            icon: Icons.photo_camera_rounded,
            variant: AppButtonVariant.outline,
            onPressed: _pickPhoto,
          ),
        ),
      ],
    );
  }

  Widget _buildAspectRow(Map<String, dynamic> aspect) {
    final key = aspect['key']?.toString() ?? '';
    final label = aspect['label']?.toString() ?? key;
    final value = _ratings[key] ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 5 ? 6 : 0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _ratings[key] = i),
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i <= value
                              ? AppTheme.primaryColor.withValues(alpha: 0.12)
                              : AppTheme.surfaceMutedColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: i <= value
                                ? AppTheme.primaryColor
                                : AppTheme.borderColor,
                          ),
                        ),
                        child: Text('$i',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: i <= value
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary,
                            )),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScorePreview() {
    final score = (_average / 5 * 100).round();
    final color = score >= 75
        ? AppTheme.successColor
        : score >= 50
            ? AppTheme.warningColor
            : AppTheme.errorColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Perkiraan Skor Kesehatan: $score/100',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> h) {
    final score = int.tryParse(h['score']?.toString() ?? '') ?? 0;
    final color = score >= 75
        ? AppTheme.successColor
        : score >= 50
            ? AppTheme.warningColor
            : AppTheme.errorColor;
    final created = DateTime.tryParse(h['created_at']?.toString() ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Text('$score',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              created != null ? Formatters.dateTime(created) : '-',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
