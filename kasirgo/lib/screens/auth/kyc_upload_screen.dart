import 'package:flutter/material.dart';

import 'onboarding_kyc_screen.dart';

/// Deprecated: gunakan [OnboardingKycScreen].
/// Dipertahankan sebagai alias agar rute/link lama tetap bekerja.
class KyCUploadScreen extends StatelessWidget {
  const KyCUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingKycScreen();
  }
}