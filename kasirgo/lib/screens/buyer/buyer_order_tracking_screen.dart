import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../utils/wa_helper.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/centennial_background.dart';

/// ST17-6 (Phase 17 - Ekosistem Hyper-Local): pelacakan pesanan Pembeli.
///
/// Status realtime via `OrderService.watchOrder` (Supabase Realtime):
/// Menunggu Validasi Kasir -> Disiapkan -> Siap -> Selesai.
class BuyerOrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String? outletName;

  const BuyerOrderTrackingScreen({
    super.key,
    required this.orderId,
    this.outletName,
  });

  @override
  State<BuyerOrderTrackingScreen> createState() =>
      _BuyerOrderTrackingScreenState();
}

class _BuyerOrderTrackingScreenState extends State<BuyerOrderTrackingScreen> {
  final _service = OrderService();
  final _supabase = SupabaseService();

  StreamSubscription<Order?>? _sub;
  Order? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final order = await _service.getOrder(widget.orderId);
    if (!mounted) return;
    setState(() {
      _order = order;
      _loading = false;
    });
    _sub = _service.watchOrder(widget.orderId).listen((o) {
      if (!mounted || o == null) return;
      setState(() => _order = o);
    });
  }

  int get _stepIndex {
    final o = _order;
    if (o == null) return 0;
    if (o.status == 'selesai') return 4;
    if (o.status == 'siap') return 3;
    if (o.status == 'diproses') return 2;
    if (o.paymentStatus == 'divalidasi') return 1;
    return 0;
  }

  String _statusHeadline(Order? o) {
    if (o == null) return 'Memuat pesanan...';
    if (o.status == 'dibatalkan') return 'Pesanan dibatalkan';
    if (o.status == 'selesai') return 'Pesanan selesai';
    if (o.paymentStatus == 'ditolak') return 'Pembayaran ditolak kasir';
    if (o.paymentStatus != 'divalidasi') return 'Menunggu validasi kasir';
    if (o.status == 'siap') return 'Pesanan siap';
    return 'Pesanan sedang disiapkan';
  }

  Future<void> _sendWaSummary() async {
    final o = _order;
    if (o == null) return;
    final wa = await _supabase.getPublicOutletWa(o.outletId);
    if (!mounted) return;
    if (wa == null || wa.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WA warung belum tersedia.')),
      );
      return;
    }
    final buffer = StringBuffer()
      ..writeln('Halo, saya sudah pesan via aplikasi:')
      ..writeln('Kode: ${o.code ?? o.id}')
      ..writeln('Nama: ${o.buyerName ?? '-'}')
      ..writeln('Tipe: ${o.isDelivery ? 'Diantar' : 'Ambil sendiri'}');
    for (final item in o.items) {
      buffer.writeln('- ${item.nameSnapshot} x${item.qty.toInt()}');
    }
    buffer
      ..writeln('Subtotal: ${Formatters.currency(o.subtotal)}')
      ..writeln('Ongkir: ${Formatters.currency(o.deliveryFee)}')
      ..writeln('Total: ${Formatters.currency(o.total)}')
      ..writeln('Status bayar: '
          '${o.isPaid ? 'Sudah divalidasi' : 'Menunggu validasi'}');
    await WaHelper.sendWhatsAppMessage(phone: wa, message: buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        title: Text(
          'Lacak Pesanan',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: CentennialBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildStepper(),
                  const SizedBox(height: 16),
                  if (_order != null) _buildSummary(_order!),
                  const SizedBox(height: 16),
                  if (_order != null)
                    AppButton(
                      label: 'Kirim Ringkasan ke WA Warung',
                      icon: Icons.chat_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: _sendWaSummary,
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final o = _order;
    final canceled = o?.status == 'dibatalkan' || o?.paymentStatus == 'ditolak';
    final done = o?.status == 'selesai';
    final color = canceled
        ? AppTheme.errorColor
        : done
            ? AppTheme.successColor
            : AppTheme.primaryColor;
    return AppCard(
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Icon(
              canceled
                  ? Icons.cancel_rounded
                  : done
                      ? Icons.check_circle_rounded
                      : Icons.local_shipping_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusHeadline(o),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${o?.code ?? '-'}'
                  '${widget.outletName != null ? ' - ${widget.outletName}' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
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

  Widget _buildStepper() {
    final current = _stepIndex;
    final steps = <Map<String, dynamic>>[
      {'label': 'Pesanan dibuat', 'icon': Icons.receipt_long_rounded},
      {'label': 'Menunggu validasi kasir', 'icon': Icons.verified_rounded},
      {'label': 'Disiapkan', 'icon': Icons.inventory_2_rounded},
      {'label': 'Siap', 'icon': Icons.shopping_bag_rounded},
      {'label': 'Selesai', 'icon': Icons.check_circle_rounded},
    ];
    return AppCard(
      child: Column(
        children: List.generate(steps.length, (i) {
          final active = i <= current;
          final isLast = i == steps.length - 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    height: 30,
                    width: 30,
                    decoration: BoxDecoration(
                      color: active
                          ? AppTheme.primaryColor
                          : AppTheme.surfaceMutedColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      steps[i]['icon'] as IconData,
                      size: 16,
                      color: active ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 26,
                      color: i < current
                          ? AppTheme.primaryColor
                          : AppTheme.borderColor,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  steps[i]['label'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color:
                        active ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSummary(Order o) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rincian',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in o.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.nameSnapshot} x${item.qty.toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    Formatters.currency(item.lineTotal),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 20, color: AppTheme.borderColor),
          _row('Subtotal', Formatters.currency(o.subtotal)),
          if (o.isDelivery)
            _row('Ongkir', Formatters.currency(o.deliveryFee)),
          _row('Total', Formatters.currency(o.total), bold: true),
          const SizedBox(height: 8),
          _row(
            'Status bayar',
            o.isPaid ? 'Sudah divalidasi' : 'Menunggu validasi kasir',
          ),
          _row('Tipe', o.isDelivery ? 'Diantar' : 'Ambil sendiri'),
          if (o.note != null && o.note!.trim().isNotEmpty)
            _row('Catatan', o.note!),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: bold ? 14 : 12.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
