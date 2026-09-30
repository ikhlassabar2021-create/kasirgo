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
  double _marginPercent = 5;

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
    final history =
        outletId.isEmpty ? <PpobTransaction>[] : await _ppob.getHistory(outletId, limit: 30);
    if (!mounted) return;
    setState(() {
      _marginPercent = cfg.marginPercent;
      _categories = cats;
      _products = products;
      _history = history;
      _loading = false;
    });
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
                        'Harga: ${Formatters.currency(inquiry.sellPrice)}'
                        ' (margin ${_marginPercent.toStringAsFixed(0)}%)',
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
                            child: Opacity(
                              opacity: 0.45,
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMedium),
                                  border:
                                      Border.all(color: AppTheme.borderColor),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.account_balance_wallet_rounded,
                                        size: 18, color: AppTheme.textSecondary),
                                    Text('Saldo (Segera)',
                                        style: GoogleFonts.inter(fontSize: 10.5)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

    final result = await _ppob.purchase(
      outletId: outletId,
      userId: userId,
      product: product,
      customerRef: customerRef,
      paymentMethod: paymentMethod,
    );

    if (!mounted) return;
    Navigator.pop(context);

    final ok = result != null && result.status == 'success';
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
                  const SizedBox(height: 32),
                ],
              ),
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
        trailing: Column(
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
