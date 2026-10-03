import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/logout_button.dart';
import '../../widgets/common/responsive.dart';
import '../modules/kitchen_display_screen.dart';

/// Shell khusus role KOKI: satu-satunya akses adalah Kitchen Display (KDS).
class KitchenHomeScreen extends ConsumerWidget {
  const KitchenHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    final outletType = ref.watch(outletTypeProvider(user.outletId ?? ''));

    return AppShell(
      navItems: const [
        AppNavItem(icon: Icons.restaurant_rounded, label: 'Dapur'),
      ],
      currentIndex: 0,
      onIndexChanged: (_) {},
      headerTitle: 'Kitchen Display',
      drawer: AppDrawer(user: user),
      mobileActions: const [LogoutButton()],
      sidebarFooter: _KokiSidebarFooter(email: user.email),
      mobileTitle: _KokiBadge(label: 'KOKI • ${outletType.toUpperCase()}'),
      body: const SafeArea(child: KitchenDisplayScreen(embedded: true)),
    );
  }
}

class _KokiBadge extends StatelessWidget {
  final String label;

  const _KokiBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.restaurant_rounded, size: 14, color: AppTheme.warningColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppTheme.warningColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _KokiSidebarFooter extends StatelessWidget {
  final String email;

  const _KokiSidebarFooter({required this.email});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15),
            child: Text(
              email.isNotEmpty ? email[0].toUpperCase() : 'K',
              style: const TextStyle(
                color: AppTheme.warningColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Text(
                  'KOKI',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const LogoutButton(),
        ],
      ),
    );
  }
}
