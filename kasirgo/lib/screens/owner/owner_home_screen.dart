import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/module_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../utils/ai_engine.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/centennial_background.dart';
import 'debt_screen.dart';
import 'social_commerce_screen.dart';
import 'whatsapp_broadcast_screen.dart';
import 'qr_table_screen.dart';
import 'online_catalog_screen.dart';
import 'health_score_screen.dart';
import '../modules/kitchen_display_screen.dart';
import '../modules/ppob_screen.dart';
import '../modules/restock_screen.dart';
import '../modules/supporter_screen.dart';
import 'customer_list_screen.dart';
import 'employee_screen.dart';
import 'pos_screen.dart';
import 'product_list_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';

final homeSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user?.outletId == null) return {};

  final service = SupabaseService();
  final today = DateTime.now().toIso8601String().split('T')[0];

  final todayTransactions = await service.getTransactions(user!.outletId!, limit: 100);
  final todayFiltered = todayTransactions.where((t) => t.createdAt.toIso8601String().startsWith(today)).toList();

  final products = await service.getProducts(user.outletId!);
  final customers = await service.getCustomers(user.outletId!);

  final todaySales = todayFiltered.fold<double>(0, (sum, t) => sum + t.finalAmount);
  final todayCount = todayFiltered.length;

  final ai = AIEngine();
  final lowStockProducts = products.where((p) => p.stock > 0 && p.stock <= 10).toList();
  final lowMarginProducts = products.where((p) {
    final m = ai.checkMargin(p);
    return m['isLowMargin'] == true && p.costPrice != null && p.costPrice! > 0;
  }).toList();
  final flashSale = ai.suggestFlashSale(products, todayTransactions);

  final now = DateTime.now();
  final expiredProducts = products.where((p) {
    if (p.expiredDate == null) return false;
    return p.expiredDate!.isBefore(now) || p.expiredDate!.difference(now).inDays <= 7;
  }).toList();

  final notifications = <Map<String, dynamic>>[];
  for (final p in lowStockProducts) {
    notifications.add({
      'type': 'low_stock',
      'title': 'Stok Menipis: ${p.name}',
      'message': 'Sisa stok ${p.stock} ${p.unit ?? "pcs"}. Segera restock.',
      'icon': Icons.warning_amber_rounded,
      'color': AppTheme.errorColor,
    });
  }
  for (final p in expiredProducts) {
    final isPassed = p.expiredDate!.isBefore(now);
    notifications.add({
      'type': 'expired',
      'title': isPassed ? 'Produk Kedaluwarsa: ${p.name}' : 'Mendekati Kedaluwarsa: ${p.name}',
      'message': 'Expired: ${p.expiredDate.toString().split(' ')[0]}',
      'icon': Icons.timer_outlined,
      'color': AppTheme.errorColor,
    });
  }
  for (final fs in flashSale) {
    notifications.add({
      'type': 'dead_stock',
      'title': 'Stok Menumpuk: ${fs['productName']}',
      'message': '${fs['reason']}. Disarankan diskon ${fs['suggestedDiscount']}%.',
      'icon': Icons.inventory_2_outlined,
      'color': AppTheme.accentColor,
    });
  }
  if (todayFiltered.isNotEmpty) {
    notifications.add({
      'type': 'insight',
      'title': 'Insight Harian AI',
      'message': 'Total $todayCount transaksi bernilai Rp ${todaySales.toStringAsFixed(0)} hari ini.',
      'icon': Icons.auto_graph,
      'color': AppTheme.primaryColor,
    });
  }

  return {
    'todaySales': todaySales,
    'todayTransactions': todayCount,
    'products': products.length,
    'customers': customers.length,
    'lowStockProducts': lowStockProducts,
    'lowMarginProducts': lowMarginProducts,
    'flashSaleProducts': flashSale,
    'expiredProducts': expiredProducts,
    'notifications': notifications,
    'allTransactions': todayTransactions,
    'allProducts': products,
  };
});

class OwnerHomeScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final Widget? subScreen;

  const OwnerHomeScreen({super.key, this.initialIndex = 0, this.subScreen});

  @override
  ConsumerState<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends ConsumerState<OwnerHomeScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant OwnerHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      setState(() => _currentIndex = widget.initialIndex);
    }
  }

  void _showNotificationsSheet(List<Map<String, dynamic>> notifications) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            maxWidth: 560,
          ),
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Notifikasi',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        _NotificationCountPill(count: notifications.length),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (notifications.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'Tidak ada notifikasi saat ini.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: notifications.length,
                          separatorBuilder: (_, _) => const Divider(color: AppTheme.borderColor, height: 1),
                          itemBuilder: (context, idx) {
                            final notif = notifications[idx];
                            final color = notif['color'] as Color;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: color.withValues(alpha: 0.3)),
                                ),
                                child: Icon(notif['icon'] as IconData, color: color, size: 20),
                              ),
                              title: Text(
                                notif['title'] as String,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                notif['message'] as String,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final summaryAsync = ref.watch(homeSummaryProvider);

    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 860;

    final bodyContent = widget.subScreen ??
        IndexedStack(
          index: _currentIndex,
          children: [
            _buildDashboard(user.name ?? user.email, summaryAsync),
            const ProductListScreen(),
            const PosScreen(),
            const ReportScreen(),
            const CustomerListScreen(),
            const EmployeeScreen(),
            const SettingsScreen(),
          ],
        );

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: CentennialBackground(
          child: Row(
            children: [
              // Desktop Sidebar with Centennial Ocean Blue touch
              Container(
                width: 240,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Column(
                  children: [
                    // Brand Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'KasirGo',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'POS & Management',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderColor),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _buildDesktopNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
                          _buildDesktopNavItem(1, Icons.inventory_2_rounded, 'Produk'),
                          _buildDesktopNavItem(2, Icons.point_of_sale_rounded, 'Kasir / POS'),
                          _buildDesktopNavItem(3, Icons.bar_chart_rounded, 'Laporan'),
                          _buildDesktopNavItem(4, Icons.people_rounded, 'Pelanggan'),
                          _buildDesktopNavItem(5, Icons.badge_rounded, 'Karyawan'),
                          _buildDesktopNavItem(6, Icons.settings_rounded, 'Pengaturan'),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderColor),
                    // User footer
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                            child: Text(
                              user.email.isNotEmpty ? user.email[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  user.role.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, size: 18, color: AppTheme.errorColor),
                            onPressed: () async {
                              await ref.read(currentUserProvider.notifier).signOut();
                              if (context.mounted) {
                                context.go('/login');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Main content area
              Expanded(
                child: Column(
                  children: [
                    // Top header bar on desktop
                    Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _currentIndex == 0
                                ? 'Ringkasan Bisnis'
                                : _currentIndex == 1
                                    ? 'Katalog Produk'
                                    : _currentIndex == 2
                                        ? 'Point of Sale'
                                        : _currentIndex == 3
                                            ? 'Laporan Penjualan'
                                            : _currentIndex == 4
                                                ? 'Data Pelanggan'
                                                : _currentIndex == 5
                                                    ? 'Data Karyawan'
                                                    : 'Pengaturan Outlet',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          summaryAsync.maybeWhen(
                            data: (summary) {
                              final notifs = (summary['notifications'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                              return IconButton(
                                icon: Badge(
                                  isLabelVisible: notifs.isNotEmpty,
                                  label: Text('${notifs.length}'),
                                  child: const Icon(Icons.notifications_none_rounded, color: AppTheme.textPrimary),
                                ),
                                onPressed: () => _showNotificationsSheet(notifs),
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: bodyContent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: AppDrawer(user: user),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'KasirGo',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppTheme.textPrimary,
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          summaryAsync.maybeWhen(
            data: (summary) {
              final notifs = (summary['notifications'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textPrimary),
                      onPressed: () => _showNotificationsSheet(notifs),
                    ),
                    if (notifs.isNotEmpty)
                      Positioned(
                        top: 6,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
                          ),
                          child: Text(
                            '${notifs.length > 9 ? "9+" : notifs.length}',
                            style: const TextStyle(
                              color: AppTheme.backgroundColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
            orElse: () => IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textPrimary),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: CentennialBackground(
        child: bodyContent,
      ),
      bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
    );
  }

  Widget _buildDesktopNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)) : null,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dense: true,
        leading: Icon(
          icon,
          size: 20,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
          ),
        ),
        onTap: () => setState(() => _currentIndex = index),
      ),
    );
  }

  Widget _buildDashboard(String displayName, AsyncValue<Map<String, dynamic>> summaryAsync) {
    return summaryAsync.when(
      loading: () => const _DashboardSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
      data: (summary) {
        final todaySales = (summary['todaySales'] as num?)?.toDouble() ?? 0;
        final todayCount = (summary['todayTransactions'] as num?)?.toInt() ?? 0;
        final productCount = (summary['products'] as num?)?.toInt() ?? 0;
        final customerCount = (summary['customers'] as num?)?.toInt() ?? 0;
        final allTransactions = (summary['allTransactions'] as List?) ?? [];

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            16,
            110,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  children: [
                    const TextSpan(text: 'Selamat datang, '),
                    TextSpan(
                      text: displayName.split(' ').first,
                      style: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Dashboard Owner',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _OutletTypeBadge(outletId: userOutletId()),
                ],
              ),
              const SizedBox(height: 20),
              _HeroSalesCard(sales: todaySales, txCount: todayCount),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      label: 'Transaksi',
                      value: '$todayCount',
                      icon: Icons.receipt_long_rounded,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiCard(
                      label: 'Produk Aktif',
                      value: '$productCount',
                      icon: Icons.inventory_2_rounded,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _KpiWideCard(
                label: 'Pelanggan Terdaftar',
                value: '$customerCount',
                icon: Icons.groups_rounded,
                color: AppTheme.successColor,
              ),
              const SizedBox(height: 28),
              _buildModularQuickActions(context, userOutletId()),
              const SizedBox(height: 28),
              const _SectionHeader(title: 'Penjualan 7 Hari Terakhir'),
              const SizedBox(height: 12),
              GlassCard(
                blur: 14,
                padding: const EdgeInsets.fromLTRB(12, 20, 16, 8),
                child: SizedBox(
                  height: 190,
                  child: _WeekChart(transactions: allTransactions),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SectionHeader(title: 'AI Co-Pilot'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppTheme.aiBadgeGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white, size: 11),
                        SizedBox(width: 4),
                        Text(
                          'AI ACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildAiInsights(summary),
            ],
          ),
        );
      },
    );
  }

  String userOutletId() {
    final user = ref.read(currentUserProvider);
    return user?.outletId ?? '';
  }

  Widget _buildAiInsights(Map<String, dynamic> summary) {
    final lowStock = summary['lowStockProducts'] as List? ?? [];
    final lowMargin = summary['lowMarginProducts'] as List? ?? [];
    final flashSale = summary['flashSaleProducts'] as List? ?? [];

    if (lowStock.isEmpty && lowMargin.isEmpty && flashSale.isEmpty) {
      return GlassCard(
        blur: 10,
        borderColor: AppTheme.successColor.withValues(alpha: 0.35),
        child: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppTheme.successColor, size: 26),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Semua aman! Tidak ada alert dari AI Co-Pilot.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (lowStock.isNotEmpty)
          _AICard(
            icon: Icons.warning_amber_rounded,
            color: AppTheme.errorColor,
            title: 'Stok Menipis (${lowStock.length} produk)',
            body: lowStock.take(3).map((p) => '${p.name}: ${p.stock} ${p.unit ?? "pcs"}').join('\n'),
          ),
        if (lowMargin.isNotEmpty)
          _AICard(
            icon: Icons.trending_down_rounded,
            color: AppTheme.warningColor,
            title: 'Margin Rendah (${lowMargin.length} produk)',
            body: lowMargin.take(3).map((p) => p.name as String).join(', '),
          ),
        if (flashSale.isNotEmpty)
          _AICard(
            icon: Icons.inventory_2_rounded,
            color: AppTheme.accentColor,
            title: 'Stok Menumpuk (${flashSale.length} produk)',
            body: flashSale.take(3).map((fs) {
              if (fs is Map<String, dynamic>) {
                return '${fs['productName']}: tidak ada transaksi ${fs['daysInactive']} hari (saran diskon ${fs['suggestedDiscount']}%)';
              }
              return (fs as Product).name;
            }).join('\n'),
          ),
      ],
    );
  }

  Widget _buildModularQuickActions(BuildContext context, String outletId) {
    final modules = ref.watch(activeModulesProvider(outletId));

    final quickActionItems = <Widget>[];

    if (modules.contains(BusinessModule.debt)) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.menu_book_rounded,
          title: 'Buku Kasbon',
          subtitle: 'Catat piutang',
          color: Colors.amber,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtScreen())),
        ),
      );
    }

    if (modules.contains(BusinessModule.ppob)) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.phone_android_rounded,
          title: 'PPOB & Pulsa',
          subtitle: 'Token PLN, pulsa',
          color: AppTheme.primaryColor,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PpobScreen())),
        ),
      );
    }

    if (modules.contains(BusinessModule.restockB2B)) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.local_shipping_rounded,
          title: 'Kulakan B2B',
          subtitle: 'Restock grosir',
          color: AppTheme.successColor,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RestockScreen())),
        ),
      );
    }

    if (modules.contains(BusinessModule.kitchenDisplay)) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.kitchen_rounded,
          title: 'Kitchen (KDS)',
          subtitle: 'Pesanan dapur',
          color: AppTheme.secondaryColor,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KitchenDisplayScreen())),
        ),
      );
    }

    quickActionItems.add(
      _ModuleCard(
        icon: Icons.mark_chat_unread_rounded,
        title: 'WA Marketing',
        subtitle: 'Broadcast & CRM',
        color: const Color(0xFF25D366),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WhatsappBroadcastScreen())),
      ),
    );

    quickActionItems.add(
      _ModuleCard(
        icon: Icons.hub_rounded,
        title: 'Social Commerce',
        subtitle: 'Sync Marketplace',
        color: Colors.deepOrange,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialCommerceScreen())),
      ),
    );

    quickActionItems.add(
      _ModuleCard(
        icon: Icons.qr_code_scanner_rounded,
        title: 'QR Meja Dine-in',
        subtitle: 'Self Order',
        color: AppTheme.accentColor,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrTableScreen())),
      ),
    );

    quickActionItems.add(
      _ModuleCard(
        icon: Icons.storefront_rounded,
        title: 'Katalog Online',
        subtitle: 'Web Katalog WA',
        color: AppTheme.primaryColor,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnlineCatalogScreen())),
      ),
    );

    quickActionItems.add(
      _ModuleCard(
        icon: Icons.health_and_safety_rounded,
        title: 'Health Score',
        subtitle: 'Diagnosa Bisnis',
        color: AppTheme.successColor,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthScoreScreen())),
      ),
    );

    quickActionItems.add(
      _ModuleCard(
        icon: Icons.favorite_rounded,
        title: 'Pendukung KasirGo',
        subtitle: 'Donasi Sukarela',
        color: Colors.amber,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupporterScreen())),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxis = constraints.maxWidth > 900 ? 5 : (constraints.maxWidth > 550 ? 4 : 2);
        final ratio = constraints.maxWidth > 550 ? 2.1 : 1.75;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Modul Bisnis KasirGo'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: crossAxis,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: ratio,
              children: quickActionItems,
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.72),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: AppTheme.accentColor,
            unselectedItemColor: AppTheme.textSecondary,
            selectedFontSize: 10.5,
            unselectedFontSize: 10,
            selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 10.5),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 10),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
              BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Produk'),
              BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_rounded), label: 'Kasir'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Laporan'),
              BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Pelanggan'),
              BottomNavigationBarItem(icon: Icon(Icons.badge_rounded), label: 'Karyawan'),
              BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Atur'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCountPill extends StatelessWidget {
  final int count;
  const _NotificationCountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppTheme.accentColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OutletTypeBadge extends ConsumerWidget {
  final String outletId;
  const _OutletTypeBadge({required this.outletId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outletType = ref.watch(outletTypeProvider(outletId));
    String label;
    switch (outletType.toLowerCase()) {
      case 'warteg':
        label = 'WARTEG';
        break;
      case 'cafe':
        label = 'CAFE & RESTO';
        break;
      case 'retail':
        label = 'RETAIL';
        break;
      default:
        label = 'KELONTONG';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.35),
            AppTheme.secondaryColor.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppTheme.accentColor,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _HeroSalesCard extends StatelessWidget {
  final double sales;
  final int txCount;

  const _HeroSalesCard({required this.sales, required this.txCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.55),
            AppTheme.secondaryColor.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PENJUALAN HARI INI',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 8),
                      MoneyText(value: Formatters.currency(sales), size: 32),
                      const SizedBox(height: 6),
                      Text(
                        '$txCount transaksi masuk',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: AppTheme.textPrimary,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: 10,
      padding: const EdgeInsets.all(16),
      borderColor: color.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppTheme.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _KpiWideCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiWideCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: 10,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderColor: color.withValues(alpha: 0.28),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _AICard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _AICard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        blur: 10,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        borderColor: color.withValues(alpha: 0.35),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: 8,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderColor: color.withValues(alpha: 0.25),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.10)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + kToolbarHeight + 8,
        16,
        110,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          CentennialSkeleton(height: 16, width: 160),
          SizedBox(height: 10),
          CentennialSkeleton(height: 30, width: 240),
          SizedBox(height: 22),
          CentennialSkeleton(height: 108),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: CentennialSkeleton(height: 120)),
              SizedBox(width: 12),
              Expanded(child: CentennialSkeleton(height: 120)),
            ],
          ),
          SizedBox(height: 12),
          CentennialSkeleton(height: 68),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  final List<dynamic> transactions;
  const _WeekChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final totals = List<double>.filled(7, 0);

    for (final t in transactions) {
      final createdAt = t.createdAt as DateTime;
      final diff = now.difference(DateTime(createdAt.year, createdAt.month, createdAt.day)).inDays;
      final idx = 6 - diff;
      if (idx >= 0 && idx <= 6) {
        totals[idx] += (t.finalAmount as num).toDouble();
      }
    }

    final maxYValue = totals.reduce((a, b) => a > b ? a : b);
    final chartMax = maxYValue <= 0 ? 10.0 : maxYValue * 1.2;
    final bars = List.generate(7, (i) {
      final dayIndex = (now.weekday - 1 - (6 - i) + 7) % 7;
      return _BarDatum(label: days[dayIndex], value: totals[i]);
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: chartMax,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= bars.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    bars[idx].label,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (index) {
          final v = bars[index].value <= 0 ? 0.02 : bars[index].value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: v,
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.45),
                    AppTheme.accentColor,
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _BarDatum {
  final String label;
  final double value;
  const _BarDatum({required this.label, required this.value});
}
