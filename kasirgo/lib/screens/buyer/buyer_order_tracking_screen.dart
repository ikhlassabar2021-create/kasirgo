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

  List<Map<String, dynamic>> get _steps {
    final delivery = _order?.isDelivery ?? false;
    return [
      {'label': 'Pesanan dibuat', 'icon': Icons.receipt_long_rounded},
      {'label': 'Menunggu validasi kasir', 'icon': Icons.verified_rounded},
      {'label': 'Disiapkan', 'icon': Icons.inventory_2_rounded},
      {'label': 'Siap', 'icon': Icons.shopping_bag_rounded},
      if (delivery) ...[
        {'label': 'Sedang diantar', 'icon': Icons.delivery_dining_rounded},
        {'label': 'Terkirim', 'icon': Icons.where_to_vote_rounded},
      ],
      {'label': 'Selesai', 'icon': Icons.check_circle_rounded},
    ];
  }

  int get _stepIndex {
    final o = _order;
    if (o == null) return 0;
    if (o.isDelivery) {
      if (o.status == 'selesai') return 6;
      if (o.status == 'terkirim') return 5;
      if (o.status == 'diantar') return 4;
    } else {
      if (o.status == 'selesai') return 4;
    }
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
    if (o.status == 'terkirim') return 'Pesanan sudah diterima';
    if (o.status == 'diantar') return 'Pesanan sedang diantar';
    if (o.status == 'siap') return 'Pesanan siap';
    return 'Pesanan sedang disiapkan';
  }

  Future<void> _confirmReceived() async {
    final o = _order;
    if (o == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Konfirmasi Terima',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text(
          'Tandai pesanan ini sudah Anda terima dari kurir?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Belum'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Sudah Diterima'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await _service.confirmReceived(orderId: o.id);
    if (!mounted) return;
    final success = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? 'Terima kasih, pesanan ditandai sudah diterima.'
          : 'Gagal: ${res['error'] ?? 'unknown'}'),
      backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
    ));
    if (success) {
      final fresh = await _service.getOrder(o.id);
      if (mounted && fresh != null) setState(() => _order = fresh);
    }
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
          style: GoogleFonts.plusJakartaSans(
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
                  if (_order != null &&
                      _order!.isDelivery &&
                      _order!.receiverCode != null) ...[
                    const SizedBox(height: 16),
                    _buildReceiverCodeCard(_order!),
                  ],
                  const SizedBox(height: 16),
                  if (_order != null) _buildSummary(_order!),
                  const SizedBox(height: 16),
                  if (_order != null && _order!.canBuyerConfirmReceived) ...[
                    AppButton(
                      label: 'Pesanan Sudah Saya Terima',
                      icon: Icons.where_to_vote_rounded,
                      onPressed: _confirmReceived,
                    ),
                    const SizedBox(height: 12),
                  ],
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${o?.code ?? '-'}'
                  '${widget.outletName != null ? ' - ${widget.outletName}' : ''}',
                  style: GoogleFonts.plusJakartaSans(
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
    final steps = _steps;
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
                  style: GoogleFonts.plusJakartaSans(
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

  Widget _buildReceiverCodeCard(Order o) {
    final code = o.receiverCode ?? '';
    final done = o.isDelivered || o.status == 'selesai';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_rounded,
                  size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Kode Penerima',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            done
                ? 'Pesanan sudah diterima.'
                : 'Bacakan kode ini ke kurir saat barang diserahkan sebagai bukti '
                    'bahwa Anda menerima pesanan.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 12,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
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
            style: GoogleFonts.plusJakartaSans(
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    Formatters.currency(item.lineTotal),
                    style: GoogleFonts.plusJakartaSans(
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
          if (o.isDelivery && o.courierLabel != null)
            _row('Kurir', o.courierLabel!),
          if (o.isDelivery && o.isOutForDelivery)
            _row('Pengiriman', 'Sedang diantar'),
          if (o.isDelivery && o.isDelivered)
            _row('Pengiriman', 'Terkirim'),
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
              style: GoogleFonts.plusJakartaSans(
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
              style: GoogleFonts.plusJakartaSans(
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
