import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../providers/app_mode_provider.dart';
import '../../utils/error_messages.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/centennial_background.dart';

/// ST17-4 (Phase 17): gerbang auth Pembeli.
///
/// Pembeli WAJIB punya akun: daftar email + konfirmasi, atau masuk dengan
/// email/password, atau Google OAuth. Setelah sesi aktif, profil (nama/HP/
/// alamat) dilengkapi di [BuyerOnboardingScreen].
class BuyerAuthScreen extends ConsumerStatefulWidget {
  const BuyerAuthScreen({super.key});

  @override
  ConsumerState<BuyerAuthScreen> createState() => _BuyerAuthScreenState();
}

enum _BuyerAuthMode { login, register }

class _BuyerAuthScreenState extends ConsumerState<BuyerAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  _BuyerAuthMode _mode = _BuyerAuthMode.login;
  bool _busy = false;
  bool _awaitingConfirmation = false;
  String _confirmationEmail = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_BuyerAuthMode mode) {
    if (_busy || _mode == mode) return;
    setState(() {
      _mode = mode;
      _awaitingConfirmation = false;
    });
  }

  void _afterSession() {
    ref.invalidate(appCustomerProvider);
    ref.invalidate(buyerProfileProvider);
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    final service = ref.read(appCustomerServiceProvider);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    try {
      if (_mode == _BuyerAuthMode.register) {
        final res = await service.signUpBuyer(
          email: email,
          password: password,
          name: _nameCtrl.text,
        );
        if (!mounted) return;
        // Supabase mengembalikan user "obfuscated" tanpa identitas bila email
        // sudah terdaftar (anti-enumeration). Perlakukan sebagai sudah punya
        // akun: arahkan ke mode Masuk, bukan menunggu konfirmasi yang tak akan
        // pernah datang.
        final alreadyRegistered =
            (res.user?.identities?.isEmpty ?? false) && res.session == null;
        if (alreadyRegistered) {
          setState(() {
            _mode = _BuyerAuthMode.login;
            _awaitingConfirmation = false;
            _passwordCtrl.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Email sudah terdaftar. Silakan masuk dengan kata sandi Anda.'),
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }
        if (res.session != null) {
          // Konfirmasi email dimatikan di project -> langsung masuk.
          _afterSession();
        } else {
          setState(() {
            _awaitingConfirmation = true;
            _confirmationEmail = email;
          });
        }
      } else {
        await service.signInWithPassword(email: email, password: password);
        if (!mounted) return;
        _afterSession();
      }
    } catch (e) {
      if (mounted) {
        // Login ditolak karena email belum dikonfirmasi: tampilkan kartu
        // konfirmasi + tombol kirim ulang, jangan bilang "kata sandi salah".
        if (_mode == _BuyerAuthMode.login && isEmailNotConfirmed(e)) {
          setState(() {
            _awaitingConfirmation = true;
            _confirmationEmail = email;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(friendlyError(e)),
              duration: const Duration(seconds: 6),
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e,
                fallback: _mode == _BuyerAuthMode.register
                    ? 'Pendaftaran gagal. Silakan coba lagi.'
                    : 'Masuk gagal. Periksa email dan kata sandi Anda.')),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(appCustomerServiceProvider).signInWithGoogle();
      if (!mounted) return;
      _afterSession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e,
                fallback: 'Masuk dengan Google gagal. Silakan coba lagi.')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _confirmationEmail.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(appCustomerServiceProvider).resendConfirmation(_confirmationEmail);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email konfirmasi dikirim ulang. Cek kotak masuk / spam.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e,
                fallback: 'Gagal mengirim ulang email. Coba lagi nanti.')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    if (_awaitingConfirmation)
                      _buildConfirmationCard()
                    else
                      _buildForm(),
                  ],
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
          'Belanja Lebih Mudah',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Masuk atau daftar dengan email untuk mulai belanja di warung sekitar.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final isRegister = _mode == _BuyerAuthMode.register;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeToggle(mode: _mode, onChanged: _switchMode),
        const SizedBox(height: 18),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isRegister) ...[
                  AppTextField(
                    controller: _nameCtrl,
                    label: 'Nama Lengkap',
                    hint: 'Mis. Budi Santoso',
                    prefixIcon: Icons.person_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nama wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 14),
                ],
                AppTextField(
                  controller: _emailCtrl,
                  label: 'Email',
                  hint: 'nama@email.com',
                  prefixIcon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Email wajib diisi';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                      return 'Format email belum benar';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _passwordCtrl,
                  label: 'Kata Sandi',
                  hint: 'Minimal 6 karakter',
                  prefixIcon: Icons.lock_rounded,
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Kata sandi wajib diisi';
                    if (v.length < 6) return 'Minimal 6 karakter';
                    return null;
                  },
                ),
                if (isRegister) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Kami akan mengirim tautan konfirmasi ke email Anda. Buka tautan itu sebelum masuk.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: isRegister ? 'Daftar' : 'Masuk',
          icon: isRegister ? Icons.person_add_alt_1_rounded : Icons.login_rounded,
          isLoading: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider(color: AppTheme.borderColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('atau',
                  style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ),
            const Expanded(child: Divider(color: AppTheme.borderColor)),
          ],
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Lanjut dengan Google',
          icon: Icons.g_mobiledata_rounded,
          variant: AppButtonVariant.outline,
          onPressed: _busy ? null : _google,
        ),
        const SizedBox(height: 12),
        Text(
          'Data Anda tersimpan aman dan hanya dipakai untuk memproses pesanan.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildConfirmationCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.mark_email_read_rounded,
                    color: AppTheme.primaryColor, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'Cek Email Anda',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kami sudah mengirim tautan konfirmasi ke $_confirmationEmail. '
                'Buka tautan itu (cek juga folder spam), lalu kembali ke sini untuk masuk.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Sudah Konfirmasi, Masuk',
          icon: Icons.login_rounded,
          onPressed: _busy
              ? null
              : () => setState(() {
                    _awaitingConfirmation = false;
                    _mode = _BuyerAuthMode.login;
                  }),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Kirim Ulang Email',
          icon: Icons.refresh_rounded,
          variant: AppButtonVariant.outline,
          isLoading: _busy,
          onPressed: _resend,
        ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final _BuyerAuthMode mode;
  final ValueChanged<_BuyerAuthMode> onChanged;

  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMutedColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          _tab(context, 'Masuk', _BuyerAuthMode.login),
          _tab(context, 'Daftar', _BuyerAuthMode.register),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, String label, _BuyerAuthMode value) {
    final active = mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppTheme.surfaceColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppTheme.textPrimary.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
