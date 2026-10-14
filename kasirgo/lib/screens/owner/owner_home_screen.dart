import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/module_provider.dart';
import 'design_studio_screen.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../utils/ai_engine.dart';
import '../../utils/qris_config.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/centennial_background.dart';
import '../../widgets/common/supporter_gate.dart';
// import 'social_commerce_screen.dart'; // HIDDEN per Item 14
import 'whatsapp_broadcast_screen.dart';
import 'qr_table_screen.dart';
import 'online_catalog_screen.dart';
import 'affiliate_owner_screen.dart';
import 'health_score_screen.dart';
import 'business_doctor_screen.dart';
import 'bundle_manager_screen.dart';
import 'lapak_live_screen.dart';
import '../../services/business_doctor_service.dart';
import '../modules/kitchen_display_screen.dart';
import 'shift_screen.dart';
import '../modules/supporter_screen.dart';
import 'pos_screen.dart';
import 'product_list_screen.dart';
import 'report_screen.dart';
import 'customer_list_screen.dart';
import 'employee_screen.dart';
import 'settings_screen.dart';
import 'guide_screen.dart';

final homeSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user?.outletId == null) return {};

  try {
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
  } catch (e) {
    return {
      'todaySales': 0.0,
      'todayTransactions': 0,
      'products': 0,
      'customers': 0,
      'lowStockProducts': [],
      'lowMarginProducts': [],
      'flashSaleProducts': [],
      'expiredProducts': [],
      'notifications': [],
      'allTransactions': [],
      'allProducts': [],
    };
  }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(currentUserProvider) == null) {
        ref.read(currentUserProvider.notifier).loadUser();
      }
    });
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

    final isDesktop = AppTheme.isDesktop(context);

    if (widget.subScreen != null) {
      return CentennialBackground(child: widget.subScreen!);
    }

    final bodyContent = IndexedStack(
          index: _currentIndex > 3 ? 0 : _currentIndex,
          children: [
            _buildDashboard(user.name ?? user.email, summaryAsync),
            const ProductListScreen(embedded: true),
            const PosScreen(embedded: true),
            const ReportScreen(embedded: true),
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
                width: AppTheme.sidebarWidth,
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
                          const SizedBox(height: 8),
                          const Divider(height: 1, color: AppTheme.borderColor),
                          const SizedBox(height: 8),
                          _buildDesktopActionItem(Icons.people_rounded, 'Pelanggan',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()))),
                          _buildDesktopActionItem(Icons.badge_rounded, 'Karyawan',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeScreen()))),
                          _buildDesktopActionItem(Icons.settings_rounded, 'Pengaturan',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
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
                      height: AppTheme.headerHeight,
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
                          constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
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
      backgroundColor: AppTheme.backgroundColor,
      drawer: AppDrawer(user: user),
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
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
          IconButton(
            tooltip: 'Panduan',
            icon: const Icon(Icons.help_outline_rounded, color: AppTheme.textPrimary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GuideScreen()),
            ),
          ),
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
        child: SafeArea(top: false, child: bodyContent),
      ),
      bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
    );
  }

  void _pushGated(String featureKey, Widget screen, {String? title}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupporterFeatureGate(
          featureKey: featureKey,
          title: title,
          child: screen,
        ),
      ),
    );
  }

  Widget _buildDesktopActionItem(IconData icon, String label, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          dense: true,
          leading: Icon(icon, size: 20, color: AppTheme.textSecondary),
          title: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          onTap: onTap,
        ),
      ),
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
      child: Material(
        type: MaterialType.transparency,
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
      ),
    );
  }

  Widget _buildDashboard(String displayName, AsyncValue<Map<String, dynamic>> summaryAsync) {
    return summaryAsync.when(
      loading: () => const _DashboardSkeleton(),
      error: (_, __) => _buildDashboardContent(displayName, {}),
      data: (summary) => _buildDashboardContent(displayName, summary),
    );
  }

  Widget _buildDashboardContent(String displayName, Map<String, dynamic> summary) {
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
              _OutletTypeSetupBanner(outletId: userOutletId()),
              _QrisSetupBanner(outletId: userOutletId()),
              const SizedBox(height: 16),
              _HeroSalesCard(
                sales: todaySales,
                txCount: todayCount,
                onKasir: () => setState(() => _currentIndex = 2),
                onOrders: () => setState(() => _currentIndex = 2),
                onReport: () => setState(() => _currentIndex = 3),
              ),
              const SizedBox(height: 12),
              _TargetProgressCard(sales: todaySales, outletId: userOutletId()),
              const SizedBox(height: 12),
              _MarketIntelCard(outletId: userOutletId()),
              const SizedBox(height: 12),
              _CrossSellCard(transactions: allTransactions, outletId: userOutletId()),
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

    quickActionItems.add(
      _ModuleCard(
        icon: Icons.medical_services_rounded,
        title: 'Dokter Bisnis AI',
        subtitle: 'Diagnosa & resep',
        color: const Color(0xFF4F46E5),
        onTap: () => _pushGated(
            'business_doctor', const BusinessDoctorScreen(),
            title: 'Dokter Bisnis AI'),
      ),
    );

    quickActionItems.add(
      _ModuleCard(
        icon: Icons.inventory_2_rounded,
        title: 'Paket Bundling',
        subtitle: 'Jual 1 harga',
        color: const Color(0xFF7C3AED),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BundleManagerScreen())),
      ),
    );

    quickActionItems.add(
      _ModuleCard(
        icon: Icons.location_on_rounded,
        title: 'Lapak Live',
        subtitle: 'Buka lapak & antrean',
        color: const Color(0xFF0D9488),
        onTap: () => _pushGated('lapak_live', const LapakLiveScreen(),
            title: 'Lapak Live'),
      ),
    );

    final ppobEnabled = ref.watch(ppobEnabledProvider).valueOrNull ?? true;

    // CATATAN (owner): fitur "Peta Ekspansi" dan "Referral" dihapus dari UI
    // sesuai permintaan; layar & service tetap ada untuk masa depan.

    if (modules.contains(BusinessModule.ppob) && ppobEnabled) {
      // CATATAN (owner): PPOB & Pulsa disembunyikan dari dashboard sesuai permintaan.
    }

    if (modules.contains(BusinessModule.restockB2B)) {
      // CATATAN (owner): Kulakan B2B disembunyikan dari dashboard sesuai permintaan.
    }

    if (ref.watch(fintechEnabledProvider).valueOrNull ?? true) {
      // CATATAN (owner): Modal Usaha disembunyikan dari dashboard sesuai permintaan.
    }


    // KDS & QR Meja hanya untuk usaha makanan/minuman (cafe/warteg/restoran).
    // Warung/kelontong/retail/gerobak bukan usaha makan -> QR Meja & KDS off
    // walau ada override module_tableManagement di DB.
    final outletType =
        ModuleConfig.normalizeType(ref.watch(outletTypeProvider(outletId)));
    final isFoodBusiness = outletType == 'cafe' || outletType == 'warteg';
    final kdsAllowed = isFoodBusiness;

    if (kdsAllowed && modules.contains(BusinessModule.kitchenDisplay)) {
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
        icon: Icons.point_of_sale_rounded,
        title: 'Shift Kasir',
        subtitle: 'Setoran & selisih',
        color: AppTheme.secondaryColor,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShiftScreen())),
      ),
    );


    // Squad DM (Digital Marketing AI) — default OFF, diaktifkan superadmin
    // via Control Plane (platform_configs 'digital_marketing_llm'.aktif).
    final dmEnabled = ref.watch(dmEnabledProvider).valueOrNull ?? false;
    if (dmEnabled) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.campaign_rounded,
          title: 'Squad DM',
          subtitle: 'Desain & Promosi AI',
          color: const Color(0xFFDB2777),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DesignStudioScreen())),
        ),
      );
    }

    quickActionItems.add(
      _ModuleCard(
        icon: Icons.mark_chat_unread_rounded,
        title: 'WA Marketing',
        subtitle: 'Broadcast & CRM',
        color: AppTheme.whatsAppColor,
        onTap: () => _pushGated('wa_marketing', const WhatsappBroadcastScreen(),
            title: 'WA Marketing'),
      ),
    );

    // quickActionItems.add(
    //   _ModuleCard(
    //     icon: Icons.hub_rounded,
    //     title: 'Social Commerce',
    //     subtitle: 'Sync Marketplace',
    //     color: AppTheme.secondaryColor,
    //     onTap: () => _pushGated('social_sync', const SocialCommerceScreen(),
    //         title: 'Social Commerce'),
    //   ),
    // ); // Hidden per Item 14

    if (isFoodBusiness && modules.contains(BusinessModule.tableManagement)) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'QR Meja Dine-in',
          subtitle: 'Self Order',
          color: AppTheme.accentColor,
          onTap: () => _pushGated('qr_table', const QrTableScreen(),
              title: 'QR Meja Dine-in'),
        ),
      );
    }

    quickActionItems.add(
      _ModuleCard(
        icon: Icons.storefront_rounded,
        title: 'Katalog Online',
        subtitle: 'Web Katalog WA',
        color: AppTheme.primaryColor,
        onTap: () => _pushGated('online_catalog', const OnlineCatalogScreen(),
            title: 'Katalog Online'),
      ),
    );

    quickActionItems.add(
      _ModuleCard(
        icon: Icons.health_and_safety_rounded,
        title: 'Health Score',
        subtitle: 'Diagnosa Bisnis',
        color: AppTheme.successColor,
        onTap: () => _pushGated('health_score_pro', const HealthScoreScreen(),
            title: 'Health Score Bisnis'),
      ),
    );

    quickActionItems.add(
      _ModuleCard(
        icon: Icons.favorite_rounded,
        title: 'Pendukung KasirGo',
        subtitle: 'Dukung Pengembangan',
        color: AppTheme.warningColor,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupporterScreen())),
      ),
    );

    quickActionItems.add(
      _ModuleCard(
        icon: Icons.handshake_rounded,
        title: 'Afiliasi',
        subtitle: 'Komisi Referral',
        color: AppTheme.accentColor,
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AffiliateOwnerScreen())),
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
    // Design System v3: Bottom nav solid putih (tanpa blur) 5 titik ala GoPay
    // Merchant: Beranda, Produk, [Kasir menonjol], Laporan, Lainnya.
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _navItem(0, Icons.home_rounded, 'Beranda'),
              _navItem(1, Icons.inventory_2_rounded, 'Produk'),
              _centerPosButton(),
              _navItem(3, Icons.bar_chart_rounded, 'Laporan'),
              _navItem(-1, Icons.grid_view_rounded, 'Lainnya'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = index >= 0 && _currentIndex == index;
    final color = selected ? AppTheme.primaryColor : AppTheme.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (index == -1) {
            _openMoreMenu();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerPosButton() {
    final selected = _currentIndex == 2;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: const Icon(Icons.point_of_sale_rounded,
                  size: 20, color: Colors.white),
            ),
            const SizedBox(height: 3),
            Text(
              'Kasir',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.secondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Modal "Lainnya": sisa menu (Pelanggan, Karyawan, Pengaturan, Panduan).
  void _openMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _moreTile(ctx, Icons.people_rounded, 'Pelanggan', () {
              Navigator.pop(ctx);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CustomerListScreen()));
            }),
            _moreTile(ctx, Icons.badge_rounded, 'Karyawan', () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EmployeeScreen()));
            }),
            _moreTile(ctx, Icons.settings_rounded, 'Pengaturan', () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),
            _moreTile(ctx, Icons.menu_book_rounded, 'Panduan', () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GuideScreen()));
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _moreTile(
      BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
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
    switch (ModuleConfig.normalizeType(outletType)) {
      case 'warteg':
        label = 'WARTEG';
        break;
      case 'cafe':
        label = 'CAFE & RESTO';
        break;
      case 'retail':
        label = 'RETAIL';
        break;
      case 'gerobak':
        label = 'GEROBAK';
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

class _QrisSetupBanner extends ConsumerStatefulWidget {
  final String outletId;

  const _QrisSetupBanner({required this.outletId});

  @override
  ConsumerState<_QrisSetupBanner> createState() => _QrisSetupBannerState();
}

class _QrisSetupBannerState extends ConsumerState<_QrisSetupBanner> {
  bool? _configured;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await QrisConfig.load(outletId: widget.outletId);
    if (!mounted) return;
    setState(() => _configured = config.isConfigured);
  }

  @override
  Widget build(BuildContext context) {
    if (_configured == null) return const SizedBox.shrink();
    if (_configured == true) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.qr_code_2_rounded, color: AppTheme.warningColor, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atur QRIS Toko Anda',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Supaya pelanggan bisa bayar QRIS. Isi Nama Merchant, NMID & Bank/E-Wallet.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              context.push('/owner/settings');
            },
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Atur',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutletTypeSetupBanner extends ConsumerStatefulWidget {
  final String outletId;
  const _OutletTypeSetupBanner({required this.outletId});

  @override
  ConsumerState<_OutletTypeSetupBanner> createState() =>
      _OutletTypeSetupBannerState();
}

class _OutletTypeSetupBannerState
    extends ConsumerState<_OutletTypeSetupBanner> {
  bool _saving = false;

  Future<void> _pickType() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Pilih Tipe Usaha',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AppConstants.businessTypes
                  .map((t) => ListTile(
                        dense: true,
                        title: Text(t,
                            style: const TextStyle(
                                color: AppTheme.textPrimary, fontSize: 14)),
                        onTap: () => Navigator.pop(ctx, t),
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );

    if (selected == null) return;
    setState(() => _saving = true);
    final ok = await SupabaseService()
        .updateOutletType(outletId: widget.outletId, businessType: selected);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      // Muat ulang tipe outlet agar modul langsung menyesuaikan.
      ref.invalidate(outletProvider(widget.outletId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tipe usaha disimpan: $selected'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan tipe usaha'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final outletType = ref.watch(outletTypeProvider(widget.outletId));
    // Hanya tampilkan bila tipe outlet masih default/kosong.
    final raw = outletType.trim().toLowerCase();
    final isUnset = raw.isEmpty || raw == 'warung' || raw == 'toko baru';
    if (!isUnset) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: AppTheme.accentColor, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lengkapi Tipe Usaha Anda',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Pilih tipe usaha agar fitur yang tampil sesuai (Warung, Gerobak, Cafe, dll).',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _saving ? null : _pickType,
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Pilih',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _HeroSalesCard extends StatelessWidget {
  final double sales;
  final int txCount;
  final VoidCallback? onKasir;
  final VoidCallback? onOrders;
  final VoidCallback? onReport;

  const _HeroSalesCard({
    required this.sales,
    required this.txCount,
    this.onKasir,
    this.onOrders,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    // Design System v3 - "GoPay Balance Card": kartu putih, aksen atas cyan.
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 5,
              decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded,
                          size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'OMZET HARI INI',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Formatters.currency(sales),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$txCount produk terjual hari ini',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _quickAction(Icons.point_of_sale_rounded, 'Buka Kasir',
                          AppTheme.secondaryColor, onKasir),
                      const SizedBox(width: 8),
                      _quickAction(Icons.receipt_long_rounded, 'Pesanan Masuk',
                          AppTheme.primaryColor, onOrders),
                      const SizedBox(width: 8),
                      _quickAction(Icons.bar_chart_rounded, 'Laporan',
                          AppTheme.accentColor, onReport),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(
      IconData icon, String label, Color color, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetProgressCard extends StatefulWidget {
  final double sales;
  final String outletId;

  const _TargetProgressCard({required this.sales, required this.outletId});

  @override
  State<_TargetProgressCard> createState() => _TargetProgressCardState();
}

class _TargetProgressCardState extends State<_TargetProgressCard> {
  Map<String, dynamic>? _target;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTarget();
  }

  Future<void> _loadTarget() async {
    try {
      final list = await BusinessDoctorService().getTargets(widget.outletId);
      if (mounted) {
        setState(() {
          _target = list.isNotEmpty ? list.first : null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final targetAmount = (_target?['target_amount'] as num?)?.toDouble() ?? 0;
    if (targetAmount <= 0) {
      // Belum ada target aktif -> tampilkan kartu ajakan pasang target.
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.flag_rounded, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pasang Target Omzet Harian',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  Text(
                    'Minta AI hitung target realistis toko kamu',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessDoctorScreen()));
              },
              child: const Text('Konsultasi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    final progress = (widget.sales / targetAmount).clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();
    final hour = DateTime.now().hour;
    // Pace Alert: jam 14:00+ tapi capaian di bawah 50%
    final isPaceAlert = hour >= 14 && progress < 0.50;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaceAlert ? AppTheme.warningColor : AppTheme.borderColor,
          width: isPaceAlert ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes_rounded, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Target Omzet Hari Ini',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ),
              if (isPaceAlert)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFD97706)),
                      SizedBox(width: 4),
                      Text(
                        'Pace Alert: Laju Lambat',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  '$percent%',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                isPaceAlert ? AppTheme.warningColor : (progress >= 1.0 ? AppTheme.successColor : AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tercapai: ${Formatters.currency(widget.sales)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              Text(
                'Target: ${Formatters.currency(targetAmount)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarketIntelCard extends StatefulWidget {
  final String outletId;
  const _MarketIntelCard({required this.outletId});

  @override
  State<_MarketIntelCard> createState() => _MarketIntelCardState();
}

class _MarketIntelCardState extends State<_MarketIntelCard> {
  Map<String, dynamic>? _intel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadIntel();
  }

  Future<void> _loadIntel() async {
    try {
      final list = await BusinessDoctorService().getMarketIntel(widget.outletId);
      if (mounted) {
        setState(() {
          _intel = list.isNotEmpty ? list.first : null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _intel == null) return const SizedBox.shrink();

    final title = _intel?['title']?.toString() ?? 'Intelijen Pasar';
    final content = _intel?['content']?.toString() ?? '';
    final createdAt = _intel?['created_at']?.toString() ?? '';
    final dateStr = createdAt.length >= 10 ? createdAt.substring(0, 10) : '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, size: 18, color: AppTheme.successColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
              if (dateStr.isNotEmpty)
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF15803D)),
                ),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF166534)),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                // Arahkan ke tab Produk (index 1)
                final state = context.findAncestorStateOfType<_OwnerHomeScreenState>();
                if (state != null) {
                  state.setState(() => state._currentIndex = 1);
                }
              },
              icon: const Icon(Icons.sell_rounded, size: 14),
              label: const Text('Terapkan ke Harga'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrossSellCard extends StatelessWidget {
  final List<dynamic> transactions;
  final String outletId;

  const _CrossSellCard({required this.transactions, required this.outletId});

  @override
  Widget build(BuildContext context) {
    // Hitung keranjang dari transaksi yang dimuat dashboard.
    final baskets = <String, Set<String>>{};
    final nameOf = <String, String>{};
    for (final tx in transactions) {
      try {
        final items = (tx.items as List);
        final set = <String>{};
        for (final it in items) {
          final pid = it.productId?.toString() ?? '';
          if (pid.isEmpty) continue;
          set.add(pid);
          nameOf[pid] = it.productName?.toString() ?? pid;
        }
        if (set.isNotEmpty) baskets['${tx.id}'] = set;
      } catch (_) {}
    }
    if (baskets.length < 2) return const SizedBox.shrink();

    final rules = AIEngine().crossSellRules(
      baskets.values.map((s) => s.toList()).toList(),
      minSupport: 1,
      topN: 3,
    );
    if (rules.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Peluang Cross-Sell',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('AI',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD97706))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rules.map((r) {
            final from = nameOf[r['antecedent']?.toString()] ?? 'Produk';
            final to = nameOf[r['consequent']?.toString()] ?? 'Produk';
            final conf = ((r['confidence'] as double) * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Beli "$from" → tawarkan "$to"',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                  Text('$conf%',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD97706))),
                ],
              ),
            );
          }),
        ],
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
    // Design System v3: kartu putih ringkas - ikon bulat 40dp di kiri.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppTheme.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
    // Design System v3: gaya ikon super-app GoPay - ikon dalam lingkaran
    // pastel lembut, label di bawahnya.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: AppTheme.shadowSoft,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
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
