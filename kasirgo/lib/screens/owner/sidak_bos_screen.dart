import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/business_doctor_service.dart';
import '../../services/sidak_service.dart';
import '../../utils/formatters.dart';
import '../../utils/receipt_generator.dart';
import '../../utils/sidak_report_pdf.dart';
import '../../utils/wa_helper.dart';
import 'sidak_stock_count_screen.dart';

/// Sidak Bos (13.24 #2): audit stok fisik & kas laci dengan temuan otomatis.
class SidakBosScreen extends ConsumerStatefulWidget {
  final SidakService? service;

  const SidakBosScreen({super.key, this.service});

  @override
  ConsumerState<SidakBosScreen> createState() => _SidakBosScreenState();
}

class _SidakBosScreenState extends ConsumerState<SidakBosScreen>
    with SingleTickerProviderStateMixin {
  late final SidakService _service;
  late final TabController _tabs;

  final _openingCtrl = TextEditingController(text: '0');
  final _actualCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  int _periodDays = 7;

  List<SidakCountRow> _rows = [];
  List<SidakFinding> _autoFindings = [];
  List<SidakSession> _sessions = [];

  double _cashSales = 0;
  double _nonCashSales = 0;
  int _txCount = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SidakService();
    _tabs = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _openingCtrl.dispose();
    _actualCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _outletId =>
      ref.read(currentUserProvider)?.outletId ?? '';

  DateTime get _periodFrom {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return start.subtract(Duration(days: _periodDays - 1));
  }

  DateTime get _periodTo => DateTime.now();

  Future<void> _loadAll() async {
    final outletId = _outletId;
    if (outletId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.loadCountRows(outletId),
        _service.cashSummary(outletId, from: _periodFrom, to: _periodTo),
        _service.listSessions(outletId),
      ]);
      final rows = results[0] as List<SidakCountRow>;
      final summary = results[1] as Map<String, dynamic>;
      final sessions = results[2] as List<SidakSession>;
      final findings = await _service.autoFindings(outletId, rows: rows);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _autoFindings = findings;
        _sessions = sessions;
        _cashSales = (summary['cash_sales'] as num?)?.toDouble() ?? 0;
        _nonCashSales = (summary['non_cash_sales'] as num?)?.toDouble() ?? 0;
        _txCount = (summary['tx_count'] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      _snack('Gagal memuat data sidak: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reloadCash() async {
    final outletId = _outletId;
    if (outletId.isEmpty) return;
    try {
      final summary =
          await _service.cashSummary(outletId, from: _periodFrom, to: _periodTo);
      if (!mounted) return;
      setState(() {
        _cashSales = (summary['cash_sales'] as num?)?.toDouble() ?? 0;
        _nonCashSales = (summary['non_cash_sales'] as num?)?.toDouble() ?? 0;
        _txCount = (summary['tx_count'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  double get _openingCash => _parseMoney(_openingCtrl.text);
  double get _expectedCash => _openingCash + _cashSales;
  bool get _cashChecked => _actualCtrl.text.trim().isNotEmpty;
  double? get _actualCash =>
      _cashChecked ? _parseMoney(_actualCtrl.text) : null;
  double get _cashDiff =>
      _cashChecked ? (_actualCash ?? 0) - _expectedCash : 0;

  double get _stockDiffValue => _rows
      .where((r) => !r.isService)
      .fold(0, (sum, r) => sum + r.diffValue);

  int get _stockDiffCount =>
      _rows.where((r) => !r.isService && r.diff != 0).length;

  List<SidakFinding> get _findings => [
        ..._service.manualFindings(
          rows: _rows,
          cashDiff: _cashDiff,
          cashChecked: _cashChecked,
        ),
        ..._autoFindings,
      ];

  static double _parseMoney(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return double.tryParse(digits) ?? 0;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openCount() async {
    if (_rows.isEmpty) {
      _snack('Belum ada produk untuk dihitung.');
      return;
    }
    final result = await Navigator.push<List<SidakCountRow>>(
      context,
      MaterialPageRoute(
        builder: (_) => SidakStockCountScreen(rows: _rows),
      ),
    );
    if (result != null && mounted) setState(() => _rows = result);
  }

  Future<void> _save() async {
    if (_rows.isEmpty) {
      _snack('Data produk belum siap. Coba segarkan.');
      return;
    }
    setState(() => _saving = true);
    try {
      final findings = _findings;
      final sessionId = await _service.saveSession(
        outletId: _outletId,
        from: _periodFrom,
        to: _periodTo,
        openingCash: _openingCash,
        expectedCash: _expectedCash,
        actualCash: _actualCash,
        cashDiff: _cashDiff,
        cashSales: _cashSales,
        nonCashSales: _nonCashSales,
        rows: _rows,
        findings: findings,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        createdBy: ref.read(currentUserProvider)?.id,
      );
      if (sessionId == null) {
        throw Exception('Sesi sidak tidak tersimpan.');
      }
      await _service.logAction(sessionId);
      if (!mounted) return;
      setState(() => _saving = false);
      await _showResult(findings);
      _resetForm();
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Gagal menyimpan sidak: $e');
    }
  }

  void _resetForm() {
    _openingCtrl.text = '0';
    _actualCtrl.clear();
    _noteCtrl.clear();
  }

  Future<void> _showResult(List<SidakFinding> findings) async {
    final clean = _cashDiff == 0 &&
        _stockDiffValue == 0 &&
        findings.isEmpty &&
        _cashChecked;
    final tone = SidakReportPdf.verdictLabel(clean, findings.length);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Row(
          children: [
            Icon(
              clean ? Icons.verified_rounded : Icons.report_problem_rounded,
              color: clean ? AppTheme.successColor : AppTheme.warningColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sidak Tersimpan',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hasil: $tone',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selisih kas ${Formatters.currency(_cashDiff)} | '
              'selisih stok ${Formatters.currency(_stockDiffValue)} | '
              '${findings.length} temuan',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _share(findings, pdf: true),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('PDF'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppTheme.touchTargetMedium),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _share(findings, pdf: false),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('Kirim WA'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppTheme.touchTargetMedium),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _share(List<SidakFinding> findings, {required bool pdf}) async {
    final storeName =
        ref.read(currentUserProvider)?.name ?? 'Usaha Saya';
    try {
      if (pdf) {
        final bytes = await SidakReportPdf.build(
          storeName: storeName,
          periodFrom: _periodFrom,
          periodTo: _periodTo,
          cashSales: _cashSales,
          nonCashSales: _nonCashSales,
          expectedCash: _expectedCash,
          actualCash: _actualCash ?? 0,
          cashDiff: _cashDiff,
          stockValueSystem: _rows
              .where((r) => !r.isService)
              .fold(0, (s, r) => s + r.stockSystem * r.costPrice),
          stockValuePhysical: _rows
              .where((r) => !r.isService)
              .fold(0, (s, r) => s + r.physical * r.costPrice),
          stockDiffValue: _stockDiffValue,
          findings: findings,
          rows: _rows,
          note: _noteCtrl.text.trim(),
        );
        final filename =
            'Sidak_${Formatters.date(DateTime.now()).replaceAll('/', '-')}.pdf';
        await ReceiptGenerator.share(bytes, filename);
        if (!mounted) return;
        _snack('Laporan sidak tersimpan sebagai PDF.');
      } else {
        final bossWa = await _bossWaNumber();
        if (!mounted) return;
        if (bossWa.isEmpty) {
          _snack('Atur nomor WhatsApp bos dulu ya.');
          return;
        }
        final text = SidakReportPdf.buildText(
          storeName: storeName,
          periodFrom: _periodFrom,
          periodTo: _periodTo,
          cashSales: _cashSales,
          nonCashSales: _nonCashSales,
          expectedCash: _expectedCash,
          actualCash: _actualCash ?? 0,
          cashDiff: _cashDiff,
          stockDiffValue: _stockDiffValue,
          findings: findings,
          rows: _rows,
          note: _noteCtrl.text.trim(),
        );
        final ok =
            await WaHelper.sendWhatsAppMessage(phone: bossWa, message: text);
        if (!mounted) return;
        if (!ok) _snack('WhatsApp tidak bisa dibuka di perangkat ini.');
      }
    } catch (e) {
      _snack('Gagal membuat laporan: $e');
    }
  }

  Future<String> _bossWaNumber() async {
    final outletId = _outletId;
    if (outletId.isEmpty) return '';
    try {
      final profile =
          await BusinessDoctorService().getProfile(outletId);
      return (profile?['boss_wa_number'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Sidak Bos'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAll,
            tooltip: 'Segarkan',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Sidak Baru'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _buildNewTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildNewTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildIntroCard(),
        const SizedBox(height: 16),
        _buildCashCard(),
        const SizedBox(height: 16),
        _buildStockCard(),
        const SizedBox(height: 16),
        _buildFindingsCard(),
        const SizedBox(height: 16),
        TextField(
          controller: _noteCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Catatan sidak (opsional)',
            hintText: 'Contoh: ada barang rusak di rak belakang',
            filled: true,
            fillColor: AppTheme.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: AppTheme.touchTargetLarge,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.fact_check_rounded),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan Hasil Sidak'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Sidak Stok & Kas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Audit internal cepat: cocokkan uang laci dan stok fisik dengan '
            'catatan kasir. Hasil otomatis dicatat untuk evaluasi Dokter Bisnis.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashCard() {
    return _card(
      title: '1. Kas Laci',
      icon: Icons.account_balance_wallet_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final d in [1, 7, 30])
                ChoiceChip(
                  label: Text(d == 1 ? 'Hari ini' : '$d hari'),
                  selected: _periodDays == d,
                  onSelected: (_) {
                    setState(() => _periodDays = d);
                    _reloadCash();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('Penjualan tunai', Formatters.currency(_cashSales)),
          _infoRow('Penjualan non-tunai', Formatters.currency(_nonCashSales)),
          _infoRow('Jumlah transaksi', '$_txCount transaksi'),
          const Divider(height: 24),
          _moneyField(
            controller: _openingCtrl,
            label: 'Uang laci saat mulai (modal awal)',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          _infoRow(
            'Kas seharusnya',
            Formatters.currency(_expectedCash),
            bold: true,
          ),
          const SizedBox(height: 10),
          _moneyField(
            controller: _actualCtrl,
            label: 'Uang laci hasil hitung',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: !_cashChecked
                  ? AppTheme.surfaceMutedColor
                  : (_cashDiff == 0
                      ? AppTheme.successSoftColor
                      : AppTheme.warningSoftColor),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Row(
              children: [
                Text(
                  'Selisih kas',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  !_cashChecked
                      ? 'Belum dihitung'
                      : Formatters.currency(_cashDiff),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: !_cashChecked
                        ? AppTheme.textSecondary
                        : (_cashDiff == 0
                            ? AppTheme.successTextColor
                            : AppTheme.warningTextColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard() {
    return _card(
      title: '2. Stok Fisik',
      icon: Icons.inventory_2_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Produk dihitung', '${_rows.where((r) => !r.isService).length}'),
          _infoRow('Produk berselisih', '$_stockDiffCount'),
          _infoRow(
            'Selisih nilai',
            Formatters.currency(_stockDiffValue),
            bold: true,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: AppTheme.touchTargetMedium,
            child: OutlinedButton.icon(
              onPressed: _openCount,
              icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
              label: const Text('Mulai Hitung Stok'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindingsCard() {
    final findings = _findings;
    return _card(
      title: '3. Temuan',
      icon: Icons.report_rounded,
      child: findings.isEmpty
          ? Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.successColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Belum ada temuan. Hitung stok dan kas untuk hasil lengkap.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                for (final f in findings) _buildFindingTile(f),
              ],
            ),
    );
  }

  Widget _buildFindingTile(SidakFinding f) {
    final isHigh = f.severity == 'tinggi';
    final isLow = f.severity == 'rendah';
    final color = isHigh
        ? AppTheme.errorColor
        : (isLow ? AppTheme.textSecondary : AppTheme.warningColor);
    final bg = isHigh
        ? AppTheme.errorSoftColor
        : (isLow ? AppTheme.surfaceMutedColor : AppTheme.warningSoftColor);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isHigh
                ? Icons.error_outline_rounded
                : (isLow ? Icons.info_outline_rounded : Icons.warning_amber_rounded),
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  f.detail,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
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

  Widget _buildHistoryTab() {
    if (_sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppTheme.infoSoftColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history_rounded,
                    size: 44, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'Belum Ada Riwayat Sidak',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lakukan sidak pertama Anda. Hasilnya tersimpan di sini '
                'sebagai bukti audit internal.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildSessionTile(_sessions[i]),
    );
  }

  Widget _buildSessionTile(SidakSession s) {
    final clean = s.isClean;
    return InkWell(
      onTap: () => _openSessionDetail(s),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: clean
                    ? AppTheme.successSoftColor
                    : AppTheme.warningSoftColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                clean ? Icons.verified_rounded : Icons.report_problem_rounded,
                color:
                    clean ? AppTheme.successColor : AppTheme.warningColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Formatters.dateTime(s.createdAt),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kas ${Formatters.currency(s.cashDiff)} | '
                    'Stok ${Formatters.currency(s.stockDiffValue)} | '
                    '${s.findings.length} temuan',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _openSessionDetail(SidakSession s) async {
    List<Map<String, dynamic>> items = [];
    try {
      items = await _service.sessionItems(s.id);
    } catch (_) {}
    if (!mounted) return;
    await showModalBottomSheet<void>(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sidak ${Formatters.dateTime(s.createdAt)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow('Kas seharusnya', Formatters.currency(s.expectedCash)),
            _infoRow('Kas fisik', Formatters.currency(s.actualCash)),
            _infoRow('Selisih kas', Formatters.currency(s.cashDiff), bold: true),
            const Divider(height: 24),
            _infoRow(
              'Nilai stok sistem',
              Formatters.currency(s.stockValueSystem),
            ),
            _infoRow(
              'Nilai stok fisik',
              Formatters.currency(s.stockValuePhysical),
            ),
            _infoRow('Selisih stok', Formatters.currency(s.stockDiffValue),
                bold: true),
            const Divider(height: 24),
            if (items.isNotEmpty) ...[
              const Text(
                'Produk berselisih',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${it['product_name']}: sistem ${it['stock_system']} '
                    '-> fisik ${it['stock_physical']} '
                    '(${Formatters.currency((it['diff_value'] as num?) ?? 0)})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
            if (s.findings.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Temuan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final f in s.findings) _buildFindingTile(f),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        isDense: true,
        filled: true,
        fillColor: AppTheme.surfaceMutedColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
