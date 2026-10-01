import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/shift.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/logout_button.dart';
import '../../widgets/common/responsive.dart';

/// Laporan ringkas untuk kasir: penjualan hari ini / mingguan / bulanan
/// plus ringkasan shift aktif. Hanya angka penjualan (tanpa untung/margin).
enum _CashierPeriod { today, last7Days, last30Days }

class CashierReportScreen extends ConsumerStatefulWidget {
  const CashierReportScreen({super.key});

  @override
  ConsumerState<CashierReportScreen> createState() =>
      _CashierReportScreenState();
}

class _CashierReportScreenState extends ConsumerState<CashierReportScreen> {
  _CashierPeriod _period = _CashierPeriod.today;
  bool _isLoading = true;
  List<Transaction> _transactions = [];
  Shift? _activeShift;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  ({DateTime start, DateTime end}) _range() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (_period) {
      case _CashierPeriod.today:
        return (start: todayStart, end: todayEnd);
      case _CashierPeriod.last7Days:
        return (start: todayStart.subtract(const Duration(days: 6)), end: todayEnd);
      case _CashierPeriod.last30Days:
        return (start: todayStart.subtract(const Duration(days: 29)), end: todayEnd);
    }
  }

  Future<void> _loadData() async {
    final user = ref.read(currentUserProvider);
    if (user?.outletId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    final service = SupabaseService();
    final range = _range();

    final results = await Future.wait([
      service.getTransactions(
        user!.outletId!,
        limit: 1000,
        startDate: range.start,
        endDate: range.end,
      ),
      service.getActiveShift(user.outletId!, userId: user.id),
    ]);

    if (!mounted) return;
    setState(() {
      _transactions = results[0] as List<Transaction>;
      _activeShift = results[1] as Shift?;
      _isLoading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Ringkasan penjualan
  // ---------------------------------------------------------------------------
  double get _totalSales =>
      _transactions.fold<double>(0, (sum, t) => sum + t.finalAmount);

  int get _txCount => _transactions.length;

  double get _avgPerTx => _txCount == 0 ? 0 : _totalSales / _txCount;

  double get _totalItems => _transactions.fold<double>(
        0,
        (sum, t) =>
            sum + t.items.fold<double>(0, (s, i) => s + i.quantity),
      );

  double get _totalTip =>
      _transactions.fold<double>(0, (sum, t) => sum + t.tipAmount);

  Map<String, double> get _byPaymentMethod {
    final map = <String, double>{};
    for (final t in _transactions) {
      final key = t.paymentMethod.trim().isEmpty
          ? 'Lainnya'
          : t.paymentMethod.toUpperCase();
      map[key] = (map[key] ?? 0) + t.finalAmount;
    }
    return map;
  }

  String _periodLabel() {
    switch (_period) {
      case _CashierPeriod.today:
        return 'Hari Ini';
      case _CashierPeriod.last7Days:
        return '7 Hari Terakhir';
      case _CashierPeriod.last30Days:
        return '30 Hari Terakhir';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    final outletType = ref.watch(outletTypeProvider(user.outletId ?? ''));

    return AppShell(
      navItems: const [
        AppNavItem(icon: Icons.dashboard_rounded, label: 'Home Kasir'),
        AppNavItem(icon: Icons.point_of_sale_rounded, label: 'POS'),
        AppNavItem(icon: Icons.insights_rounded, label: 'Laporan'),
      ],
      currentIndex: 2,
      onIndexChanged: (index) {
        if (index == 0) {
          context.pop();
        } else if (index == 1) {
          context.pushReplacement('/cashier/pos');
        }
      },
      headerTitle: 'Laporan Penjualan',
      drawer: AppDrawer(user: user),
      mobileActions: const [LogoutButton()],
      mobileTitle: Text(
        'LAPORAN • ${outletType.toUpperCase()}',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodSelector(),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor),
                    ),
                  )
                else ...[
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  _buildPaymentBreakdown(),
                  const SizedBox(height: 24),
                  _buildActiveShiftSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final options = <(_CashierPeriod, String)>[
      (_CashierPeriod.today, 'Hari Ini'),
      (_CashierPeriod.last7Days, 'Mingguan'),
      (_CashierPeriod.last30Days, 'Bulanan'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          for (final opt in options)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_period == opt.$1) return;
                  setState(() => _period = opt.$1);
                  _loadData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _period == opt.$1
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    opt.$2,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _period == opt.$1
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan ${_periodLabel()}',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL PENJUALAN',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                Formatters.currency(_totalSales),
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.receipt_long_rounded,
                color: AppTheme.secondaryColor,
                label: 'Transaksi',
                value: Formatters.number(_txCount),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.shopping_bag_rounded,
                color: AppTheme.warningColor,
                label: 'Item Terjual',
                value: Formatters.number(_totalItems),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.trending_up_rounded,
                color: AppTheme.successColor,
                label: 'Rata-rata / Transaksi',
                value: Formatters.currency(_avgPerTx),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.volunteer_activism_rounded,
                color: AppTheme.accentColor,
                label: 'Total Tip',
                value: Formatters.currency(_totalTip),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentBreakdown() {
    final breakdown = _byPaymentMethod;
    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Metode Pembayaran',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          GlassCard(
            child: Text(
              'Belum ada transaksi pada periode ini.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          )
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _iconForMethod(entries[i].key),
                            size: 20,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _labelForMethod(entries[i].key),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          Formatters.currency(entries[i].value),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != entries.length - 1)
                    Divider(height: 1, color: AppTheme.borderColor),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActiveShiftSection() {
    final shift = _activeShift;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shift Aktif',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: shift == null
              ? Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        color: AppTheme.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Belum ada shift aktif. Buka shift dari Home Kasir.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppTheme.successColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Shift dibuka',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.successColor,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          Formatters.dateTime(shift.openedAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ShiftRow(
                      label: 'Kas Awal',
                      value: Formatters.currency(shift.openingCash),
                    ),
                    _ShiftRow(
                      label: 'Penjualan Tunai',
                      value: Formatters.currency(shift.totalCash ?? 0),
                    ),
                    _ShiftRow(
                      label: 'Penjualan QRIS',
                      value: Formatters.currency(shift.totalQris ?? 0),
                    ),
                    _ShiftRow(
                      label: 'Penjualan Transfer',
                      value: Formatters.currency(shift.totalTransfer ?? 0),
                    ),
                    _ShiftRow(
                      label: 'Tip Masuk',
                      value: Formatters.currency(shift.totalTip),
                    ),
                    Divider(height: 24, color: AppTheme.borderColor),
                    _ShiftRow(
                      label: 'Kas Seharusnya',
                      value: Formatters.currency(
                        shift.openingCash +
                            (shift.totalCash ?? 0) +
                            shift.totalTip,
                      ),
                      emphasize: true,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  IconData _iconForMethod(String method) {
    final m = method.toUpperCase();
    if (m.contains('QRIS')) return Icons.qr_code_2_rounded;
    if (m.contains('CASH') || m.contains('TUNAI')) {
      return Icons.payments_rounded;
    }
    if (m.contains('TRANSFER')) return Icons.account_balance_rounded;
    return Icons.credit_card_rounded;
  }

  String _labelForMethod(String method) {
    final m = method.toUpperCase();
    if (m.contains('QRIS')) return 'QRIS';
    if (m.contains('CASH') || m.contains('TUNAI')) return 'Tunai';
    if (m.contains('TRANSFER')) return 'Transfer Bank';
    return method;
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _ShiftRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: emphasize ? 13.5 : 13,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                color: emphasize
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: emphasize ? 15 : 13,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
              color: emphasize
                  ? AppTheme.primaryColor
                  : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
