import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/centennial_background.dart';

class KitchenOrder {
  final String id;
  final String orderNumber;
  final String tableNumber;
  final DateTime orderTime;
  final List<KitchenOrderItem> items;
  String status; // 'pending' | 'cooking' | 'ready' | 'served'
  final String? notes;

  KitchenOrder({
    required this.id,
    required this.orderNumber,
    required this.tableNumber,
    required this.orderTime,
    required this.items,
    this.status = 'pending',
    this.notes,
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
  const KitchenDisplayScreen({super.key});

  @override
  ConsumerState<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends ConsumerState<KitchenDisplayScreen> {
  String _selectedFilter = 'all'; // all, pending, cooking, ready
  bool _isLoading = false;

  final List<KitchenOrder> _orders = [
    KitchenOrder(
      id: 'kds-1',
      orderNumber: '#01',
      tableNumber: 'Meja 3',
      orderTime: DateTime.now().subtract(const Duration(minutes: 12)),
      status: 'cooking',
      notes: 'Sambal dipisah',
      items: [
        KitchenOrderItem(name: 'Nasi Goreng Spesial', quantity: 2, notes: 'Pedas sedang'),
        KitchenOrderItem(name: 'Ayam Geprek Sambal Matah', quantity: 1),
        KitchenOrderItem(name: 'Es Teh Manis', quantity: 3),
      ],
    ),
    KitchenOrder(
      id: 'kds-2',
      orderNumber: '#02',
      tableNumber: 'Meja 1',
      orderTime: DateTime.now().subtract(const Duration(minutes: 5)),
      status: 'pending',
      items: [
        KitchenOrderItem(name: 'Mie Godhog Jawa', quantity: 1),
        KitchenOrderItem(name: 'Tahu Tempe Goreng', quantity: 1),
        KitchenOrderItem(name: 'Kopi Tubruk Robusta', quantity: 1),
      ],
    ),
    KitchenOrder(
      id: 'kds-3',
      orderNumber: '#03',
      tableNumber: 'Meja 5',
      orderTime: DateTime.now().subtract(const Duration(minutes: 20)),
      status: 'ready',
      notes: 'Bawa piring kecil 2',
      items: [
        KitchenOrderItem(name: 'Kwetiau Seafood Goreng', quantity: 2),
        KitchenOrderItem(name: 'Jus Alpukat', quantity: 2),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadRealTransactions();
  }

  Future<void> _loadRealTransactions() async {
    final user = ref.read(currentUserProvider);
    if (user?.outletId == null) return;

    setState(() => _isLoading = true);
    try {
      final txs = await SupabaseService().getTransactions(user!.outletId!, limit: 20);
      if (txs.isNotEmpty && mounted) {
        final realOrders = txs.take(6).map((t) {
          final isRecent = DateTime.now().difference(t.createdAt).inMinutes < 15;
          final status = isRecent ? 'cooking' : 'ready';
          return KitchenOrder(
            id: t.id,
            orderNumber: '#${t.id.substring(0, t.id.length >= 4 ? 4 : t.id.length).toUpperCase()}',
            tableNumber: t.notes?.contains('Meja') == true ? t.notes! : 'Dine-In',
            orderTime: t.createdAt,
            status: status,
            notes: t.notes,
            items: t.items.map((i) => KitchenOrderItem(name: i.productName, quantity: i.quantity)).toList(),
          );
        }).toList();

        setState(() {
          _orders.clear();
          _orders.addAll(realOrders);
        });
      }
    } catch (_) {
      // fallback sample orders
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    setState(() {
      if (order.status == 'pending') {
        order.status = 'cooking';
      } else if (order.status == 'cooking') {
        order.status = 'ready';
      } else if (order.status == 'ready') {
        order.status = 'served';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _orders.where((o) {
      if (o.status == 'served') return false;
      if (_selectedFilter == 'all') return true;
      return o.status == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Kitchen Display (KDS)',
          style: GoogleFonts.inter(
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
      body: CentennialBackground(
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
                                  style: GoogleFonts.inter(
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
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 16,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                order.tableNumber,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: AppTheme.primaryColor,
                                                ),
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
                                                  color: waitMinutes > 15 ? AppTheme.errorColor : AppTheme.textSecondary,
                                                  fontWeight: waitMinutes > 15 ? FontWeight.bold : FontWeight.normal,
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
                                                      style: GoogleFonts.inter(
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
                                        child: ElevatedButton(
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
                                          onPressed: () => _nextStatus(order),
                                          child: Text(
                                            order.status == 'pending'
                                                ? 'MULAI MASAK'
                                                : order.status == 'cooking'
                                                    ? 'TANDAI SIAP SAJI'
                                                    : 'SELESAIKAN ORDER',
                                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
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
      ),
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
