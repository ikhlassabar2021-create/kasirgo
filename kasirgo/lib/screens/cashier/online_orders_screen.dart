import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../config/app_theme.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../services/order_service.dart';
import '../../utils/formatters.dart';

/// ST17-2 (Phase 17 - Ekosistem Hyper-Local): layar "Pesanan Online" untuk
/// owner/kasir. Pesanan dari app Pembeli (`orders`) ditampilkan realtime;
/// pembayaran QRIS statis/transfer divalidasi manual oleh kasir, lalu
/// dilanjutkan/diselesaikan. Lihat migrasi 2026-10-31-kasirgo-17a-hyperlocal.sql.
class OnlineOrdersScreen extends StatelessWidget {
  const OnlineOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(child: OnlineOrdersView(standalone: true)),
    );
  }
}

/// Konten daftar pesanan online. Dipakai sebagai tab di layar "Pesanan Masuk"
/// (dine-in) maupun sebagai layar mandiri.
class OnlineOrdersView extends ConsumerStatefulWidget {
  const OnlineOrdersView({super.key, this.standalone = false});

  final bool standalone;

  @override
  ConsumerState<OnlineOrdersView> createState() => _OnlineOrdersViewState();
}

class _OnlineOrdersViewState extends ConsumerState<OnlineOrdersView>
    with SingleTickerProviderStateMixin {
  final _service = OrderService();
  List<Order> _orders = [];
  bool _isLoading = true;
  String _filter = 'menunggu';
  sb.RealtimeChannel? _channel;
  final Set<String> _seen = {};
  final Set<String> _busyOrders = {};
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _blink.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _init() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    await _load();
    _subscribe(outletId);
  }

  Future<void> _load({bool silent = false}) async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null) return;
    if (!silent && mounted) setState(() => _isLoading = true);
    final list = await _service.listOrders(outletId);
    if (!mounted) return;
    setState(() {
      _orders = list;
      _isLoading = false;
    });
  }

  void _subscribe(String outletId) {
    _channel = sb.Supabase.instance.client
        .channel('online-orders-$outletId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'outlet_id',
            value: outletId,
          ),
          callback: (payload) {
            if (payload.eventType == sb.PostgresChangeEvent.insert) {
              final rec = payload.newRecord;
              final id = rec['id']?.toString();
              if (id != null && !_seen.contains(id)) {
                _seen.add(id);
                _announceNewOrder(rec);
              }
            }
            _load(silent: true);
          },
        )
        .subscribe();
  }

  void _announceNewOrder(Map<String, dynamic> rec) {
    final buyer = rec['buyer_name']?.toString();
    final code = rec['code']?.toString();
    final total = Order.fromJson(Map<String, dynamic>.from(rec)).total;
    final label = (buyer != null && buyer.trim().isNotEmpty) ? buyer : 'Pembeli';
    final title = 'Pesanan Online Baru';
    final body = '$label - ${code ?? ''} - ${Formatters.currency(total)}';

    SystemSound.play(SystemSoundType.alert);
    NotificationService.instance.showOrderNotification(
      title: title,
      body: body,
      payload: 'order:$code',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$title: $body'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ));
  }

  Future<void> _validate(Order order, bool accept) async {
    if (_busyOrders.contains(order.id)) return;
    setState(() => _busyOrders.add(order.id));
    try {
      final res = await _service.validateOrderPayment(
        orderId: order.id,
        accept: accept,
      );
      if (!mounted) return;
      final ok = res['success'] == true;
      final idempotent = res['idempotent'] == true;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(ok
              ? (idempotent
                  ? 'Pesanan ini sudah divalidasi sebelumnya.'
                  : (accept
                      ? 'Pembayaran valid. Pesanan diproses.'
                      : 'Pesanan ditolak / pembayaran belum masuk.'))
              : 'Gagal memproses: ${res['error'] ?? 'unknown'}'),
          backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
        ));
      if (ok) await _load(silent: true);
    } finally {
      if (mounted) setState(() => _busyOrders.remove(order.id));
    }
  }

  Future<void> _complete(Order order) async {
    if (_busyOrders.contains(order.id)) return;
    setState(() => _busyOrders.add(order.id));
    try {
      final res = await _service.completeOrder(order.id);
      if (!mounted) return;
      final ok = res['success'] == true;
      final idempotent = res['idempotent'] == true;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(ok
              ? (idempotent
                  ? 'Pesanan ini sudah diselesaikan sebelumnya.'
                  : 'Pesanan selesai. Transaksi tercatat.')
              : 'Gagal menyelesaikan: ${res['error'] ?? 'unknown'}'),
          backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
        ));
      if (ok) await _load(silent: true);
    } finally {
      if (mounted) setState(() => _busyOrders.remove(order.id));
    }
  }

  Future<void> _setCourier(Order order, String courier) async {
    if (_busyOrders.contains(order.id) || order.courier == courier) return;
    setState(() => _busyOrders.add(order.id));
    try {
      final ok = await _service.setOrderCourier(order.id, courier);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(ok
              ? 'Kurir: ${_courierName(courier)}'
              : 'Gagal memilih kurir'),
          backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
        ));
      if (ok) await _load(silent: true);
    } finally {
      if (mounted) setState(() => _busyOrders.remove(order.id));
    }
  }

  String _courierName(String c) {
    switch (c) {
      case 'kurir_warung':
        return 'Kurir Warung';
      case 'grab':
        return 'Grab';
      case 'gojek':
        return 'Gojek';
      default:
        return c;
    }
  }

  List<Order> get _filtered {
    switch (_filter) {
      case 'menunggu':
        return _orders
            .where((o) =>
                o.paymentStatus == 'belum_konfirmasi' &&
                o.status != 'dibatalkan')
            .toList();
      case 'aktif':
        return _orders
            .where((o) =>
                o.status != 'selesai' && o.status != 'dibatalkan')
            .toList();
      case 'selesai':
        return _orders.where((o) => o.status == 'selesai').toList();
      default:
        return _orders;
    }
  }

  int _countFor(String filter) {
    switch (filter) {
      case 'menunggu':
        return _orders
            .where((o) =>
                o.paymentStatus == 'belum_konfirmasi' &&
                o.status != 'dibatalkan')
            .length;
      case 'aktif':
        return _orders
            .where((o) =>
                o.status != 'selesai' && o.status != 'dibatalkan')
            .length;
      case 'selesai':
        return _orders.where((o) => o.status == 'selesai').length;
      default:
        return _orders.length;
    }
  }

  int get _pendingCount => _countFor('menunggu');

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      children: [
        if (widget.standalone) _header(),
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _chip('Menunggu Pengecekan', 'menunggu'),
              const SizedBox(width: 8),
              _chip('Aktif', 'aktif'),
              const SizedBox(width: 8),
              _chip('Selesai', 'selesai'),
              const SizedBox(width: 8),
              _chip('Semua', 'semua'),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : filtered.isEmpty
                  ? _empty()
                  : RefreshIndicator(
                      onRefresh: () => _load(),
                      color: AppTheme.primaryColor,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _orderCard(filtered[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      color: AppTheme.surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pesanan Online',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: AppTheme.successColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('Live - $_pendingCount menunggu pengecekan',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
            onPressed: () => _load(),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storefront_rounded, size: 56, color: AppTheme.borderColor),
          const SizedBox(height: 10),
          Text('Belum ada pesanan online',
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final sel = _filter == value;
    final count = _countFor(value);
    final warn = value == 'menunggu' && count > 0;
    return ChoiceChip(
      label: Text(count > 0 ? '$label ($count)' : label),
      selected: sel,
      showCheckmark: false,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.surfaceColor,
      side: BorderSide(
          color: sel
              ? AppTheme.primaryColor
              : warn
                  ? AppTheme.warningColor
                  : AppTheme.borderColor),
      labelStyle: TextStyle(
        color: sel
            ? Colors.white
            : warn
                ? AppTheme.warningColor
                : AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: sel ? FontWeight.bold : FontWeight.w500,
      ),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'baru':
        return AppTheme.warningColor;
      case 'diproses':
        return AppTheme.primaryColor;
      case 'siap':
        return AppTheme.secondaryColor;
      case 'dibatalkan':
        return AppTheme.errorColor;
      default:
        return AppTheme.successColor;
    }
  }

  String _timeAgo(DateTime? t) {
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  Widget _blinkBadge(String text) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.35).animate(_blink),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top_rounded,
                size: 12, color: AppTheme.warningColor),
            const SizedBox(width: 4),
            Text(text,
                style: GoogleFonts.inter(
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5)),
          ],
        ),
      ),
    );
  }

  Widget _courierRow(Order o) {
    const options = <List<Object>>[
      ['kurir_warung', 'Kurir Warung', Icons.storefront_rounded],
      ['grab', 'Grab', Icons.delivery_dining_rounded],
      ['gojek', 'Gojek', Icons.two_wheeler_rounded],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_shipping_rounded,
                size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text('Antar via',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final value = opt[0] as String;
            final label = opt[1] as String;
            final icon = opt[2] as IconData;
            final sel = o.courier == value;
            final busy = _busyOrders.contains(o.id);
            return GestureDetector(
              onTap: busy ? null : () => _setCourier(o, value),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primaryColor : AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                      color: sel ? AppTheme.primaryColor : AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 14,
                        color: sel ? Colors.white : AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Text(label,
                        style: GoogleFonts.inter(
                            color: sel ? Colors.white : AppTheme.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _orderCard(Order o) {
    final pending = o.paymentStatus == 'belum_konfirmasi' && o.status != 'dibatalkan';
    final canComplete = o.paymentStatus == 'divalidasi' && o.status != 'selesai';
    final color = _statusColor(o.status);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: pending
              ? AppTheme.warningColor.withValues(alpha: 0.6)
              : o.status == 'baru'
                  ? AppTheme.primaryColor.withValues(alpha: 0.4)
                  : AppTheme.borderColor,
          width: pending ? 1.6 : 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: o.isDelivery
                      ? AppTheme.accentColor.withValues(alpha: 0.14)
                      : AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      o.isDelivery
                          ? Icons.delivery_dining_rounded
                          : Icons.storefront_rounded,
                      size: 13,
                      color: o.isDelivery
                          ? AppTheme.accentColor
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                        o.isDelivery
                            ? (o.courierLabel != null
                                ? 'DIANTAR - ${o.courierLabel!.toUpperCase()}'
                                : 'DIANTAR')
                            : 'AMBIL',
                        style: GoogleFonts.inter(
                            color: o.isDelivery
                                ? AppTheme.accentColor
                                : AppTheme.primaryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(o.statusLabel.toUpperCase(),
                    style: GoogleFonts.inter(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5)),
              ),
              const Spacer(),
              Text(_timeAgo(o.createdAt),
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
          if (pending) ...[
            const SizedBox(height: 8),
            _blinkBadge('MENUNGGU PENGECEKAN KASIR'),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_rounded,
                  size: 15, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  o.buyerName?.trim().isNotEmpty == true
                      ? o.buyerName!
                      : 'Pembeli',
                  style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
              if (o.code != null && o.code!.isNotEmpty)
                Text('#${o.code}',
                    style: GoogleFonts.inter(
                        color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
          if (o.buyerPhone?.trim().isNotEmpty == true || o.distanceKm != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  if (o.buyerPhone?.trim().isNotEmpty == true) ...[
                    const Icon(Icons.phone_rounded,
                        size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(o.buyerPhone!,
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary, fontSize: 11.5)),
                  ],
                  if (o.buyerPhone?.trim().isNotEmpty == true &&
                      o.distanceKm != null)
                    const SizedBox(width: 12),
                  if (o.distanceKm != null) ...[
                    const Icon(Icons.near_me_rounded,
                        size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text('${o.distanceKm!.toStringAsFixed(1)} km',
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary, fontSize: 11.5)),
                  ],
                ],
              ),
            ),
          if (o.isDelivery && o.buyerAddress?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 14, color: AppTheme.accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        o.buyerAddress!,
                        style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 11.5,
                            height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          ...o.items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text('${_qty(it.qty)}x ',
                        style: GoogleFonts.inter(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5)),
                    Expanded(
                      child: Text(it.nameSnapshot,
                          style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ),
                    Text(Formatters.currency(it.lineTotal),
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary, fontSize: 11.5)),
                  ],
                ),
              )),
          const Divider(height: 18, color: AppTheme.borderColor),
          if (o.isDelivery && o.deliveryFee > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Ongkir (titipan kurir)',
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary, fontSize: 11.5)),
                  ),
                  Text(Formatters.currency(o.deliveryFee),
                      style: GoogleFonts.inter(
                          color: AppTheme.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text('Total',
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
              Text(Formatters.currency(o.total),
                  style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ],
          ),
          if (o.note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMutedColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Text('Catatan: ${o.note}',
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary, fontSize: 11.5)),
            ),
          ],
          if (o.isDelivery &&
              o.paymentStatus == 'divalidasi' &&
              o.status != 'selesai' &&
              o.status != 'dibatalkan') ...[
            const SizedBox(height: 12),
            _courierRow(o),
          ],
          if (pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _actionBtn('Pembayaran Valid & Proses',
                      AppTheme.successColor, () => _validate(o, true),
                      busy: _busyOrders.contains(o.id)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionBtn('Tolak / Belum Masuk',
                      AppTheme.errorColor, () => _validate(o, false),
                      busy: _busyOrders.contains(o.id)),
                ),
              ],
            ),
          ] else if (canComplete) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _actionBtn('Selesai', AppTheme.primaryColor,
                      () => _complete(o),
                      busy: _busyOrders.contains(o.id)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  Widget _actionBtn(String label, Color color, VoidCallback onTap,
      {bool busy = false}) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        onPressed: busy ? null : onTap,
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }
}
