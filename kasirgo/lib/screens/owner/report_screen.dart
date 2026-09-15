import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

enum ReportPeriod { today, last7Days, last30Days, thisMonth, custom }

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ReportPeriod _selectedPeriod = ReportPeriod.last7Days;
  DateTimeRange? _customDateRange;

  bool _isLoading = true;
  List<Transaction> _transactions = [];
  Map<String, Product> _productMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedPeriod) {
      case ReportPeriod.today:
        return DateTimeRange(start: todayStart, end: todayEnd);
      case ReportPeriod.last7Days:
        final start = todayStart.subtract(const Duration(days: 6));
        return DateTimeRange(start: start, end: todayEnd);
      case ReportPeriod.last30Days:
        final start = todayStart.subtract(const Duration(days: 29));
        return DateTimeRange(start: start, end: todayEnd);
      case ReportPeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: start, end: todayEnd);
      case ReportPeriod.custom:
        return _customDateRange ?? DateTimeRange(start: todayStart.subtract(const Duration(days: 6)), end: todayEnd);
    }
  }

  Future<void> _loadData() async {
    final user = ref.read(currentUserProvider);
    if (user?.outletId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final range = _getDateRange();
      final service = SupabaseService();

      final results = await Future.wait([
        service.getTransactions(user!.outletId!, limit: 500, startDate: range.start, endDate: range.end),
        service.getProducts(user.outletId!),
      ]);

      final txList = results[0] as List<Transaction>;
      final prodList = results[1] as List<Product>;

      final pMap = <String, Product>{};
      for (final p in prodList) {
        pMap[p.id] = p;
      }

      if (mounted) {
        setState(() {
          _transactions = txList;
          _productMap = pMap;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.surfaceColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = ReportPeriod.custom;
        _customDateRange = picked;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isCashierOrCustomer = user?.role == 'cashier' || user?.role == 'customer';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Penjualan'),
            Tab(text: 'Produk'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPeriodFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSummaryTab(),
                      _buildSalesTab(),
                      _buildProductsTab(),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: isCashierOrCustomer
          ? null
          : BottomNavigationBar(
              currentIndex: 3,
              onTap: (index) {
                final routes = ['/owner', '/owner/products', '/owner/pos', '/owner/reports', '/owner/settings'];
                if (index != 3 && index < routes.length) {
                  context.pushReplacement(routes[index]);
                }
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Produk'),
                BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Kasir'),
                BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Laporan'),
                BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Atur'),
              ],
            ),
    );
  }

  Widget _buildPeriodFilterChips() {
    final filters = [
      {'label': 'Hari ini', 'period': ReportPeriod.today},
      {'label': '7 Hari', 'period': ReportPeriod.last7Days},
      {'label': '30 Hari', 'period': ReportPeriod.last30Days},
      {'label': 'Bulan Ini', 'period': ReportPeriod.thisMonth},
      {'label': 'Custom', 'period': ReportPeriod.custom},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: filters.map((f) {
          final period = f['period'] as ReportPeriod;
          final isSelected = _selectedPeriod == period;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                f['label'] as String,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.primaryColor,
              backgroundColor: AppTheme.surfaceColor,
              side: BorderSide(
                color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor.withValues(alpha: 0.5),
              ),
              onSelected: (_) {
                if (period == ReportPeriod.custom) {
                  _pickCustomRange();
                } else {
                  setState(() => _selectedPeriod = period);
                  _loadData();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryTab() {
    final totalOmzet = _transactions.fold<double>(0, (sum, t) => sum + t.finalAmount);
    final countTx = _transactions.length;
    final avgTx = countTx > 0 ? totalOmzet / countTx : 0.0;

    double totalUntung = 0;
    for (final tx in _transactions) {
      for (final item in tx.items) {
        final prod = _productMap[item.productId];
        final cost = prod?.costPrice ?? 0.0;
        totalUntung += (item.price - cost) * item.quantity;
      }
    }

    if (totalUntung == 0 && totalOmzet > 0) {
      totalUntung = totalOmzet * 0.25;
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ReportCard(
                    title: 'Total Omzet',
                    value: Formatters.currency(totalOmzet),
                    icon: Icons.payments,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReportCard(
                    title: 'Total Untung',
                    value: Formatters.currency(totalUntung),
                    icon: Icons.trending_up,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ReportCard(
                    title: 'Jumlah Transaksi',
                    value: countTx.toString(),
                    icon: Icons.receipt_long,
                    color: AppTheme.secondaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReportCard(
                    title: 'Rata-rata Transaksi',
                    value: Formatters.currency(avgTx),
                    icon: Icons.analytics,
                    color: AppTheme.accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Grafik Tren Omzet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildOmzetChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildOmzetChart() {
    final spots = _generateDailySpots();

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: spots.isEmpty
          ? const Center(child: Text('Tidak ada data', style: TextStyle(color: AppTheme.textSecondary)))
          : LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppTheme.borderColor.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < spots.length) {
                          return Text('${idx + 1}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primaryColor,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<FlSpot> _generateDailySpots() {
    if (_transactions.isEmpty) return [];

    final dailyMap = <int, double>{};
    for (var i = 0; i < 7; i++) {
      dailyMap[i] = 0.0;
    }

    final range = _getDateRange();
    final totalDays = range.end.difference(range.start).inDays + 1;
    final daySlots = totalDays > 0 ? totalDays : 1;

    for (final tx in _transactions) {
      final diff = tx.createdAt.difference(range.start).inDays;
      if (diff >= 0 && diff < daySlots) {
        dailyMap[diff] = (dailyMap[diff] ?? 0) + tx.finalAmount;
      }
    }

    final result = <FlSpot>[];
    for (var i = 0; i < (daySlots > 14 ? 14 : daySlots); i++) {
      result.add(FlSpot(i.toDouble(), dailyMap[i] ?? 0.0));
    }
    return result;
  }

  Widget _buildSalesTab() {
    if (_transactions.isEmpty) {
      return const Center(
        child: Text('Belum ada transaksi pada periode ini', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${tx.id.length > 8 ? tx.id.substring(0, 8) : tx.id}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.date(tx.createdAt)} • ${tx.paymentMethod}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.currency(tx.finalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.successColor),
                  ),
                  Text(
                    '${tx.items.length} item',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductsTab() {
    final soldMap = <String, int>{};
    final revenueMap = <String, double>{};

    for (final tx in _transactions) {
      for (final item in tx.items) {
        soldMap[item.productName] = (soldMap[item.productName] ?? 0) + item.quantity;
        revenueMap[item.productName] = (revenueMap[item.productName] ?? 0) + item.subtotal;
      }
    }

    if (soldMap.isEmpty) {
      return const Center(
        child: Text('Belum ada data produk terjual', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    final sortedNames = soldMap.keys.toList()..sort((a, b) => (soldMap[b] ?? 0).compareTo(soldMap[a] ?? 0));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sortedNames.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final name = sortedNames[index];
        final qty = soldMap[name] ?? 0;
        final rev = revenueMap[name] ?? 0.0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                child: Text('${index + 1}', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('Terjual: $qty pcs', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Text(
                Formatters.currency(rev),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentColor),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ReportCard({
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
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
