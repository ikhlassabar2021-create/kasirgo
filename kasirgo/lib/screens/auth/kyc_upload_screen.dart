import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/kyc_verification_service.dart';
import '../../widgets/common/centennial_background.dart';
import '../../widgets/common/glass_card.dart';

class KyCUploadScreen extends ConsumerStatefulWidget {
  const KyCUploadScreen({super.key});

  @override
  ConsumerState<KyCUploadScreen> createState() => _KyCUploadScreenState();
}

class _KyCUploadScreenState extends ConsumerState<KyCUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  XFile? _ktpImage;
  XFile? _selfieImage;
  bool _isLoading = false;
  KYCVerificationResult? _result;

  Future<void> _pickImage(ImageSource source, ImageField field) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          if (field == ImageField.ktp) _ktpImage = image;
          if (field == ImageField.selfie) _selfieImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat gambar: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _submitKYC() async {
    if (!_formKey.currentState!.validate()) return;

    if (_ktpImage == null || _selfieImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('KTP dan foto selfie wajib diunggah'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      final kycService = KyCVerificationService();
      
      // Get outlet ID from provider or user data
      final outletId = int.tryParse(user?.outletId ?? '1') ?? 1;
      
      final result = await kycService.verifyKYC(
        ktpImage: _ktpImage!,
        selfieImage: _selfieImage!,
        outletId: outletId,
        nik: '',
      );

      if (mounted) {
        setState(() => _result = result);

        if (result.isAutoApproved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verifikasi KYC berhasil! Akun Anda telah diaktifkan.'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          context.go('/home');
        } else if (result.needsManualReview) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Permintaan sedang ditinjau tim: ${result.message}'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
          context.go('/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verifikasi ditolak: ${result.message}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifikasi: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CentennialBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.badge_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Verifikasi KYC',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lengkapi data untuk aktivasi akun',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  if (_result != null) ...[
                    GlassCard(
                      blur: 12,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            _result!.isAutoApproved 
                                ? Icons.check_circle_rounded 
                                : (_result!.needsManualReview 
                                    ? Icons.hourglass_empty_rounded 
                                    : Icons.error_rounded),
                            size: 48,
                            color: _result!.isAutoApproved 
                                ? AppTheme.successColor 
                                : (_result!.needsManualReview 
                                    ? AppTheme.warningColor 
                                    : AppTheme.errorColor),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _result!.isAutoApproved 
                                ? 'Terverifikasi' 
                                : (_result!.needsManualReview ? 'Sedang Ditinjau' : 'Ditolak'),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _result!.isAutoApproved 
                                  ? AppTheme.successColor 
                                  : (_result!.needsManualReview 
                                      ? AppTheme.warningColor 
                                      : AppTheme.errorColor),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _result!.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: _result!.faceMatchScore / 100,
                            backgroundColor: AppTheme.borderColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _result!.faceMatchScore >= 85 
                                  ? AppTheme.successColor 
                                  : AppTheme.warningColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Skore Kecocokan Wajah: ${_result!.faceMatchScore}%',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/home'),
                        icon: const Icon(Icons.home_rounded),
                        label: const Text('Kembali ke Beranda'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ] else ...[
                    GlassCard(blur: 12, padding: const EdgeInsets.all(24), child: _buildUploadSection()),
                    const SizedBox(height: 16),
                    GlassCard(blur: 12, padding: const EdgeInsets.all(24), child: _buildSelfieSection()),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitKYC,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.upload_file_rounded),
                                const SizedBox(width: 8),
                                Text(
                                  'Submit Verifikasi',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Foto KTP', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => _pickImage(ImageSource.camera, ImageField.ktp),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, AppTheme.backgroundColor.withValues(alpha: 0.3)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _ktpImage != null ? AppTheme.successColor : AppTheme.primaryColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: _ktpImage == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt_rounded, size: 40, color: AppTheme.textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      'Ambil Foto KTP',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '(Pastikan jelas & tidak glare)',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(File(_ktpImage!.path), fit: BoxFit.cover),
                ),
        ),
      ),
    ]);
  }

  Widget _buildSelfieSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Foto Selfie + KTP', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => _pickImage(ImageSource.camera, ImageField.selfie),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, AppTheme.backgroundColor.withValues(alpha: 0.3)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _selfieImage != null ? AppTheme.successColor : AppTheme.primaryColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: _selfieImage == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt_rounded, size: 40, color: AppTheme.textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      'Ambil Selfie Pegang KTP',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '(Wajah terlihat jelas)',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(File(_selfieImage!.path), fit: BoxFit.cover),
                ),
        ),
      ),
    ]);
  }
}

enum ImageField { ktp, selfie }
