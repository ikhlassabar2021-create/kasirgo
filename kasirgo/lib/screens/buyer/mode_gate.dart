import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_theme.dart';
import '../../models/app_mode.dart';
import '../../providers/app_mode_provider.dart';
import 'mode_select_screen.dart';

/// ST17-4 (Phase 17 - Ekosistem Hyper-Local): gerbang mode di root router.
///
/// - Mode belum dipilih -> tampilkan [ModeSelectScreen].
/// - Mode = Penjual -> arahkan ke alur login Penjual.
/// - Mode = Pembeli -> arahkan ke shell Pembeli.
class ModeGate extends ConsumerStatefulWidget {
  const ModeGate({super.key});

  @override
  ConsumerState<ModeGate> createState() => _ModeGateState();
}

class _ModeGateState extends ConsumerState<ModeGate> {
  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appModeProvider);

    if (mode == null) {
      return const ModeSelectScreen();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(mode == AppMode.seller ? '/login' : '/buyer');
    });

    return const Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
