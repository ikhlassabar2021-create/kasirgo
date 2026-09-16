import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../utils/ai_engine.dart';
import '../../utils/subscription_gate.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/ad_banner_widget.dart';
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
  final tier = await SubscriptionGate.getOutletTier(user.outletId!);

  final todaySales = todayFiltered.fold<double>(0, (sum, t) => sum + t.finalAmount);
  final todayCount = todayFiltered.length;

  final ai = AIEngine();
  final lowStockProducts = products.where((p) => p.stock > 0 && p.stock <= 10).toList();
  final lowMarginProducts = products.where((p) {
    final m = ai.checkMargin(p);
    return m['isLowMargin'] == true && p.costPrice != null && p.costPrice! > 0;
  }).toList();
  final flashSale = ai.suggestFlashSale(products);

  return {
    'todaySales': todaySales,
    'todayTransactions': todayCount,
    'products': products.length,
    'customers': customers.length,
    'lowStockProducts': lowStockProducts,
    'lowMarginProducts': lowMarginProducts,
    'flashSaleProducts': flashSale,
    'allTransactions': todayTransactions,
    'allProducts': products,
    'tier': tier,
  };
});

class OwnerHomeScreen extends ConsumerStatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  ConsumerState<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends ConsumerState<OwnerHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final summaryAsync = ref.watch(homeSummaryProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('KasirGo'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      drawer: AppDrawer(user: user),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selamat Datang',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const Text(
              'Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            summaryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const SizedBox(),
              data: (summary) => Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Penjualan Hari Ini',
                      value: Formatters.currency(summary['todaySales'] ?? 0),
                      icon: Icons.trending_up,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Transaksi',
                      value: '${summary['todayTransactions'] ?? 0}',
                      icon: Icons.receipt_long,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            summaryAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (summary) => Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Produk',
                      value: '${summary['products'] ?? 0}',
                      icon: Icons.inventory_2,
                      color: AppTheme.accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Pelanggan',
                      value: '${summary['customers'] ?? 0}',
                      icon: Icons.people,
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Penjualan 7 Hari Terakhir',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.borderColor.withValues(alpha: 0.5),
                ),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 10,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
                          if (value.toInt() >= 0 &&
                              value.toInt() < days.length) {
                            return Text(
                              days[value.toInt()],
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    7,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: 0,
                          color: AppTheme.primaryColor,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'AI Co-Pilot',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            summaryAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (summary) {
                final lowStock = summary['lowStockProducts'] as List? ?? [];
                final lowMargin = summary['lowMarginProducts'] as List? ?? [];
                final flashSale = summary['flashSaleProducts'] as List? ?? [];
                if (lowStock.isEmpty && lowMargin.isEmpty && flashSale.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: AppTheme.successColor),
                        SizedBox(width: 12),
                        Expanded(child: Text('Semua aman! Tidak ada alert dari AI Co-Pilot.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
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
                        icon: Icons.trending_down,
                        color: Colors.orange,
                        title: 'Margin Rendah (${lowMargin.length} produk)',
                        body: lowMargin.take(3).map((p) => p.name as String).join(', '),
                      ),
                    if (flashSale.isNotEmpty)
                      _AICard(
                        icon: Icons.flash_on,
                        color: AppTheme.accentColor,
                        title: 'Saran Flash Sale (${flashSale.length} produk)',
                        body: flashSale.take(3).map((p) => p.name as String).join(', '),
                      ),
                  ],
                );
              },
            ),
            summaryAsync.maybeWhen(
              data: (summary) => AdBannerWidget(tier: summary['tier'] as String?),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
          const ProductListScreen(),
          const PosScreen(),
          const ReportScreen(),
          const CustomerListScreen(),
          const EmployeeScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, _currentIndex),
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        setState(() => _currentIndex = index);
      },
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Produk'),
        BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Kasir'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Laporan'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Pelanggan'),
        BottomNavigationBarItem(icon: Icon(Icons.badge), label: 'Karyawan'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Atur'),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}