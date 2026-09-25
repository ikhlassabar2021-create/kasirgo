import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/shift.dart';
import '../../models/tip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/responsive.dart';

final activeShiftProvider = FutureProvider.autoDispose<Shift?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user?.outletId == null) return null;
  return SupabaseService().getActiveShift(user!.outletId!, userId: user.id);
});

final shiftTipsProvider = FutureProvider.autoDispose<List<Tip>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user?.outletId == null) return [];
  return SupabaseService().getTips(user!.outletId!);
});

class CashierHomeScreen extends ConsumerStatefulWidget {
  const CashierHomeScreen({super.key});

  @override
  ConsumerState<CashierHomeScreen> createState() => _CashierHomeScreenState();
}

class _CashierHomeScreenState extends ConsumerState<CashierHomeScreen> {
  int _bottomNavIndex = 0;

  void _handleOpenShift(BuildContext parentContext, String outletId, String userId) {
    final cashController = TextEditingController(text: '0');
    String selectedShift = 'pagi';

    showDialog(
      context: parentContext,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          title: Text(
            'Buka Shift Baru',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Shift:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['pagi', 'siang', 'malam'].map((s) {
                  final isSelected = selectedShift == s;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setDialogState(() => selectedShift = s),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor : AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
                          ),
                          child: Text(
                            s.toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cashController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Kas Modal Awal',
                  prefixText: 'Rp ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final openingCash = double.tryParse(cashController.text) ?? 0.0;
                final messenger = ScaffoldMessenger.of(parentContext);
                Navigator.pop(ctx);
                final newShift = Shift(
                  id: '',
                  outletId: outletId,
                  userId: userId,
                  shift: selectedShift,
                  openedAt: DateTime.now(),
                  openingCash: openingCash,
                );
                final result = await SupabaseService().openShift(newShift);
                if (!mounted) return;
                ref.invalidate(activeShiftProvider);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(result != null ? 'Shift berhasil dibuka!' : 'Gagal membuka shift'),
                    backgroundColor: result != null ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                );
              },
              child: const Text('Mulai Shift'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCloseShift(BuildContext parentContext, Shift currentShift) {
    final cashController = TextEditingController(text: currentShift.openingCash.toStringAsFixed(0));

    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: Text(
          'Tutup Shift Kasir',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shift ${currentShift.shift.toUpperCase()} dimulai pukul ${Formatters.date(currentShift.openedAt)}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Modal Awal: ${Formatters.currency(currentShift.openingCash)}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cashController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Total Kas Akhir (Uang Fisik di Laci)',
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              final closingCash = double.tryParse(cashController.text) ?? 0.0;
              final messenger = ScaffoldMessenger.of(parentContext);
              Navigator.pop(ctx);
              final success = await SupabaseService().closeShift(currentShift.id, closingCash);
              if (!mounted) return;
              ref.invalidate(activeShiftProvider);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(success ? 'Shift ditutup. Rekap tersimpan!' : 'Gagal menutup shift'),
                  backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
                ),
              );
            },
            child: const Text('Tutup & Selesai'),
          ),
        ],
      ),
    );
  }

  void _showAddTipDialog(BuildContext parentContext, String outletId, String? userId) {
    final tipController = TextEditingController();

    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: Text(
          'Catat Tip Tunai/Kolektif',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        content: TextField(
          controller: tipController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Nominal Tip',
            prefixText: 'Rp ',
            hintText: 'Contoh: 10000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(tipController.text) ?? 0.0;
              if (amount <= 0) return;
              final messenger = ScaffoldMessenger.of(parentContext);
              Navigator.pop(ctx);
              final tip = Tip(
                id: '',
                outletId: outletId,
                userId: userId,
                amount: amount,
                createdAt: DateTime.now(),
              );
              final res = await SupabaseService().recordTip(tip);
              if (!mounted) return;
              ref.invalidate(shiftTipsProvider);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(res != null ? 'Tip ${Formatters.currency(amount)} dicatat!' : 'Gagal mencatat tip'),
                  backgroundColor: res != null ? AppTheme.successColor : AppTheme.errorColor,
                ),
              );
            },
            child: const Text('Simpan Tip'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    final outletType = ref.watch(outletTypeProvider(user.outletId ?? ''));
    final activeShiftAsync = ref.watch(activeShiftProvider);
    final tipsAsync = ref.watch(shiftTipsProvider);

    return AppShell(
      navItems: const [
        AppNavItem(icon: Icons.dashboard_rounded, label: 'Home Kasir'),
        AppNavItem(icon: Icons.point_of_sale_rounded, label: 'POS'),
      ],
      currentIndex: _bottomNavIndex,
      onIndexChanged: (index) {
        setState(() => _bottomNavIndex = index);
        if (index == 1) {
          context.push('/cashier/pos');
        }
      },
      headerTitle: 'Home Kasir',
      drawer: AppDrawer(user: user),
      mobileTitle: _RoleBadge(icon: Icons.badge_rounded, label: 'KASIR • ${outletType.toUpperCase()}'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(context, user.email, activeShiftAsync.value),
              const SizedBox(height: 24),
              _buildShiftAndTipSection(
                context,
                user.outletId ?? '',
                user.id,
                activeShiftAsync.value,
                tipsAsync.value ?? [],
              ),
              const SizedBox(height: 28),
              const _SectionLabel(title: 'Aksi Cepat Kasir'),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.25,
                children: [
                  _QuickActionCard(
                    icon: Icons.point_of_sale_rounded,
                    color: AppTheme.primaryColor,
                    title: 'Buka POS',
                    subtitle: 'Layar transaksi',
                    onTap: () => context.push('/cashier/pos'),
                  ),
                  _QuickActionCard(
                    icon: Icons.qr_code_2_rounded,
                    color: AppTheme.secondaryColor,
                    title: 'QRIS Manual',
                    subtitle: 'Statis / Dinamis',
                    onTap: () => context.push('/cashier/pos'),
                  ),
                  _QuickActionCard(
                    icon: Icons.volunteer_activism_rounded,
                    color: AppTheme.warningColor,
                    title: 'Input Tip',
                    subtitle: 'Catat tip masuk',
                    onTap: () => _showAddTipDialog(context, user.outletId ?? '', user.id),
                  ),
                  _QuickActionCard(
                    icon: Icons.access_time_rounded,
                    color: activeShiftAsync.value != null ? AppTheme.errorColor : AppTheme.successColor,
                    title: activeShiftAsync.value != null ? 'Tutup Shift' : 'Buka Shift',
                    subtitle: activeShiftAsync.value != null ? 'Hitung kas fisik' : 'Mulai shift baru',
                    onTap: () {
                      if (activeShiftAsync.value != null) {
                        _handleCloseShift(context, activeShiftAsync.value!);
                      } else {
                        _handleOpenShift(context, user.outletId ?? '', user.id);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, String email, Shift? activeShift) {
    final hasActiveShift = activeShift != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: hasActiveShift ? const Color(0xFF34D399) : Colors.white70,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasActiveShift
                                  ? 'Shift ${activeShift.shift.toUpperCase()} Aktif'
                                  : 'Shift Belum Dibuka',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.point_of_sale_rounded, size: 22),
                  label: Text(
                    'BUKA KASIR (POS)',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  onPressed: () => context.push('/cashier/pos'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftAndTipSection(
    BuildContext context,
    String outletId,
    String userId,
    Shift? activeShift,
    List<Tip> tips,
  ) {
    final totalTips = tips.fold<double>(0.0, (sum, t) => sum + t.amount);

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status Shift', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    Icon(
                      activeShift != null ? Icons.check_circle : Icons.pause_circle_outline,
                      size: 16,
                      color: activeShift != null ? AppTheme.successColor : AppTheme.warningColor,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  activeShift != null ? 'Shift ${activeShift.shift.toUpperCase()}' : 'Tutup',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                ),
                Text(
                  activeShift != null
                      ? 'Modal: ${Formatters.currency(activeShift.openingCash)}'
                      : 'Buka sebelum melayani',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Tip', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    Icon(Icons.volunteer_activism_rounded, size: 16, color: Color(0xFFF59E0B)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  Formatters.currency(totalTips),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                ),
                Text(
                  '${tips.length} transaksi tip',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RoleBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: 10,
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      borderColor: AppTheme.borderColor,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
