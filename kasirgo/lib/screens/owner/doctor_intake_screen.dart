import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/business_doctor_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/centennial_background.dart';
import '../../utils/error_messages.dart';

class DoctorIntakeScreen extends ConsumerStatefulWidget {
  const DoctorIntakeScreen({super.key, this.service});

  final BusinessDoctorService? service;

  @override
  ConsumerState<DoctorIntakeScreen> createState() =>
      _DoctorIntakeScreenState();
}

class _Opt {
  final String value;
  final String label;
  final IconData icon;
  const _Opt(this.value, this.label, this.icon);
}

class _Step {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<({String key, String question, List<_Opt> options})> groups;
  const _Step({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.groups,
  });
}

const _steps = <_Step>[
  _Step(
    title: 'Kondisi Fisik Toko',
    subtitle: 'Lihat toko Anda hari-hari ini.',
    icon: Icons.storefront_rounded,
    groups: [
      (
        key: 'keramaian',
        question: 'Bagaimana ramainya pembeli?',
        options: [
          _Opt('ramai', 'Ramai terus', Icons.groups_rounded),
          _Opt('sedang', 'Sedang saja', Icons.people_alt_rounded),
          _Opt('sepi', 'Sering sepi', Icons.person_rounded),
        ],
      ),
      (
        key: 'kerapian',
        question: 'Bagaimana kerapian barang?',
        options: [
          _Opt('rapi', 'Rapi & teratur', Icons.cleaning_services_rounded),
          _Opt('biasa', 'Biasa saja', Icons.dashboard_customize_rounded),
          _Opt('berantakan', 'Kurang rapi', Icons.inventory_rounded),
        ],
      ),
      (
        key: 'stok_menumpuk',
        question: 'Ada stok menumpuk / lama tak laku?',
        options: [
          _Opt('ya', 'Ada', Icons.inventory_2_rounded),
          _Opt('tidak', 'Tidak ada', Icons.check_circle_rounded),
        ],
      ),
    ],
  ),
  _Step(
    title: 'Tampilan Toko',
    subtitle: 'Penilaian Anda sendiri sudah cukup.',
    icon: Icons.visibility_rounded,
    groups: [
      (
        key: 'tampilan',
        question: 'Menurut Anda, tampilan toko?',
        options: [
          _Opt('menarik', 'Menarik', Icons.thumb_up_rounded),
          _Opt('biasa', 'Biasa saja', Icons.thumbs_up_down_rounded),
          _Opt('kurang', 'Kurang menarik', Icons.thumb_down_rounded),
        ],
      ),
      (
        key: 'papan_nama',
        question: 'Papan nama / spanduk terlihat jelas?',
        options: [
          _Opt('jelas', 'Jelas', Icons.store_mall_directory_rounded),
          _Opt('kurang', 'Kurang jelas', Icons.visibility_off_rounded),
        ],
      ),
    ],
  ),
  _Step(
    title: 'Perilaku Pelanggan',
    subtitle: 'Sedikit lagi selesai.',
    icon: Icons.people_rounded,
    groups: [
      (
        key: 'pelanggan',
        question: 'Pelanggan Anda kebanyakan?',
        options: [
          _Opt('langganan', 'Langganan tetap', Icons.repeat_rounded),
          _Opt('campur', 'Campur', Icons.shuffle_rounded),
          _Opt('baru', 'Kebanyakan baru', Icons.person_add_rounded),
        ],
      ),
      (
        key: 'promosi',
        question: 'Sudah pernah promosi?',
        options: [
          _Opt('belum', 'Belum pernah', Icons.campaign_outlined),
          _Opt('pernah', 'Sudah pernah', Icons.campaign_rounded),
        ],
      ),
    ],
  ),
];

class _PhotoRef {
  final String kind;
  final String label;
  final String name;
  final Uint8List bytes;
  const _PhotoRef({
    required this.kind,
    required this.label,
    required this.name,
    required this.bytes,
  });
}

class _DoctorIntakeScreenState extends ConsumerState<DoctorIntakeScreen> {
  final _answers = <String, String>{};
  final _notes = TextEditingController();
  final _photos = <_PhotoRef>[];
  int _step = 0;
  bool _saving = false;
  bool _pickingPhoto = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  bool get _stepComplete => _steps[_step]
      .groups
      .every((g) => (_answers[g.key] ?? '').isNotEmpty);

  Future<void> _next() async {
    if (!_stepComplete) return;
    if (_step < _steps.length - 1) {
      setState(() => _step++);
      return;
    }
    await _submit();
  }

  Future<void> _addPhoto(String kind, String label) async {
    if (_pickingPhoto) return;
    final source = await showModalBottomSheet<ImageSource>(
      useSafeArea: true,
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
    if (source == null) return;
    setState(() => _pickingPhoto = true);
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
        _photos.add(_PhotoRef(
          kind: kind,
          label: label,
          name: image.name,
          bytes: bytes,
        ));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e, fallback: 'Gagal mengambil foto.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  List<Map<String, dynamic>> get _visualRefs => [
        for (final p in _photos)
          {
            'kind': p.kind,
            'label': p.label,
            'file_name': p.name,
            'captured_at': DateTime.now().toIso8601String(),
            'storage': 'local_only',
          },
      ];

  Future<void> _submit() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    setState(() => _saving = true);
    final physical = <String, dynamic>{
      for (final g in _steps[0].groups) g.key: _answers[g.key],
      for (final g in _steps[1].groups) g.key: _answers[g.key],
    };
    final behavior = <String, dynamic>{
      for (final g in _steps[2].groups) g.key: _answers[g.key],
    };
    try {
      await (widget.service ?? BusinessDoctorService()).saveIntake(
        outletId: outletId,
        physical: physical,
        visualNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        behavior: behavior,
        visualRefs: _visualRefs,
      );
      if (!mounted) return;
      Navigator.pop(context, _summary());
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: 'Gagal menyimpan. Silakan coba lagi.'))),
      );
    }
  }

  String _summary() {
    String label(String groupKey) {
      for (final s in _steps) {
        for (final g in s.groups) {
          if (g.key == groupKey) {
            for (final o in g.options) {
              if (o.value == _answers[groupKey]) return o.label;
            }
          }
        }
      }
      return _answers[groupKey] ?? '-';
    }

    final lines = <String>[
      'Cek Fisik Toko (hasil observasi pemilik):',
      '- Keramaian pembeli: ${label('keramaian')}',
      '- Kerapian barang: ${label('kerapian')}',
      '- Stok menumpuk: ${label('stok_menumpuk')}',
      '- Tampilan toko: ${label('tampilan')}',
      '- Papan nama: ${label('papan_nama')}',
      '- Pelanggan: ${label('pelanggan')}',
      '- Riwayat promosi: ${label('promosi')}',
      if (_notes.text.trim().isNotEmpty) '- Catatan pemilik: ${_notes.text.trim()}',
      '',
      'Lakukan diagnosa berdasarkan data aplikasi dan cek fisik ini. '
          'Sebutkan masalah utama, skor kesehatan usaha, dan 3 langkah perbaikan paling mudah.',
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Cek Fisik Toko',
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(step.icon, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text('Langkah ${_step + 1} dari ${_steps.length}',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (_step + 1) / _steps.length,
                          minHeight: 6,
                          backgroundColor: AppTheme.borderColor,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(step.title,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(step.subtitle,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      for (final g in step.groups) ...[
                        _buildGroup(g),
                        const SizedBox(height: 20),
                      ],
                      if (_step == 1) ...[
                        _buildPhotoSection(),
                        const SizedBox(height: 20),
                        _buildNotes(),
                      ],
                    ],
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroup(
      ({String key, String question, List<_Opt> options}) group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(group.question,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final o in group.options)
              _buildChoice(o, _answers[group.key] == o.value,
                  () => setState(() => _answers[group.key] = o.value)),
          ],
        ),
      ],
    );
  }

  Widget _buildChoice(_Opt o, bool selected, VoidCallback onTap) {
    final color = selected ? AppTheme.primaryColor : AppTheme.borderColor;
    return Material(
      color: selected
          ? AppTheme.primaryColor.withValues(alpha: 0.08)
          : AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: onTap,
        child: Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: color, width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(o.icon,
                  size: 24,
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary),
              const SizedBox(height: 8),
              Text(o.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimary,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Foto klinis (opsional)',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Foto etalase & nota belanja harian membantu dokter menilai '
          'tampilan dan harga kulakan. Foto tetap di HP Anda.',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _photoButton(
              icon: Icons.storefront_rounded,
              label: 'Foto Etalase',
              kind: 'etalase',
            ),
            _photoButton(
              icon: Icons.receipt_long_rounded,
              label: 'Foto Nota Belanja',
              kind: 'nota_belanja',
            ),
          ],
        ),
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _photos.length; i++)
                _photoThumb(_photos[i], i),
            ],
          ),
        ],
      ],
    );
  }

  Widget _photoButton({
    required IconData icon,
    required String label,
    required String kind,
  }) {
    return OutlinedButton.icon(
      onPressed:
          _pickingPhoto ? null : () => _addPhoto(kind, label),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryColor,
        side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
        minimumSize: const Size(0, AppTheme.touchTargetMedium),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
      ),
    );
  }

  Widget _photoThumb(_PhotoRef photo, int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Image.memory(
            photo.bytes,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 84,
              height: 84,
              color: AppTheme.surfaceMutedColor,
              child: const Icon(Icons.broken_image_outlined,
                  color: AppTheme.textSecondary),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: InkWell(
            onTap: () => setState(() => _photos.removeAt(index)),
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppTheme.errorColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Catatan tambahan (opsional)',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Misal: pelanggan minta produk yang belum ada...',
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: AppButton(
                  label: 'Kembali',
                  variant: AppButtonVariant.outline,
                  onPressed: _saving
                      ? null
                      : () => setState(() => _step--),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: AppButton(
                label: _step < _steps.length - 1 ? 'Lanjut' : 'Diagnosa Sekarang',
                icon: _step < _steps.length - 1
                    ? Icons.arrow_forward_rounded
                    : Icons.medical_services_rounded,
                isLoading: _saving,
                onPressed: _stepComplete && !_saving ? _next : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
