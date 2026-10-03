import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/app_theme.dart';
import '../../models/restock.dart';
import '../../providers/auth_provider.dart';
import '../../services/b2b_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

/// Embedded B2B Restock (Phase 9 / ST9-3).
///
/// - Link distributor dari config superadmin (platform_configs
///   'b2b_restock') -> ganti link TANPA ubah koding.
/// - Anti-bypass: domain lock (WebView hanya membuka domain distributor),
///   redirect luar diblokir + tracking_id outlet disertakan di URL.
/// - Order dicatat ke restock_orders + komisi otomatis dari config.
class RestockScreen extends ConsumerStatefulWidget {
  const RestockScreen({super.key});

  @override
  ConsumerState<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends ConsumerState<RestockScreen> {
  final SupabaseService _service = SupabaseService();
  final B2bService _b2b = B2bService();

  bool _loading = true;
  B2bConfig _cfg = B2bConfig.fallback;
  List<RestockOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cfg = await _b2b.loadConfig();
    final outletId = ref.read(currentUserProvider)?.outletId ?? '';
    List<RestockOrder> orders = [];
    if (outletId.isNotEmpty) {
      orders = await _service.getRestockOrders(outletId);
    }
    if (!mounted) return;
    setState(() {
      _cfg = cfg;
      _orders = orders;
      _loading = false;
    });
  }

  Future<void> _openCatalog() async {
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId ?? '';
    if (outletId.isEmpty || user == null) return;

    if (!_cfg.isReady) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
          title: Row(
            children: [
              const Icon(Icons.storefront_rounded,
                  color: AppTheme.warningColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Katalog Belum Tersedia',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
              ),
            ],
          ),
          content: Text(
            'Katalog kulakan B2B belum dikonfigurasi oleh admin KasirGo. '
            'Coba lagi nanti.',
            style: GoogleFonts.inter(
                fontSize: 12.5, color: AppTheme.textSecondary),
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
      return;
    }

    final trackingId = _b2b.buildTrackingId(outletId);
    final url = _b2b.buildCatalogUrl(_cfg.distributorUrl, outletId, trackingId);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestockWebViewScreen(
          initialUrl: url,
          distributorName: _cfg.distributorName,
          allowedHosts: _cfg.hosts,
          trackingId: trackingId,
        ),
      ),
    );
    if (mounted) _load();
  }

  /// Owner mencatat order yang dilakukan di katalog distributor.
  Future<void> _recordOrder() async {
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId ?? '';
    if (outletId.isEmpty || user == null) return;

    final amountCtl = TextEditingController();
    final noteCtl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Text('Catat Order Restock',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Isi total belanja kulakan yang kamu order di '
                '${_cfg.distributorName}. Komisi ${_cfg.commissionPercent.toStringAsFixed(0)}% '
                'dicatat otomatis.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style:
                  GoogleFonts.inter(fontSize: 15, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Total belanja (Rp)',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtl,
              style:
                  GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Catatan barang (opsional)',
                hintText: 'cth: Minyak 2L x 24',
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
              child: Text('Simpan',
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

    final order = RestockOrder(
      id: '',
      outletId: outletId,
      userId: user.id,
      distributor: _cfg.distributorName,
      trackingId: _b2b.buildTrackingId(outletId),
      amount: amount,
      commission: _b2b.commissionFor(amount, cfg: _cfg),
      status: 'pending',
      itemsNote: noteCtl.text.trim().isEmpty ? null : noteCtl.text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await _service.createRestockOrder(order);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Order dicatat. Estimasi komisi: ${Formatters.currency(order.commission)}'),
          backgroundColor: AppTheme.successColor));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menyimpan order: $e'),
          backgroundColor: AppTheme.errorColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(currentUserProvider);
    final isOwner = (user?.role ?? 'cashier') == 'owner';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Kulakan B2B (Restock)',
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
                  _buildHeaderCard(isOwner),
                  const SizedBox(height: 16),
                  Text('RIWAYAT RESTOCK',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  if (_orders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Text('Belum ada order restock.',
                          style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary)),
                    )
                  else
                    ..._orders.map(_orderCard),
                  const SizedBox(height: 32),
                ],
              ),
            ),
      floatingActionButton: _cfg.isReady
          ? FloatingActionButton.extended(
              heroTag: 'restock_record',
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              onPressed: _recordOrder,
              icon: const Icon(Icons.fact_check_rounded),
              label: Text('Sudah Order',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _buildHeaderCard(bool isOwner) {
    if (!_cfg.isReady) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            const Icon(Icons.storefront_rounded,
                size: 40, color: AppTheme.textSecondary),
            const SizedBox(height: 10),
            Text('Katalog Distributor Belum Aktif',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Pengelola aplikasi belum mengatur link distributor B2B. '
              'Setelah aktif, kamu bisa restock grosir langsung dari sini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), AppTheme.successColor],
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
              const Icon(Icons.local_shipping_rounded,
                  size: 18, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_cfg.distributorName.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Restock grosir, harga distributor',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text(
            'Komisi platform ${_cfg.commissionPercent.toStringAsFixed(0)}% per order. '
            'Tracking_id outlet otomatis disertakan di katalog.',
            style: GoogleFonts.inter(
                fontSize: 11, color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _openCatalog,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('Buka Katalog Distributor',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.successColor,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(RestockOrder o) {
    final statusColor = switch (o.status) {
      'completed' || 'shipped' => AppTheme.successColor,
      'cancelled' => AppTheme.errorColor,
      'pending' || 'draft' => AppTheme.warningColor,
      _ => AppTheme.primaryColor,
    };
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
        leading: const Icon(Icons.inventory_2_rounded,
            size: 22, color: AppTheme.textSecondary),
        title: Text(o.itemsNote ?? o.distributor ?? 'Restock',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${o.trackingId ?? '-'} - ${_fmtTime(o.createdAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(Formatters.currency(o.amount),
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            Text('Komisi ${Formatters.currency(o.commission)}',
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppTheme.successColor)),
            Text(o.status.toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor)),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// WebView katalog distributor dengan DOMAIN LOCK (anti-bypass):
/// hanya host dari config yang boleh dibuka; redirect ke domain lain
/// diblokir. Tracking_id tampil di app bar untuk atribusi order.
class RestockWebViewScreen extends StatefulWidget {
  final String initialUrl;
  final String distributorName;
  final Set<String> allowedHosts;
  final String trackingId;

  const RestockWebViewScreen({
    super.key,
    required this.initialUrl,
    required this.distributorName,
    required this.allowedHosts,
    required this.trackingId,
  });

  @override
  State<RestockWebViewScreen> createState() => _RestockWebViewScreenState();
}

class _RestockWebViewScreenState extends State<RestockWebViewScreen> {
  late final WebViewController _controller;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.backgroundColor)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          final host = uri?.host.toLowerCase() ?? '';
          if (request.url.startsWith('data:') ||
              request.url.startsWith('about:')) {
            return NavigationDecision.prevent;
          }
          if (host.isEmpty) return NavigationDecision.navigate;
          final allowed = widget.allowedHosts.contains(host) ||
              widget.allowedHosts.any((h) => host.endsWith('.$h'));
          if (allowed) return NavigationDecision.navigate;
          // Anti-bypass: blokir redirect keluar domain distributor.
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Diblokir: $host bukan domain distributor.'),
              backgroundColor: AppTheme.errorColor));
          return NavigationDecision.prevent;
        },
        onPageFinished: (_) {
          if (mounted) setState(() {});
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _loadFailed = true);
        },
      ))
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.distributorName,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            Text('Tracking: ${widget.trackingId}',
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
              tooltip: 'Selesai order',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_rounded,
                  color: AppTheme.successColor)),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: AppTheme.warningColor.withValues(alpha: 0.12),
            child: Text(
              'Mode terkunci: hanya ${widget.distributorName}. '
              'Setelah order, tekan tombol centang lalu "Sudah Order".',
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: _loadFailed
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 40, color: AppTheme.textSecondary),
                        const SizedBox(height: 10),
                        Text('Gagal memuat katalog.',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.textSecondary)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _loadFailed = false);
                            _controller.loadRequest(
                                Uri.parse(widget.initialUrl));
                          },
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                : WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
