import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../utils/ai_engine.dart';
import '../../widgets/common/app_drawer.dart';
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
      'color': Colors.redAccent,
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
  const OwnerHomeScreen({super.key});

  @override
  ConsumerState<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends ConsumerState<OwnerHomeScreen> {
  int _currentIndex = 0;

  void _showNotificationsDialog(BuildContext context, List<Map<String, dynamic>> notifications) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifikasi (${notifications.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: AppTheme.borderColor),
                if (notifications.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Tidak ada notifikasi saat ini.', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) => const Divider(color: AppTheme.borderColor, height: 1),
                      itemBuilder: (context, idx) {
                        final notif = notifications[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          leading: CircleAvatar(
                            backgroundColor: (notif['color'] as Color).withValues(alpha: 0.15),
                            child: Icon(notif['icon'] as IconData, color: notif['color'] as Color, size: 20),
                          ),
                          title: Text(
                            notif['title'] as String,
                            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
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
        );
      },
    );
  }

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
          summaryAsync.maybeWhen(
            data: (summary) {
              final notifs = (summary['notifications'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => _showNotificationsDialog(context, notifs),
                  ),
                  if (notifs.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '${notifs.length > 9 ? "9+" : notifs.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
            orElse: () => IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
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
                        icon: Icons.inventory_2_outlined,
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
              },
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