import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../providers/app_mode_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/centennial_background.dart';

/// ST17-4 (Phase 17 - Ekosistem Hyper-Local): onboarding Pembeli zero-friction.
/// Cukup Nama + NoHP -> sesi anonymous -> baris `app_customers`.
/// Consent UU PDP (lokasi + nohp) disimpan lokal di perangkat.
class BuyerOnboardingScreen extends ConsumerStatefulWidget {
  const BuyerOnboardingScreen({super.key});

  @override
  ConsumerState<BuyerOnboardingScreen> createState() =>
      _BuyerOnboardingScreenState();
}

class _BuyerOnboardingScreenState extends ConsumerState<BuyerOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _consentPhone = true;
  bool _consentLocation = false;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_consentPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izinkan nomor HP dipakai agar pesanan bisa dikonfirmasi.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    final service = ref.read(appCustomerServiceProvider);
    final result = await service.register(
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
    );
    if (!mounted) return;

    if (result == null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Periksa koneksi lalu coba lagi.')),
      );
      return;
    }

    await service.setConsent(location: _consentLocation, phone: _consentPhone);
    ref.invalidate(appCustomerProvider);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CentennialBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppTheme.formMaxWidth),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      AppCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              controller: _nameCtrl,
                              label: 'Nama Anda',
                              hint: 'Mis. Budi',
                              prefixIcon: Icons.person_rounded,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Nama wajib diisi'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: _phoneCtrl,
                              label: 'Nomor HP / WhatsApp',
                              hint: '08xxxxxxxxxx',
                              prefixIcon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                              ],
                              validator: (v) {
                                final digits =
                                    (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                                if (digits.length < 9) {
                                  return 'Nomor HP belum benar';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            _ConsentTile(
                              value: _consentPhone,
                              title: 'Saya setuju nomor HP dipakai toko',
                              subtitle:
                                  'Untuk konfirmasi pesanan & kabar status. Tidak dibagikan ke pihak lain.',
                              onChanged: (v) =>
                                  setState(() => _consentPhone = v ?? false),
                            ),
                            _ConsentTile(
                              value: _consentLocation,
                              title: 'Izinkan akses lokasi (opsional)',
                              subtitle:
                                  'Menampilkan warung terdekat. Anda tetap bisa pesan tanpa lokasi.',
                              onChanged: (v) =>
                                  setState(() => _consentLocation = v ?? false),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'Mulai Belanja',
                        icon: Icons.arrow_forward_rounded,
                        isLoading: _busy,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Data Anda tersimpan aman dan hanya dipakai untuk pesanan.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            gradient: AppTheme.aiBadgeGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 14),
        Text(
          'Kenalan dulu, yuk',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Cukup nama dan nomor HP. Tanpa email, tanpa password.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _ConsentTile extends StatelessWidget {
  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool?> onChanged;

  const _ConsentTile({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppTheme.primaryColor,
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary),
      ),
    );
  }
}
