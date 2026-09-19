import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/module_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../utils/ai_engine.dart';
import '../../widgets/common/app_drawer.dart';
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
            _buildModularQuickActions(context, user.outletId ?? ''),
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

  Widget _buildModularQuickActions(BuildContext context, String outletId) {
    final outletType = ref.watch(outletTypeProvider(outletId));
    final modules = ref.watch(activeModulesProvider(outletId));

    String typeLabel;
    switch (outletType.toLowerCase()) {
      case 'warteg':
        typeLabel = 'Warteg / Rumah Makan';
        break;
      case 'cafe':
        typeLabel = 'Cafe & Resto';
        break;
      case 'retail':
        typeLabel = 'Retail / Toko';
        break;
      case 'kelontong':
      default:
        typeLabel = 'Warung Kelontong';
        break;
    }

    final quickActionItems = <Widget>[];

    // Kelontong & Retail: Grosir
    if (modules.contains(BusinessModule.wholesalePrice)) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.price_change,
          title: 'Harga Grosir',
          subtitle: 'Grosir berjenjang',
          color: AppTheme.accentColor,
          onTap: () {
            setState(() => _currentIndex = 1); // Go to Produk
          },
        ),
      );
    }

    // Kelontong & Warteg: Kasbon
    if (modules.contains(BusinessModule.debt)) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.menu_book,
          title: 'Buku Kasbon',
          subtitle: 'Catat piutang',
          color: Colors.amber,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtScreen()));
          },
        ),
      );
    }

    // Kelontong & Retail: PPOB
    if (modules.contains(BusinessModule.ppob)) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.phone_android,
          title: 'PPOB & Pulsa',
          subtitle: 'Token PLN, pulsa',
          color: AppTheme.primaryColor,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PpobScreen()));
          },
        ),
      );
    }

    // Kelontong & Retail: Kulakan B2B
    if (modules.contains(BusinessModule.restockB2B)) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.local_shipping,
          title: 'Kulakan B2B',
          subtitle: 'Restock grosir',
          color: AppTheme.successColor,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const RestockScreen()));
          },
        ),
      );
    }

    // Warteg: Resep / Bahan Baku Porsi
    if (outletType.toLowerCase() == 'warteg' && modules.contains(BusinessModule.recipeIngredients)) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.soup_kitchen,
          title: 'Porsi & Bahan',
          subtitle: 'Pantau stok porsi',
          color: Colors.orange,
          onTap: () {
            setState(() => _currentIndex = 1); // Produk/Menu
          },
        ),
      );
    }

    // Warteg: Shift Kasir
    if (outletType.toLowerCase() == 'warteg') {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.schedule,
          title: 'Shift Kasir',
          subtitle: 'Rekap pergantian shift',
          color: AppTheme.secondaryColor,
          onTap: () {
            setState(() => _currentIndex = 3); // Laporan/Shift
          },
        ),
      );
    }

    // Cafe & Warteg: Kitchen KDS
    if (modules.contains(BusinessModule.kitchenDisplay)) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.kitchen,
          title: 'Kitchen (KDS)',
          subtitle: 'Layar pesanan dapur',
          color: AppTheme.secondaryColor,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const KitchenDisplayScreen()));
          },
        ),
      );
    }

    // Cafe: QR Meja & Table Management
    if (modules.contains(BusinessModule.tableManagement)) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.table_restaurant,
          title: 'QR Meja',
          subtitle: 'Dine-in self order',
          color: AppTheme.accentColor,
          onTap: () {
            setState(() => _currentIndex = 2); // Kasir / POS
          },
        ),
      );
    }

    // Cafe: Split Bill & Tip
    if (modules.contains(BusinessModule.splitBill)) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.call_split,
          title: 'Split Bill & Tip',
          subtitle: 'Bagi bayar pesanan',
          color: Colors.pinkAccent,
          onTap: () {
            setState(() => _currentIndex = 2); // Kasir / POS
          },
        ),
      );
    }

    // Retail & Cafe: Varian / Multi-variant
    if (modules.contains(BusinessModule.variants)) {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.style,
          title: 'Multi Varian',
          subtitle: 'Ukuran, rasa, warna',
          color: Colors.teal,
          onTap: () {
            setState(() => _currentIndex = 1); // Produk
          },
        ),
      );
    }

    // Retail: Barcode & CRM
    if (outletType.toLowerCase() == 'retail') {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.loyalty,
          title: 'CRM Pelanggan',
          subtitle: 'Poin & loyalitas',
          color: AppTheme.successColor,
          onTap: () {
            setState(() => _currentIndex = 4); // Pelanggan
          },
        ),
      );
    }

    // Integrasi Phase 6: WhatsApp Broadcast & CRM
    quickActionItems.add(
      _ModuleCard(
        icon: Icons.mark_chat_unread,
        title: 'WhatsApp Marketing',
        subtitle: 'Broadcast & Retensi',
        color: const Color(0xFF25D366),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const WhatsappBroadcastScreen()));
        },
      ),
    );

    // Integrasi Phase 6: Social Commerce
    quickActionItems.add(
      _ModuleCard(
        icon: Icons.hub,
        title: 'Social Commerce',
        subtitle: 'Sync Tokopedia/Shopee',
        color: Colors.deepOrange,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialCommerceScreen()));
        },
      ),
    );

    // Integrasi Phase 6: QR Meja
    if (outletType.toLowerCase() == 'cafe' || outletType.toLowerCase() == 'warteg') {
      quickActionItems.add(
        _ModuleCard(
          icon: Icons.qr_code_scanner,
          title: 'QR Meja Dine-in',
          subtitle: 'Scan & Order Meja',
          color: AppTheme.accentColor,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const QrTableScreen()));
          },
        ),
      );
    }

    // Integrasi Phase 6: Toko Online Katalog
    quickActionItems.add(
      _ModuleCard(
        icon: Icons.store,
        title: 'Katalog Online',
        subtitle: 'Web katalog & WA',
        color: Colors.blueAccent,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const OnlineCatalogScreen()));
        },
      ),
    );

    // Integrasi Phase 6: Health Score & Cashflow
    quickActionItems.add(
      _ModuleCard(
        icon: Icons.health_and_safety,
        title: 'Health Score',
        subtitle: 'Diagnosa & Cashflow',
        color: AppTheme.successColor,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthScoreScreen()));
        },
      ),
    );

    // Selalu tampilkan Program Pendukung
    quickActionItems.add(
      _ModuleCard(
        icon: Icons.favorite,
        title: 'Pendukung KasirGo',
        subtitle: 'Rp0 tanpa paywall',
        color: Colors.amber,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SupporterScreen()));
        },
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Modul Bisnis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                typeLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: quickActionItems,
        ),
      ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}