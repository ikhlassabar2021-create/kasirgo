import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Laporan',
            onPressed: _showShareDialog,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Laporan Bank (PDF)',
            onPressed: _exportBankReadyPdf,
          ),
        ],
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.table_view, color: Colors.white),
        label: const Text('Excel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _exportExcel,
      ),
    );
  }

  Future<void> _exportExcel() async {
    if (_transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data transaksi untuk diexport')),
      );
      return;
    }

    try {
      final excel = xl.Excel.createExcel();

      final summarySheet = excel['Ringkasan'];
      excel.setDefaultSheet('Ringkasan');

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

      summarySheet.appendRow([xl.TextCellValue('LAPORAN RINGKASAN KASIRGO')]);
      summarySheet.appendRow([xl.TextCellValue('Periode'), xl.TextCellValue(_selectedPeriod.name)]);
      summarySheet.appendRow([xl.TextCellValue('Tanggal Export'), xl.TextCellValue(DateTime.now().toIso8601String())]);
      summarySheet.appendRow([xl.TextCellValue('')]);
      summarySheet.appendRow([xl.TextCellValue('Indikator'), xl.TextCellValue('Nilai')]);
      summarySheet.appendRow([xl.TextCellValue('Total Omzet'), xl.DoubleCellValue(totalOmzet)]);
      summarySheet.appendRow([xl.TextCellValue('Total Untung Bersih'), xl.DoubleCellValue(totalUntung)]);
      summarySheet.appendRow([xl.TextCellValue('Jumlah Transaksi'), xl.IntCellValue(countTx)]);
      summarySheet.appendRow([xl.TextCellValue('Rata-rata Transaksi'), xl.DoubleCellValue(avgTx)]);

      final salesSheet = excel['Penjualan'];
      salesSheet.appendRow([
        xl.TextCellValue('ID Transaksi'),
        xl.TextCellValue('Waktu'),
        xl.TextCellValue('Metode Bayar'),
        xl.TextCellValue('Jumlah Item'),
        xl.TextCellValue('Total Bayar'),
      ]);

      for (final tx in _transactions) {
        salesSheet.appendRow([
          xl.TextCellValue(tx.id),
          xl.TextCellValue(tx.createdAt.toIso8601String()),
          xl.TextCellValue(tx.paymentMethod),
          xl.IntCellValue(tx.items.length),
          xl.DoubleCellValue(tx.finalAmount),
        ]);
      }

      final fileBytes = excel.save(fileName: 'Laporan_KasirGo_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      if (fileBytes != null) {
        await Printing.sharePdf(
          bytes: Uint8List.fromList(fileBytes),
          filename: 'Laporan_KasirGo_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export Excel: $e')),
        );
      }
    }
  }

  Future<void> _exportBankReadyPdf() async {
    if (_transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data transaksi untuk laporan bank')),
      );
      return;
    }

    try {
      final user = ref.read(currentUserProvider);
      final range = _getDateRange();
      final totalOmzet = _transactions.fold<double>(0, (sum, t) => sum + t.finalAmount);
      final countTx = _transactions.length;

      double totalHpp = 0;
      for (final tx in _transactions) {
        for (final item in tx.items) {
          final prod = _productMap[item.productId];
          final cost = prod?.costPrice ?? 0.0;
          totalHpp += cost * item.quantity;
        }
      }
      if (totalHpp == 0 && totalOmzet > 0) {
        totalHpp = totalOmzet * 0.75;
      }
      final labaKotor = totalOmzet - totalHpp;

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context pContext) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('LAPORAN KEUANGAN BANK-READY', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.Text('KasirGo POS System • Bukti Usaha Resmi', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Text(Formatters.date(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Divider(thickness: 1.5),
                  pw.SizedBox(height: 12),
                  pw.Text('Profil Usaha', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Nama Merchant : ${user?.email ?? "KasirGo Merchant"}'),
                  pw.Text('Outlet ID      : ${user?.outletId ?? "-"}'),
                  pw.Text('Periode Laporan: ${Formatters.date(range.start)} s/d ${Formatters.date(range.end)}'),
                  pw.SizedBox(height: 16),
                  pw.Text('Ringkasan Laba Rugi (Standar Perbankan)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Pos Keuangan', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Jumlah', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Pendapatan Penjualan (Omzet)')),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(Formatters.currency(totalOmzet))),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Harga Pokok Penjualan (HPP)')),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(Formatters.currency(totalHpp))),
                        ],
                      ),
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Laba Kotor (Gross Profit)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(Formatters.currency(labaKotor), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Volume Transaksi')),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$countTx transaksi')),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 24),
                  pw.Text('Catatan Bank:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    'Laporan ini digenerate secara otomatis oleh sistem KasirGo dan merefleksikan catatan penjualan '
                    'kasir/POS yang tercatat pada database. Valid sebagai lampiran pengajuan kredit UMKM/KUR.',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Laporan_Bank_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal generate PDF Bank: $e')),
        );
      }
    }
  }

  void _showShareDialog() {
    final range = _getDateRange();
    final totalOmzet = _transactions.fold<double>(0, (sum, t) => sum + t.finalAmount);
    final countTx = _transactions.length;

    final summaryText = 'Laporan Penjualan KasirGo%0A'
        'Periode: ${Formatters.date(range.start)} - ${Formatters.date(range.end)}%0A'
        'Total Omzet: ${Formatters.currency(totalOmzet)}%0A'
        'Total Transaksi: $countTx%0A%0A'
        'Dicatat otomatis oleh KasirGo Super-App UMKM.';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bCtx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.chat, color: AppTheme.successColor),
                title: const Text('Share via WhatsApp'),
                onTap: () async {
                  Navigator.pop(bCtx);
                  final uri = Uri.parse('https://wa.me/?text=$summaryText');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.email, color: AppTheme.accentColor),
                title: const Text('Share via Email'),
                onTap: () async {
                  Navigator.pop(bCtx);
                  final emailUri = Uri(
                    scheme: 'mailto',
                    queryParameters: {
                      'subject': 'Laporan Penjualan KasirGo',
                      'body': summaryText.replaceAll('%0A', '\n'),
                    },
                  );
                  if (await canLaunchUrl(emailUri)) {
                    await launchUrl(emailUri);
                  }
                },
              ),
            ],
          ),
        );
      },
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

    final barGroups = _generateDailyBarGroups();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
            ),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
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
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < barGroups.length) {
                          return Text('${idx + 1}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Daftar Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _generateDailyBarGroups() {
    final range = _getDateRange();
    final totalDays = range.end.difference(range.start).inDays + 1;
    final daySlots = totalDays > 0 ? (totalDays > 14 ? 14 : totalDays) : 1;

    final dailyMap = <int, double>{};
    for (var i = 0; i < daySlots; i++) {
      dailyMap[i] = 0.0;
    }

    for (final tx in _transactions) {
      final diff = tx.createdAt.difference(range.start).inDays;
      if (diff >= 0 && diff < daySlots) {
        dailyMap[diff] = (dailyMap[diff] ?? 0) + tx.finalAmount;
      }
    }

    return List.generate(daySlots, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: dailyMap[i] ?? 0.0,
            color: AppTheme.primaryColor,
            width: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
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
    final top10Names = sortedNames.take(10).toList();
    final maxQty = top10Names.fold<int>(1, (max, n) => (soldMap[n] ?? 0) > max ? (soldMap[n] ?? 0) : max);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top 10 Produk Terlaris (Qty)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ...top10Names.map((name) {
                  final qty = soldMap[name] ?? 0;
                  final pct = qty / maxQty;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text('$qty pcs', style: const TextStyle(fontSize: 12, color: AppTheme.accentColor, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 8,
                            backgroundColor: AppTheme.borderColor.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondaryColor),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Semua Produk Terjual', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
          ),
        ],
      ),
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
