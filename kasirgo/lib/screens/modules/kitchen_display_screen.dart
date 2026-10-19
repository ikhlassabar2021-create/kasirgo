import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/centennial_background.dart';

import '../../widgets/common/bubble_glass.dart';

class KitchenOrder {
  final String id;
  final String orderNumber;
  final String tableNumber;
  final DateTime orderTime;
  final List<KitchenOrderItem> items;
  String status; // 'pending' | 'cooking' | 'ready' | 'served'
  final String? notes;

  /// 'dine_in' (transaksi QR meja) atau 'online' (pesanan dari katalog web).
  final String source;

  KitchenOrder({
    required this.id,
    required this.orderNumber,
    required this.tableNumber,
    required this.orderTime,
    required this.items,
    this.status = 'pending',
    this.notes,
    this.source = 'dine_in',
  });
}

class KitchenOrderItem {
  final String name;
  final int quantity;
  final String? notes;

  KitchenOrderItem({
    required this.name,
    required this.quantity,
    this.notes,
  });
}

class KitchenDisplayScreen extends ConsumerStatefulWidget {
  const KitchenDisplayScreen({super.key, this.embedded = false});

  /// true bila ditampilkan di dalam shell lain (mis. role koki) sehingga
  /// Scaffold/AppBar sendiri tidak dirender.
  final bool embedded;

  @override
  ConsumerState<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends ConsumerState<KitchenDisplayScreen> {
  String _selectedFilter = 'all'; // all, pending, cooking, ready
  bool _isLoading = false;

  final List<KitchenOrder> _orders = [];

  sb.RealtimeChannel? _channel;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _loadRealTransactions();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribeRealtime());
    _tickTimer = Timer.periodic(
        const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _subscribeRealtime() {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null) return;
    _channel = sb.Supabase.instance.client
        .channel('owner-kds-$outletId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'outlet_id',
            value: outletId,
          ),
          callback: (_) => _loadRealTransactions(),
        )
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'outlet_id',
            value: outletId,
          ),
          callback: (_) => _loadRealTransactions(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  String _mapStatus(String s) {
    switch (s) {
      case 'diproses':
        return 'cooking';
      case 'siap':
        return 'ready';
      case 'selesai':
        return 'served';
      default:
        return 'pending';
    }
  }

  Future<void> _loadRealTransactions() async {
    final user = ref.read(currentUserProvider);
    if (user?.outletId == null) return;

    setState(() => _isLoading = true);
    try {
      final dineInFuture =
          SupabaseService().getDineInOrders(user!.outletId!, limit: 30);
      final onlineFuture = _loadOnlineOrders(user.outletId!);
      final txs = await dineInFuture;
      final online = await onlineFuture;
      if (mounted) {
        // Hanya pesanan yang SUDAH dikonfirmasi bayar oleh kasir yang
        // diteruskan ke dapur (payment_status != 'unpaid').
        final realOrders = txs
            .where((t) => t.paymentStatus != 'unpaid')
            .map((t) {
          final notes = t.notes?.trim();
          return KitchenOrder(
            id: t.id,
            orderNumber:
                '#${t.id.substring(0, t.id.length >= 4 ? 4 : t.id.length).toUpperCase()}',
            tableNumber: (notes?.isNotEmpty ?? false) ? notes! : 'Dine-In',
            orderTime: t.createdAt,
            status: _mapStatus(t.orderStatus),
            notes: t.notes,
            items: t.items
                .map((i) =>
                    KitchenOrderItem(name: i.productName, quantity: i.quantity))
                .toList(),
          );
        }).toList();

        setState(() {
          _orders
            ..clear()
            ..addAll(realOrders)
            ..addAll(online);
        });
      }
    } catch (_) {
      // keep current list on error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Pesanan online (katalog web) yang SUDAH divalidasi kasir dan masih
  /// diproses dapur. Transaksi baru dibuat saat kasir menekan "Selesaikan"
  /// (complete_order), jadi dapur hanya menggerakkan status order.
  Future<List<KitchenOrder>> _loadOnlineOrders(String outletId) async {
    final orders = await OrderService().listOrders(
      outletId,
      paymentStatus: 'divalidasi',
      limit: 30,
    );
    final startOfDay = DateTime.now().toLocal();
    final dayStart = DateTime(startOfDay.year, startOfDay.month, startOfDay.day);
    return orders.where((o) {
      final created = o.createdAt?.toLocal();
      if (created != null && created.isBefore(dayStart)) return false;
      return o.status == 'baru' || o.status == 'diproses' || o.status == 'siap';
    }).map((o) {
      final isDelivery = o.fulfillment == 'delivery';
      return KitchenOrder(
        id: o.id,
        orderNumber: (o.code?.isNotEmpty ?? false)
            ? o.code!
            : '#${o.id.substring(0, o.id.length >= 4 ? 4 : o.id.length).toUpperCase()}',
        tableNumber: isDelivery ? 'Antar (kurir)' : 'Ambil di toko',
        orderTime: o.createdAt?.toLocal() ?? DateTime.now(),
        status: _mapStatus(o.status),
        notes: o.note,
        source: 'online',
        items: o.items
            .map((i) => KitchenOrderItem(
                  name: i.nameSnapshot,
                  quantity: i.qty.round(),
                ))
            .toList(),
      );
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.errorColor;
      case 'cooking':
        return AppTheme.warningColor;
      case 'ready':
        return AppTheme.successColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'MENUNGGU';
      case 'cooking':
        return 'DIMASAK';
      case 'ready':
        return 'SIAP SAJI';
      default:
        return status.toUpperCase();
    }
  }

  void _nextStatus(KitchenOrder order) {
    String? dbStatus;
    setState(() {
      if (order.status == 'pending') {
        order.status = 'cooking';
        dbStatus = 'diproses';
      } else if (order.status == 'cooking') {
        order.status = 'ready';
        dbStatus = 'siap';
      } else if (order.status == 'ready' && order.source != 'online') {
        // Pesanan online tidak ditutup dari dapur: kasir yang menjalankan
        // complete_order agar transaksi & pelanggan tercatat.
        order.status = 'served';
        dbStatus = 'selesai';
      }
    });
    if (dbStatus != null && !order.id.startsWith('kds-')) {
      if (order.source == 'online') {
        OrderService().setOrderStatus(order.id, dbStatus!);
      } else {
        SupabaseService().setOrderStatus(order.id, dbStatus!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _orders.where((o) {
      if (o.status == 'served') return false;
      if (_selectedFilter == 'all') return true;
      return o.status == _selectedFilter;
    }).toList();

    final content = CentennialBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Semua Antrean (${_orders.where((o) => o.status != 'served').length})',
                      isSelected: _selectedFilter == 'all',
                      onTap: () => setState(() => _selectedFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Menunggu',
                      isSelected: _selectedFilter == 'pending',
                      badgeColor: AppTheme.errorColor,
                      onTap: () => setState(() => _selectedFilter = 'pending'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Dimasak',
                      isSelected: _selectedFilter == 'cooking',
                      badgeColor: AppTheme.warningColor,
                      onTap: () => setState(() => _selectedFilter = 'cooking'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Siap',
                      isSelected: _selectedFilter == 'ready',
                      badgeColor: AppTheme.successColor,
                      onTap: () => setState(() => _selectedFilter = 'ready'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.soup_kitchen_rounded, size: 64, color: AppTheme.borderColor),
                                const SizedBox(height: 12),
                                Text(
                                  'Semua Pesanan Dapur Selesai!',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Belum ada tiket antrean masak baru.',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 400,
                              mainAxisExtent: 320,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              final order = filtered[idx];
                              final statusColor = _getStatusColor(order.status);
                              final waitMinutes = DateTime.now().difference(order.orderTime).inMinutes;

                              return Card(
                                color: AppTheme.surfaceColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: order.status == 'pending'
                                        ? AppTheme.errorColor.withValues(alpha: 0.6)
                                        : AppTheme.borderColor,
                                    width: order.status == 'pending' ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                order.orderNumber,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 16,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (order.source == 'online') ...[
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.primaryColor
                                                            .withValues(alpha: 0.12),
                                                        borderRadius:
                                                            BorderRadius.circular(6),
                                                      ),
                                                      child: const Text(
                                                        'ONLINE',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w800,
                                                          color: AppTheme.primaryColor,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                  ],
                                                  Flexible(
                                                    child: Text(
                                                      order.tableNumber,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: AppTheme.primaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: statusColor),
                                                ),
                                                child: Text(
                                                  _getStatusLabel(order.status),
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${waitMinutes}m lalu',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: waitMinutes > 10 ? AppTheme.errorColor : AppTheme.textSecondary,
                                                  fontWeight: waitMinutes > 10 ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.warningColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Note: ${order.notes}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.warningColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Divider(height: 16, color: AppTheme.borderColor),
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: order.items.length,
                                          itemBuilder: (context, i) {
                                            final it = order.items[i];
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 3),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: 24,
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      '${it.quantity}x',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 14,
                                                        color: AppTheme.primaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          it.name,
                                                          style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w600,
                                                            color: AppTheme.textPrimary,
                                                          ),
                                                        ),
                                                        if (it.notes != null)
                                                          Text(
                                                            it.notes!,
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              color: AppTheme.textSecondary,
                                                              fontStyle: FontStyle.italic,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        height: AppTheme.touchTargetLarge,
                                        child: BubbleButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: order.status == 'ready'
                                                ? AppTheme.textSecondary
                                                : order.status == 'cooking'
                                                    ? AppTheme.successColor
                                                    : AppTheme.warningColor,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: (order.status == 'ready' &&
                                                  order.source == 'online')
                                              ? null
                                              : () => _nextStatus(order),
                                          child: Text(
                                            order.status == 'pending'
                                                ? 'MULAI MASAK'
                                                : order.status == 'cooking'
                                                    ? 'TANDAI SIAP SAJI'
                                                    : order.source == 'online'
                                                        ? 'SIAP - TUNGGU KASIR'
                                                        : 'SELESAIKAN ORDER',
                                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
             ],
           ),
         ),
       );

    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Kitchen Display (KDS)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
            onPressed: _loadRealTransactions,
          ),
        ],
      ),
      body: content,
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? badgeColor;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
