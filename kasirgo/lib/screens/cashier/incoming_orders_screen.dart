import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../config/app_theme.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

class IncomingOrdersScreen extends ConsumerStatefulWidget {
  const IncomingOrdersScreen({super.key});

  @override
  ConsumerState<IncomingOrdersScreen> createState() =>
      _IncomingOrdersScreenState();
}

class _IncomingOrdersScreenState extends ConsumerState<IncomingOrdersScreen> {
  final _service = SupabaseService();
  List<Transaction> _orders = [];
  bool _isLoading = true;
  String _filter = 'aktif';
  sb.RealtimeChannel? _channel;
  final Set<String> _seen = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
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
    final list = await _service.getDineInOrders(outletId);
    if (!mounted) return;
    setState(() {
      _orders = list;
      _isLoading = false;
    });
  }

  void _subscribe(String outletId) {
    _channel = sb.Supabase.instance.client
        .channel('dinein-$outletId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'outlet_id',
            value: outletId,
          ),
          callback: (payload) {
            final rec = payload.newRecord;
            final ch = rec['channel']?.toString();
            if (ch != null && ch.isNotEmpty && ch != 'dine_in') return;

            if (payload.eventType == sb.PostgresChangeEvent.insert) {
              final id = rec['id']?.toString();
              if (id != null && !_seen.contains(id)) {
                _seen.add(id);
                SystemSound.play(SystemSoundType.alert);
                if (mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(
                      content: Text('Pesanan baru masuk!'),
                      backgroundColor: AppTheme.primaryColor,
                      duration: Duration(seconds: 2),
                    ));
                }
              }
            }
            _load(silent: true);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _setStatus(Transaction tx, String status) async {
    final ok = await _service.setOrderStatus(tx.id, status);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal mengubah status pesanan'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    await _load(silent: true);
  }

  List<Transaction> get _filtered {
    switch (_filter) {
      case 'baru':
        return _orders.where((o) => o.orderStatus == 'baru').toList();
      case 'selesai':
        return _orders.where((o) => o.orderStatus == 'selesai').toList();
      case 'aktif':
        return _orders.where((o) => o.orderStatus != 'selesai').toList();
      default:
        return _orders;
    }
  }

  int get _activeCount =>
      _orders.where((o) => o.orderStatus != 'selesai').length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pesanan Masuk',
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
                Text('Live - $_activeCount pesanan aktif',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
            onPressed: () => _load(),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _chip('Aktif', 'aktif'),
                const SizedBox(width: 8),
                _chip('Baru', 'baru'),
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
                    child:
                        CircularProgressIndicator(color: AppTheme.primaryColor))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inbox_rounded,
                                size: 56, color: AppTheme.borderColor),
                            const SizedBox(height: 10),
                            Text('Belum ada pesanan masuk',
                                style: GoogleFonts.inter(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13)),
                          ],
                        ),
                      )
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
      ),
    );
  }

  Widget _chip(String label, String value) {
    final sel = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      showCheckmark: false,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.surfaceColor,
      side: BorderSide(
          color: sel ? AppTheme.primaryColor : AppTheme.borderColor),
      labelStyle: TextStyle(
        color: sel ? Colors.white : AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: sel ? FontWeight.bold : FontWeight.w500,
      ),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'baru':
        return AppTheme.errorColor;
      case 'diproses':
        return AppTheme.warningColor;
      case 'siap':
        return AppTheme.primaryColor;
      default:
        return AppTheme.successColor;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'baru':
        return 'BARU';
      case 'diproses':
        return 'DIPROSES';
      case 'siap':
        return 'SIAP SAJI';
      case 'selesai':
        return 'SELESAI';
      default:
        return s.toUpperCase();
    }
  }

  String _methodLabel(String m) {
    switch (m) {
      case 'qris':
        return 'QRIS';
      case 'bank_transfer':
        return 'Transfer';
      case 'cash':
        return 'Tunai';
      default:
        return m;
    }
  }

  IconData _methodIcon(String m) {
    switch (m) {
      case 'qris':
        return Icons.qr_code_2_rounded;
      case 'bank_transfer':
        return Icons.account_balance_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  Widget _orderCard(Transaction tx) {
    final table = (tx.notes?.trim().isNotEmpty ?? false) ? tx.notes! : 'Dine-In';
    final color = _statusColor(tx.orderStatus);
    final isSelesai = tx.orderStatus == 'selesai';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tx.orderStatus == 'baru'
              ? AppTheme.errorColor.withValues(alpha: 0.45)
              : AppTheme.borderColor,
          width: tx.orderStatus == 'baru' ? 1.6 : 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  table,
                  style: GoogleFonts.inter(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _statusLabel(tx.orderStatus),
                  style: GoogleFonts.inter(
                      color: color, fontWeight: FontWeight.w800, fontSize: 10.5),
                ),
              ),
              const Spacer(),
              Text(_timeAgo(tx.createdAt),
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          ...tx.items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text('${it.quantity}x ',
                        style: GoogleFonts.inter(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5)),
                    Expanded(
                      child: Text(
                        it.productName,
                        style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(Formatters.currency(it.subtotal),
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary, fontSize: 11.5)),
                  ],
                ),
              )),
          const Divider(height: 18, color: AppTheme.borderColor),
          Row(
            children: [
              Icon(_methodIcon(tx.paymentMethod),
                  size: 16, color: AppTheme.successColor),
              const SizedBox(width: 6),
              Text(
                '${_methodLabel(tx.paymentMethod)} - dikonfirmasi pelanggan',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
              const Spacer(),
              Text(
                Formatters.currency(tx.finalAmount),
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          if (!isSelesai) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (tx.orderStatus == 'baru')
                  Expanded(
                    child: _actionBtn('Proses', AppTheme.warningColor,
                        () => _setStatus(tx, 'diproses')),
                  ),
                if (tx.orderStatus == 'diproses')
                  Expanded(
                    child: _actionBtn('Siap Saji', AppTheme.primaryColor,
                        () => _setStatus(tx, 'siap')),
                  ),
                if (tx.orderStatus == 'siap')
                  Expanded(
                    child: _actionBtn('Selesai', AppTheme.successColor,
                        () => _setStatus(tx, 'selesai')),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        onPressed: onTap,
        child: Text(label,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}
