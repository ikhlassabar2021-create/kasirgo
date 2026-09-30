import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';

/// Tombol keluar yang dapat dipakai di header desktop maupun app bar mobile.
class LogoutButton extends ConsumerWidget {
  final bool compact;

  const LogoutButton({super.key, this.compact = true});

  Future<void> _confirmAndSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: const Text('Keluar Akun?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Anda akan keluar dari sesi ini dan kembali ke halaman login.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Icon(Icons.close_rounded, size: 20),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(currentUserProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!compact) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorColor,
          side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Keluar'),
        onPressed: () => _confirmAndSignOut(context, ref),
      );
    }

    return IconButton(
      tooltip: 'Keluar Akun',
      icon: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
      onPressed: () => _confirmAndSignOut(context, ref),
    );
  }
}