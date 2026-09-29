import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/kyc_verification_service.dart';
import '../../widgets/common/centennial_background.dart';

/// Wizard KYC wajib (6 field) — foto disimpan LOKAL di HP.
///
/// Alur: unsubmitted -> draft -> pending_review -> verified/rejected.
/// Auto-verify + anti-duplikat dijalankan di server (RPC `submit_kyc`).
class OnboardingKycScreen extends ConsumerStatefulWidget {
  /// Dipanggil setiap status berubah (mis. setelah submit).
  final ValueChanged<KycStatus>? onStatusChanged;

  /// True bila ditampilkan penuh sebagai gate (tanpa tombol kembali).
  final bool gated;

  const OnboardingKycScreen({super.key, this.onStatusChanged, this.gated = false});

  @override
  ConsumerState<OnboardingKycScreen> createState() => _OnboardingKycScreenState();
}

class _OnboardingKycScreenState extends ConsumerState<OnboardingKycScreen> {
  final _kyc = KycService();
  final _formKeys = [GlobalKey<FormState>(), GlobalKey<FormState>(), GlobalKey<FormState>()];

  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _storeName = TextEditingController();
  final _storeAddress = TextEditingController();
  final _nik = TextEditingController();

  XFile? _ktpImage;
  XFile? _selfieImage;
  bool _consent = false;
  bool _loading = false;
  bool _prefilling = true;
  int _step = 0;

  String? _outletId;
  KycStatus _status = KycStatus.unsubmitted;
  String? _message;
  String? _rejectReason;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _storeName.dispose();
    _storeAddress.dispose();
    _nik.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    final user = ref.read(currentUserProvider);
    _outletId = user?.outletId;
    if (user != null) {
      _email.text = user.email;
      final guessName = user.name ?? '';
      if (guessName.isNotEmpty && guessName != 'Warung Saya') {
        _storeName.text = guessName;
      }
    }

    if (_outletId != null && _outletId!.isNotEmpty) {
      try {
        final outlet = await Supabase.instance.client
            .from('outlets')
            .select('name, address, phone, owner_wa_number')
            .eq('id', _outletId!)
            .maybeSingle();
        if (outlet != null) {
          if ((outlet['name'] as String?)?.isNotEmpty == true) {
            _storeName.text = outlet['name'] as String;
          }
          if ((outlet['address'] as String?)?.isNotEmpty == true) {
            _storeAddress.text = outlet['address'] as String;
          }
          final wa = (outlet['owner_wa_number'] as String?)?.isNotEmpty == true
              ? outlet['owner_wa_number'] as String?
              : outlet['phone'] as String?;
          if (wa != null && wa.isNotEmpty) _phone.text = wa;
        }
      } catch (_) {}

      final draft = await _kyc.loadDraft(_outletId!);
      if (draft != null) {
        _fullName.text = draft.fullName ?? _fullName.text;
        _phone.text = draft.phone ?? _phone.text;
        _email.text = draft.email ?? _email.text;
        _storeName.text = draft.storeName ?? _storeName.text;
        _storeAddress.text = draft.storeAddress ?? _storeAddress.text;
        _ktpImage = draft.ktpImagePath != null ? XFile(draft.ktpImagePath!) : null;
        _selfieImage =
            draft.selfieKtpImagePath != null ? XFile(draft.selfieKtpImagePath!) : null;
      }

      final record = await _kyc.fetchRecord(_outletId!);
      if (record != null) {
        _status = record.status;
        _rejectReason = record.rejectReason;
      } else {
        _status = await _kyc.cachedStatus(_outletId!);
      }
    }

    if (mounted) setState(() => _prefilling = false);
  }

  Future<void> _pickImage(bool isKtp) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        setState(() {
          if (isKtp) {
            _ktpImage = image;
          } else {
            _selfieImage = image;
          }
        });
      }
    } catch (e) {
      _snack('Gagal memuat gambar: $e', AppTheme.errorColor);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _saveDraft() async {
    if (_outletId == null || _outletId!.isEmpty) return;
    await _kyc.saveDraft(KycRecord(
      outletId: _outletId!,
      fullName: _fullName.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      storeName: _storeName.text.trim(),
      storeAddress: _storeAddress.text.trim(),
      ktpImagePath: _ktpImage?.path,
      selfieKtpImagePath: _selfieImage?.path,
      status: KycStatus.draft,
    ));
    setState(() => _status = KycStatus.draft);
    widget.onStatusChanged?.call(KycStatus.draft);
    _snack('Draf tersimpan di perangkat.', AppTheme.primaryColor);
  }

  void _next() {
    if (_step == 0 && !(_formKeys[0].currentState?.validate() ?? false)) return;
    if (_step < 2) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _submit() async {
    if (!(_formKeys[1].currentState?.validate() ?? false)) return;
    if (_ktpImage == null || _selfieImage == null) {
      _snack('Foto KTP dan selfie memegang KTP wajib diambil.', AppTheme.warningColor);
      return;
    }
    if (!_consent) {
      _snack('Centang persetujuan data (UU PDP) untuk melanjutkan.', AppTheme.warningColor);
      return;
    }
    if (_outletId == null || _outletId!.isEmpty) {
      _snack('Outlet tidak ditemukan.', AppTheme.errorColor);
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _kyc.submit(
        outletId: _outletId!,
        fullName: _fullName.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        storeName: _storeName.text.trim(),
        storeAddress: _storeAddress.text.trim(),
        ktpImagePath: _ktpImage!.path,
        selfieKtpImagePath: _selfieImage!.path,
        nik: _nik.text.trim().isEmpty ? null : _nik.text.trim(),
        consent: _consent,
      );

      if (!mounted) return;
      setState(() {
        _status = result.status;
        _message = result.message;
      });
      widget.onStatusChanged?.call(result.status);

      if (result.isVerified) {
        _snack('Verifikasi berhasil. Selamat berjualan!', AppTheme.successColor);
      } else if (result.savedOffline) {
        _snack(result.message, AppTheme.primaryColor);
      } else if (result.duplicate) {
        _snack(result.message, AppTheme.errorColor);
      } else {
        _snack(result.message, AppTheme.warningColor);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_prefilling) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_status.isVerified) {
      return _buildStatusPanel(
        icon: Icons.verified_rounded,
        color: AppTheme.successColor,
        title: 'Outlet Terverifikasi',
        body: 'Verifikasi KYC sudah selesai. Anda dapat menggunakan semua fitur.',
      );
    }

    return CentennialBackground(
      child: Column(
        children: [
          _buildHeader(),
          _buildStepper(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_status == KycStatus.rejected) _buildRejectedBanner(),
                  if (_status == KycStatus.pendingReview) _buildPendingBanner(),
                  IndexedStack(
                    index: _step,
                    children: [_stepBusiness(), _stepDocuments(), _stepReview()],
                  ),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.badge_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Verifikasi Data Usaha',
                        style: GoogleFonts.inter(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                    Text('Wajib sebelum mulai berjualan',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    const labels = ['Data Usaha', 'Dokumen', 'Tinjau'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: List.generate(3, (i) {
          final active = i <= _step;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primaryColor : AppTheme.surfaceMutedColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : AppTheme.textSecondary)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(labels[i],
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: i == _step ? FontWeight.w700 : FontWeight.w500,
                          color: active ? AppTheme.textPrimary : AppTheme.textSecondary)),
                ),
                if (i < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: i < _step ? AppTheme.primaryColor : AppTheme.borderColor,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboard,
    int maxLines = 1,
    bool optional = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(color: AppTheme.textPrimary),
        validator: validator ??
            (optional
                ? null
                : (v) => (v == null || v.trim().isEmpty) ? '$label wajib diisi' : null),
        decoration: InputDecoration(
          labelText: optional ? '$label (opsional)' : label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
          filled: true,
          fillColor: AppTheme.surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.borderColor),
          ),
        ),
      ),
    );
  }

  Widget _stepBusiness() {
    return Form(
      key: _formKeys[0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            controller: _fullName,
            label: 'Nama Lengkap Pemilik',
            icon: Icons.person_outline,
            hint: 'Sesuai KTP',
          ),
          _field(
            controller: _phone,
            label: 'Nomor HP (WhatsApp)',
            icon: Icons.phone_outlined,
            hint: '08xxxxxxxxxx',
            keyboard: TextInputType.phone,
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
              if (digits.length < 10) return 'Nomor HP minimal 10 digit';
              return null;
            },
          ),
          _field(
            controller: _email,
            label: 'Email',
            icon: Icons.mail_outline,
            hint: 'nama@email.com',
            keyboard: TextInputType.emailAddress,
            validator: (v) {
              final s = (v ?? '').trim();
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                return 'Email tidak valid';
              }
              return null;
            },
          ),
          _field(
            controller: _storeName,
            label: 'Nama Toko',
            icon: Icons.storefront_outlined,
            hint: 'Contoh: Warung Barokah',
            validator: (v) =>
                (v == null || v.trim().length < 3) ? 'Nama toko minimal 3 huruf' : null,
          ),
          _field(
            controller: _storeAddress,
            label: 'Alamat Toko',
            icon: Icons.location_on_outlined,
            hint: 'Jalan, RT/RW, kelurahan, kota',
            maxLines: 3,
            validator: (v) =>
                (v == null || v.trim().length < 5) ? 'Alamat minimal 5 karakter' : null,
          ),
        ],
      ),
    );
  }

  Widget _stepDocuments() {
    return Form(
      key: _formKeys[1],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _photoPicker(
            title: 'Foto KTP',
            subtitle: 'Pastikan jelas, tidak glare, semua sudut terlihat',
            image: _ktpImage,
            onTap: () => _pickImage(true),
          ),
          const SizedBox(height: 16),
          _photoPicker(
            title: 'Selfie Memegang KTP',
            subtitle: 'Wajah & KTP terlihat jelas dalam satu foto',
            image: _selfieImage,
            onTap: () => _pickImage(false),
          ),
          const SizedBox(height: 16),
          _field(
            controller: _nik,
            label: 'NIK (opsional, untuk cegah duplikat)',
            icon: Icons.credit_card_outlined,
            hint: '16 digit — hanya disimpan sebagai hash',
            keyboard: TextInputType.number,
            optional: true,
          ),
          _tipCard(),
        ],
      ),
    );
  }

  Widget _stepReview() {
    return Form(
      key: _formKeys[2],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: [
                _reviewRow('Nama', _fullName.text),
                _reviewRow('No. HP', _phone.text),
                _reviewRow('Email', _email.text),
                _reviewRow('Nama Toko', _storeName.text),
                _reviewRow('Alamat', _storeAddress.text),
                _reviewRow('Foto KTP', _ktpImage == null ? 'Belum ada' : 'Siap'),
                _reviewRow('Selfie + KTP', _selfieImage == null ? 'Belum ada' : 'Siap'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            activeColor: AppTheme.primaryColor,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Saya menyetujui pemrosesan data untuk verifikasi (UU PDP). Foto disimpan di perangkat ini.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _photoPicker({
    required String title,
    required String subtitle,
    required XFile? image,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: image != null ? AppTheme.successColor : AppTheme.borderColor,
            width: 2,
          ),
        ),
        child: image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_rounded,
                      size: 34, color: AppTheme.primaryColor),
                  const SizedBox(height: 8),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(image.path), fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Ganti',
                            style: TextStyle(fontSize: 11, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _tipCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tips foto yang benar',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('Benar: terang, fokus, KTP tidak tertutup jari, wajah jelas.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          Text('Salah: blur, gelap/glare, terpotong, atau memakai masker.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildRejectedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_rounded, color: AppTheme.errorColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _message ??
                  (_rejectReason?.isNotEmpty == true
                      ? 'Ditolak: $_rejectReason'
                      : 'Verifikasi ditolak. Mohon perbaiki dan kirim ulang.'),
              style: const TextStyle(fontSize: 12, color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_empty_rounded, color: AppTheme.warningColor),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Data Anda sedang ditinjau. Anda dapat mengirim ulang bila perlu.',
              style: TextStyle(fontSize: 12, color: AppTheme.warningColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(top: BorderSide(color: AppTheme.borderColor)),
        ),
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _back,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Kembali'),
                ),
              ),
            if (_step > 0) const SizedBox(width: 8),
            if (_step < 2)
              IconButton(
                onPressed: _loading ? null : _saveDraft,
                tooltip: 'Simpan draf',
                icon: const Icon(Icons.save_outlined),
                color: AppTheme.textSecondary,
              ),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : (_step < 2 ? _next : _submit),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_step < 2 ? 'Lanjut' : 'Kirim Verifikasi',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            if (!widget.gated)
              ElevatedButton(
                onPressed: () => context.go('/owner'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ke Beranda'),
              ),
          ],
        ),
      ),
    );
  }
}
