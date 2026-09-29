import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth/onboarding_kyc_screen.dart';
import '../../services/kyc_verification_service.dart';
import 'centennial_background.dart';

/// Memblokir modul owner sampai KYC `verified`.
///
/// Sebelum verified: hanya wizard KYC + bantuan + logout yang tampil.
/// Tidak ada tombol lewati (sesuai spec Phase 7.8 ST7.8-7).
class KycGate extends ConsumerStatefulWidget {
  final Widget child;

  const KycGate({super.key, required this.child});

  @override
  ConsumerState<KycGate> createState() => _KycGateState();
}

class _KycGateState extends ConsumerState<KycGate> {
  final _kyc = KycService();
  bool _checking = true;
  bool _verified = false;
  bool _isOwner = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId;
    if (outletId == null || outletId.isEmpty) {
      if (mounted) {
        setState(() {
          _checking = false;
          _verified = true;
        });
      }
      return;
    }
    _isOwner = user?.role == 'owner';
    final ok = await _kyc.refreshIfStale(outletId);
    if (mounted) {
      setState(() {
        _verified = ok;
        _checking = false;
      });
    }
  }

  void _onStatus(KycStatus status) {
    if (status.isVerified) {
      setState(() => _verified = true);
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const CentennialBackground(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_verified) return widget.child;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CentennialBackground(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: AppTheme.warningColor, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Selesaikan verifikasi untuk mulai berjualan',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: const Text('Keluar'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.borderColor),
              Expanded(
                child: _isOwner
                    ? OnboardingKycScreen(gated: true, onStatusChanged: _onStatus)
                    : _buildStaffBlocked(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaffBlocked() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 64, color: AppTheme.warningColor),
            SizedBox(height: 16),
            Text('Outlet belum terverifikasi',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              'Pemilik outlet belum menyelesaikan verifikasi KYC. Hubungi pemilik untuk mulai berjualan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
