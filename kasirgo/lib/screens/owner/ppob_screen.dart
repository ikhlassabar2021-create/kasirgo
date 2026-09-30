import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/ppob.dart';
import '../../providers/auth_provider.dart';
import '../../services/ppob_service.dart';
import '../../utils/formatters.dart';

class PpobScreen extends ConsumerStatefulWidget {
  const PpobScreen({super.key});

  @override
  ConsumerState<PpobScreen> createState() => _PpobScreenState();
}

class _PpobScreenState extends ConsumerState<PpobScreen> {
  final PpobService _ppob = PpobService();

  bool _loading = true;
  String _selectedCategory = 'all';
  List<String> _categories = [];
  List<PpobProduct> _products = [];
  List<PpobTransaction> _history = [];
  double _saldo = 0;
  bool _cfgEnabled = true;
  String _reportPeriod = 'today';
  PpobReport _report =
      const PpobReport(sales: 0, cost: 0, profit: 0, count: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cfg = await _ppob.loadConfig();
    final cats = await _ppob.getCategories();
    final products = await _ppob.getProducts(category: _selectedCategory);
    final outletId = ref.read(currentUserProvider)?.outletId ?? '';
    List<PpobTransaction> history = [];
    double saldo = 0;
    PpobReport report =
        const PpobReport(sales: 0, cost: 0, profit: 0, count: 0);
    if (outletId.isNotEmpty) {
      history = await _ppob.getHistory(outletId, limit: 30);
      saldo = await _ppob.getSaldo(outletId);
      report = await _ppob.getSummary(outletId, _rangeStart(), DateTime.now());
    }
    if (!mounted) return;
    setState(() {
      _cfgEnabled = cfg.enabled;
      _categories = cats;
      _products = products;
      _history = history;
      _saldo = saldo;
      _report = report;
      _loading = false;
    });
  }

  /// Awal periode laporan PPOB sesuai pilihan owner.
  DateTime _rangeStart() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_reportPeriod) {
      'week' => today.subtract(const Duration(days: 6)),
      'month' => DateTime(now.year, now.month, 1),
      _ => today,
    };
  }

  bool get _showMargin {
    final role = ref.read(currentUserProvider)?.role ?? 'cashier';
    return role != 'cashier';
  }

  Future<void> _refreshSaldo() async {
    final outletId = ref.read(currentUserProvider)?.outletId ?? '';
    if (outletId.isEmpty) return;
    final saldo = await _ppob.getSaldo(outletId);
    if (!mounted) return;
    setState(() => _saldo = saldo);
  }

  /// Owner setor hasil settlement QRIS ke saldo (closed-loop).
  Future<void> _addSaldo() async {
    final outletId = ref.read(currentUserProvider)?.outletId ?? '';
    if (outletId.isEmpty) return;
    final amountCtl = TextEditingController();
    final noteCtl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Text('Setor QRIS ke Saldo',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Masukkan jumlah dana QRIS yang diterima di rekening. '
                'Saldo ini otomatis dipakai untuk beli PPOB.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.inter(
                  fontSize: 15, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Jumlah (Rp)',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtl,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'cth: Setoran QRIS 30 Sep',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Icon(Icons.close_rounded, size: 20)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Setor',
                  style: GoogleFonts.inter(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final amount = double.tryParse(
            amountCtl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Jumlah tidak valid'),
          backgroundColor: AppTheme.errorColor));
      return;
    }
    try {
      final newSaldo =
          await _ppob.addQrisToSaldo(outletId, amount, note: noteCtl.text);
      if (!mounted) return;
      setState(() => _saldo = newSaldo);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Saldo bertambah. Saldo sekarang: ${Formatters.currency(newSaldo)}'),
          backgroundColor: AppTheme.successColor));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal setor saldo: $e'),
          backgroundColor: AppTheme.errorColor));
    }
  }

  Future<void> _openInquiry(PpobProduct product) async {
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId ?? '';
    if (outletId.isEmpty || user == null) return;

    final refController = TextEditingController();
    final category = product.category ?? 'pulsa';
    final hint = switch (category) {
      'pln' => 'ID Pelanggan PLN (10-12 digit)',
      'game' => 'ID Akun Game',
      'e-money' => 'Nomor Kartu / Akun',
      _ => 'Nomor HP Tujuan (08xx)',
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final inquiry = _ppob.inquireSync(product, refController.text);
          final paymentMethodCtl = ValueNotifier<String>('cash');
          return Padding(
            padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(product.name,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                        'Harga: ${Formatters.currency(inquiry.sellPrice)}',
                        style: GoogleFonts.inter(
                            fontSize: 12.5, color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: refController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      onChanged: (_) => setSheetState(() {}),
                      style: GoogleFonts.inter(
                          fontSize: 15, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Tujuan',
                        hintText: hint,
                        errorText: refController.text.isEmpty
                            ? null
                            : inquiry.error,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('METODE PEMBAYARAN',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    ValueListenableBuilder<String>(
                      valueListenable: paymentMethodCtl,
                      builder: (ctx, method, _) => Row(
                        children: [
                          _payOption('cash', 'Tunai',
                              Icons.payments_rounded, method, paymentMethodCtl),
                          const SizedBox(width: 8),
                          _payOption('qris', 'QRIS',
                              Icons.qr_code_2_rounded, method, paymentMethodCtl),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _saldo >= inquiry.sellPrice
                                ? _payOption(
                                    'saldo',
                                    'Saldo ${Formatters.currency(_saldo)}',
                                    Icons.account_balance_wallet_rounded,
                                    method,
                                    paymentMethodCtl)
                                : Opacity(
                                    opacity: 0.45,
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AppTheme.backgroundColor,
                                        borderRadius: BorderRadius.circular(
                                            AppTheme.radiusMedium),
                                        border: Border.all(
                                            color: AppTheme.borderColor),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                              Icons
                                                  .account_balance_wallet_rounded,
                                              size: 18,
                                              color: AppTheme.textSecondary),
                                          Text('Saldo kurang',
                                              style: GoogleFonts.inter(
                                                  fontSize: 10.5)),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Rincian transparan (modal & margin hanya untuk owner/admin).
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: _showMargin
                          ? Column(
                              children: [
                                _resultRow('Harga jual',
                                    Formatters.currency(inquiry.sellPrice)),
                                _resultRow('Modal provider',
                                    Formatters.currency(inquiry.costPrice)),
                                _resultRow('Margin',
                                    Formatters.currency(inquiry.profit)),
                              ],
                            )
                          : _resultRow('Harga',
                              Formatters.currency(inquiry.sellPrice)),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: inquiry.isValid
                            ? () async {
                                final method = paymentMethodCtl.value;
                                Navigator.pop(sheetCtx);
                                await _processPurchase(
                                    product, refController.text, method, user.id);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.borderColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium)),
                        ),
                        child: Text('Bayar ${Formatters.currency(inquiry.sellPrice)}',
                            style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _payOption(String value, String label, IconData icon, String current,
      ValueNotifier<String> notifier) {
    final selected = current == value;
    return Expanded(
      child: InkWell(
        onTap: () => notifier.value = value,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                : AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
                color:
                    selected ? AppTheme.primaryColor : AppTheme.borderColor,
                width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPurchase(PpobProduct product, String customerRef,
      String paymentMethod, String userId) async {
    final outletId = ref.read(currentUserProvider)?.outletId ?? '';
    if (outletId.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(height: 14),
            Text('Memproses transaksi...',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );

    PpobTransaction? result;
    String? errorMsg;
    try {
      result = await _ppob.purchase(
        outletId: outletId,
        userId: userId,
        product: product,
        customerRef: customerRef,
        paymentMethod: paymentMethod,
      );
    } on PpobException catch (e) {
      errorMsg = e.message;
    } catch (e) {
      errorMsg = 'Terjadi kesalahan. Coba lagi.';
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (errorMsg != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
          title: Column(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppTheme.errorColor, size: 44),
              const SizedBox(height: 8),
              Text('Transaksi Gagal',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
            ],
          ),
          content: Text(errorMsg!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12.5, color: AppTheme.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Tutup',
                    style: GoogleFonts.inter(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700))),
          ],
        ),
      );
      _load();
      return;
    }

    final ok = result != null && result.status == 'success';
    if (ok && paymentMethod == 'saldo') {
      await _refreshSaldo();
      if (!mounted) return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Column(
          children: [
            Icon(
              ok
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: ok ? AppTheme.successColor : AppTheme.errorColor,
              size: 44,
            ),
            const SizedBox(height: 8),
            Text(
              result == null
                  ? 'Gagal'
                  : ok
                      ? 'Transaksi Berhasil'
                      : result.status == 'pending'
                          ? 'Menunggu Provider'
                          : 'Transaksi Gagal',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary),
            ),
          ],
        ),
        content: result == null
            ? Text('Transaksi tidak tersimpan. Coba lagi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 12.5, color: AppTheme.textSecondary))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _resultRow('Produk', result.productName),
                  _resultRow('Tujuan', result.customerRef),
                  _resultRow('Harga', Formatters.currency(result.amount)),
                  if (result.paymentMethod == 'saldo' && ok) ...[
                    _resultRow('Metode', 'Saldo QRIS'),
                    _resultRow('Sisa Saldo', Formatters.currency(_saldo)),
                  ],
                  if (result.providerRef != null)
                    _resultRow('Ref', result.providerRef!),
                  const SizedBox(height: 6),
                  Text(
                    ok
                        ? 'Struk digital tersimpan di riwayat.'
                        : 'Status: ${result.status}. Cek riwayat untuk update.',
                    style: GoogleFonts.inter(
                        fontSize: 11.5, color: AppTheme.textSecondary),
                  ),
                ],
              ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Tutup',
                  style: GoogleFonts.inter(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );

    _load();
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12.5, color: AppTheme.textSecondary)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedCategory == 'all'
        ? _products
        : _products
            .where((p) => (p.category ?? '') == _selectedCategory)
            .toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('PPOB & Tagihan',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded,
                  color: AppTheme.textSecondary)),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSaldoCard(),
                  if (_showMargin) _buildReportCard(),
                  if (!_cfgEnabled) ...[
                    _buildDisabledCard(),
                  ] else ...[
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _categoryChip('all', 'Semua'),
                        ..._categories.map((c) => _categoryChip(c, _labelCat(c))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Text(
                        'Belum ada produk PPOB di kategori ini.\nKatalog dikelola superadmin.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 12.5, color: AppTheme.textSecondary),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.98,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final p = filtered[i];
                        final sell = _ppob.sellPriceFor(p);
                        return InkWell(
                          onTap: () => _openInquiry(p),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(_iconCat(p.category),
                                    size: 20, color: AppTheme.primaryColor),
                                const Spacer(),
                                Text(p.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary)),
                                const SizedBox(height: 2),
                                Text(Formatters.currency(sell),
                                    style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryColor)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                  Text('RIWAYAT TRANSAKSI',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Text('Belum ada transaksi PPOB.',
                          style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary)),
                    )
                  else
                    ..._history.map(_historyCard),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  /// Kartu saldo closed-loop (settlement QRIS -> beli PPOB).
  Widget _buildSaldoCard() {
    final role = ref.read(currentUserProvider)?.role ?? 'cashier';
    final isOwner = role == 'owner';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF06B6D4), AppTheme.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  size: 18, color: Colors.white70),
              const SizedBox(width: 6),
              Text('SALDO QRIS (CLOSED-LOOP)',
                  style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.white70)),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _refreshSaldo,
                icon: const Icon(Icons.refresh_rounded,
                    size: 18, color: Colors.white),
              ),
            ],
          ),
          Text(Formatters.currency(_saldo),
              style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text(
            'Saldo dari settlement QRIS. Otomatis dipakai saat beli PPOB '
            'dengan metode Saldo.',
            style: GoogleFonts.inter(
                fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
          ),
          if (isOwner) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                onPressed: _addSaldo,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Setor QRIS ke Saldo',
                    style: GoogleFonts.inter(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Kartu laporan PPOB: omset, untung, jumlah, rata-rata per periode.
  Widget _buildReportCard() {
    const periods = {
      'today': 'Hari Ini',
      'week': '7 Hari',
      'month': 'Bulan Ini',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
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
              const Icon(Icons.insights_rounded,
                  size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text('LAPORAN PPOB',
                  style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppTheme.textSecondary)),
              const Spacer(),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _reportPeriod,
                  isDense: true,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor),
                  items: periods.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _reportPeriod = v);
                    _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _reportStat('Omzet', _report.sales,
                    AppTheme.primaryColor),
              ),
              Expanded(
                child: _reportStat(
                    'Untung', _report.profit, AppTheme.successColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _reportStat('Transaksi', _report.count.toDouble(),
                    AppTheme.accentColor,
                    isCount: true),
              ),
              Expanded(
                child: _reportStat(
                    'Rata-rata', _report.avg, AppTheme.secondaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportStat(String label, double value, Color color,
      {bool isCount = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(isCount ? value.toStringAsFixed(0) : Formatters.currency(value),
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color)),
      ],
    );
  }

  /// PPOB dinonaktifkan superadmin via Control Plane.
  Widget _buildDisabledCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.power_settings_new_rounded,
              size: 40, color: AppTheme.textSecondary),
          const SizedBox(height: 10),
          Text('PPOB Belum Diaktifkan',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'Fitur PPOB sedang dinonaktifkan oleh pengelola aplikasi. '
            'Hubungi dukungan untuk informasi lebih lanjut.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 12.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String value, String label) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
        backgroundColor: AppTheme.surfaceColor,
        side: BorderSide(
            color: selected
                ? AppTheme.primaryColor
                : AppTheme.borderColor.withValues(alpha: 0.5)),
        labelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? AppTheme.primaryColor
                : AppTheme.textSecondary),
        onSelected: (_) {
          setState(() => _selectedCategory = value);
          _load();
        },
      ),
    );
  }

  Widget _historyCard(PpobTransaction tx) {
    final ok = tx.status == 'success';
    final color = ok
        ? AppTheme.successColor
        : tx.status == 'pending'
            ? AppTheme.warningColor
            : AppTheme.errorColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Icon(_iconCat(null), size: 22, color: AppTheme.textSecondary),
        title: Text(tx.productName,
            style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${tx.customerRef} - ${_fmtTime(tx.createdAt)}'
            '${tx.providerRef != null ? ' - ${tx.providerRef}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppTheme.textSecondary),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Formatters.currency(tx.amount),
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                Text(tx.status.toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ),
            if (tx.status == 'pending') ...[
              const SizedBox(width: 6),
              SizedBox(
                height: 32,
                child: TextButton(
                  onPressed: () async {
                    final updated = await _ppob.refreshStatus(tx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(updated == null
                            ? 'Gagal cek status.'
                            : 'Status: ${updated.status.toUpperCase()}'),
                        backgroundColor: updated?.status == 'success'
                            ? AppTheme.successColor
                            : AppTheme.warningColor));
                    _load();
                  },
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: Text('Cek',
                      style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _labelCat(String c) => switch (c) {
        'pulsa' => 'Pulsa',
        'data' => 'Paket Data',
        'pln' => 'Token PLN',
        'game' => 'Voucher Game',
        'e-money' => 'E-Money',
        _ => c.toUpperCase(),
      };

  IconData _iconCat(String? c) => switch (c) {
        'pulsa' => Icons.signal_cellular_alt_rounded,
        'data' => Icons.wifi_rounded,
        'pln' => Icons.bolt_rounded,
        'game' => Icons.sports_esports_rounded,
        'e-money' => Icons.account_balance_wallet_rounded,
        _ => Icons.receipt_long_rounded,
      };

  String _fmtTime(DateTime dt) =>
      '${dt.day.toStringAsFixed(0).padLeft(2, '0')}/${dt.month.toStringAsFixed(0).padLeft(2, '0')} ${dt.hour.toStringAsFixed(0).padLeft(2, '0')}:${dt.minute.toStringAsFixed(0).padLeft(2, '0')}';
}
