import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

class HealthScoreScreen extends ConsumerStatefulWidget {
  const HealthScoreScreen({super.key});

  @override
  ConsumerState<HealthScoreScreen> createState() => _HealthScoreScreenState();
}

class _HealthScoreScreenState extends ConsumerState<HealthScoreScreen> {
  final _service = SupabaseService();
  bool _isLoading = true;

  double _healthScore = 0;
  double _revenueTrendScore = 0;
  double _retentionScore = 0;
  double _inventoryScore = 0;
  double _marginScore = 0;
  double _growthScore = 0;

  double _totalReceivables = 0;
  double _weeklyRunRate = 0;

  @override
  void initState() {
    super.initState();
    _calculateHealthScore();
  }

  Future<void> _calculateHealthScore() async {
    final user = ref.read(currentUserProvider);
    if (user?.outletId == null) return;
    setState(() => _isLoading = true);

    final outletId = user!.outletId!;
    final transactions = await _service.getTransactions(outletId, limit: 300);
    final products = await _service.getProducts(outletId);
    final customers = await _service.getCustomers(outletId);
    final debts = await _service.getDebts(outletId);

    final now = DateTime.now();
    final d30Ago = now.subtract(const Duration(days: 30));
    final d60Ago = now.subtract(const Duration(days: 60));
    final d7Ago = now.subtract(const Duration(days: 7));

    // Revenue 30d vs previous 30d (weight: 30%)
    final tLast30 = transactions.where((t) => t.createdAt.isAfter(d30Ago)).toList();
    final tPrev30 = transactions
        .where((t) => t.createdAt.isAfter(d60Ago) && t.createdAt.isBefore(d30Ago))
        .toList();

    final revLast30 = tLast30.fold<double>(0, (sum, t) => sum + t.finalAmount);
    final revPrev30 = tPrev30.fold<double>(0, (sum, t) => sum + t.finalAmount);

    if (revPrev30 > 0) {
      final ratio = revLast30 / revPrev30;
      _revenueTrendScore = (ratio * 100).clamp(0.0, 100.0);
    } else {
      _revenueTrendScore = revLast30 > 0 ? 85.0 : 50.0;
    }

    // Customer retention (weight: 25%)
    final activeCustomers = customers.where((c) {
      if (c.lastVisit == null) return false;
      return c.lastVisit!.isAfter(d30Ago);
    }).length;
    _retentionScore = customers.isNotEmpty
        ? ((activeCustomers / customers.length) * 100).clamp(0.0, 100.0)
        : 70.0;

    // Inventory turnover / Dead stock ratio (weight: 20%)
    final activeStockProducts = products.where((p) => p.stock > 0).length;
    _inventoryScore = products.isNotEmpty
        ? ((activeStockProducts / products.length) * 100).clamp(0.0, 100.0)
        : 80.0;

    // Margin health (weight: 15%)
    final productsWithCost = products.where((p) => p.costPrice != null && p.costPrice! > 0).toList();
    if (productsWithCost.isNotEmpty) {
      final healthyMarginCount = productsWithCost.where((p) {
        final margin = (p.price - p.costPrice!) / p.price;
        return margin >= 0.15; // At least 15% margin
      }).length;
      _marginScore = ((healthyMarginCount / productsWithCost.length) * 100).clamp(0.0, 100.0);
    } else {
      _marginScore = 75.0;
    }

    // Transaction volume growth (weight: 10%)
    if (tPrev30.isNotEmpty) {
      _growthScore = ((tLast30.length / tPrev30.length) * 100).clamp(0.0, 100.0);
    } else {
      _growthScore = tLast30.isNotEmpty ? 80.0 : 50.0;
    }

    // Overall Health Score (0 - 100)
    _healthScore = (_revenueTrendScore * 0.30) +
        (_retentionScore * 0.25) +
        (_inventoryScore * 0.20) +
        (_marginScore * 0.15) +
        (_growthScore * 0.10);

    // Cashflow metrics
    _totalReceivables = debts
        .where((d) => d.status == 'unpaid' || d.status == 'partial')
        .fold<double>(0, (sum, d) => sum + (d.amount - d.paidAmount));

    final tLast7 = transactions.where((t) => t.createdAt.isAfter(d7Ago)).toList();
    _weeklyRunRate = tLast7.fold<double>(0, (sum, t) => sum + t.finalAmount);

    setState(() => _isLoading = false);
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return AppTheme.successColor;
    if (score >= 60) return Colors.amber;
    return AppTheme.errorColor;
  }

  String _getScoreStatus(double score) {
    if (score >= 80) return 'Sangat Sehat';
    if (score >= 60) return 'Cukup Sehat';
    return 'Perlu Perhatian';
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _getScoreColor(_healthScore);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Health Score & Cashflow'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scoreColor.withValues(alpha: 0.2),
                          AppTheme.surfaceColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Business Health Score',
                          style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _healthScore.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getScoreStatus(_healthScore),
                            style: TextStyle(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Komponen Penilaian (AI Diagnostics)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricRow('Tren Omset (30 hari)', _revenueTrendScore, 30),
                  _buildMetricRow('Retensi Pelanggan', _retentionScore, 25),
                  _buildMetricRow('Perputaran Stok Barang', _inventoryScore, 20),
                  _buildMetricRow('Kesehatan Margin Produk', _marginScore, 15),
                  _buildMetricRow('Pertumbuhan Transaksi', _growthScore, 10),
                  const SizedBox(height: 24),
                  const Text(
                    'Proyeksi Cashflow & Likuiditas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Piutang (Kasbon)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              const SizedBox(height: 6),
                              Text(
                                Formatters.currency(_totalReceivables),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.amber),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Omset 7 Hari Terakhir', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              const SizedBox(height: 6),
                              Text(
                                Formatters.currency(_weeklyRunRate),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.accentColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricRow(String label, double score, int weight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$label (Bobot $weight%)', style: const TextStyle(fontSize: 13)),
              Text('${score.toStringAsFixed(0)}/100', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              backgroundColor: AppTheme.surfaceColor,
              valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(score)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
