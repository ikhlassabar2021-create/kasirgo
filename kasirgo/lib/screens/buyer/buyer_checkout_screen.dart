import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_theme.dart';
import '../../models/app_customer.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/order_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../utils/wa_helper.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/centennial_background.dart';
import 'buyer_order_tracking_screen.dart';
import '../../utils/error_messages.dart';

/// ST17-6 (Phase 17 - Ekosistem Hyper-Local): Checkout Pembeli.
///
/// Pilih Ambil Sendiri (Click & Collect) atau Diantar (ongkir otomatis dari
/// `delivery_rules` via RPC `submit_order`) -> tulis `orders`. Setelah pesanan
/// dibuat, tampil QRIS statis / rekening warung + tombol "Saya Sudah Bayar".
/// Bukti transfer disimpan LOKAL di HP Pembeli (tanpa Storage/R2).
class BuyerCheckoutScreen extends ConsumerStatefulWidget {
  final String outletId;
  final String outletName;
  final AppCustomer customer;
  final bool hasDelivery;
  final double? buyerLat;
  final double? buyerLng;

  const BuyerCheckoutScreen({
    super.key,
    required this.outletId,
    required this.outletName,
    required this.customer,
    this.hasDelivery = false,
    this.buyerLat,
    this.buyerLng,
  });

  @override
  ConsumerState<BuyerCheckoutScreen> createState() =>
      _BuyerCheckoutScreenState();
}

class _BuyerCheckoutScreenState extends ConsumerState<BuyerCheckoutScreen> {
  final _orderService = OrderService();
  final _supabase = SupabaseService();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String _fulfillment = 'pickup';
  bool _submitting = false;
  bool _loadingPayment = true;

  Map<String, dynamic>? _created;
  Map<String, dynamic>? _payment;
  bool _proofSaved = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.customer.name ?? '';
    _phoneCtrl.text = widget.customer.phone ?? '';
    _prefillFromProfile();
    _loadPaymentInfo();
  }

  /// Isi otomatis dari akun Pembeli LOKAL (nama, nohp, alamat).
  Future<void> _prefillFromProfile() async {
    final profile = await ref.read(buyerProfileServiceProvider).load();
    if (!mounted || profile == null) return;
    setState(() {
      if (_nameCtrl.text.trim().isEmpty && profile.hasName) {
        _nameCtrl.text = profile.name;
      }
      if (_phoneCtrl.text.trim().isEmpty && profile.hasPhone) {
        _phoneCtrl.text = profile.phone;
      }
      if (_addressCtrl.text.trim().isEmpty && profile.hasAddress) {
        _addressCtrl.text = profile.address;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentInfo() async {
    final data = await _supabase.getPublicOutletPayment(widget.outletId);
    if (!mounted) return;
    setState(() {
      _payment = data;
      _loadingPayment = false;
    });
  }

  String _str(Map<String, dynamic>? m, String key) {
    final v = m?[key];
    return v == null ? '' : v.toString();
  }

  /// Terjemahkan kode error RPC `submit_order` menjadi pesan yang bisa
  /// ditindaklanjuti pembeli (bukan kode mentah).
  String _orderErrorMessage(String raw) {
    switch (raw) {
      case 'AUTH_REQUIRED':
        return 'Sesi Anda berakhir. Silakan masuk lagi untuk melanjutkan.';
      case 'OUTLET_NOT_FOUND':
        return 'Warung tidak ditemukan atau sedang tidak menerima pesanan.';
      case 'EMPTY_CART':
        return 'Keranjang kosong. Pilih produk terlebih dahulu.';
      case 'ADDRESS_REQUIRED':
        return 'Alamat lengkap wajib diisi untuk pengantaran.';
      case 'PRODUCT_NOT_FOUND':
        return 'Salah satu produk tidak lagi tersedia. Hapus dari keranjang lalu pilih lagi.';
      case 'PRODUCT_NOT_PUBLISHED':
        return 'Salah satu produk sedang tidak dijual online. Hapus dari keranjang lalu pilih produk lain.';
      case 'OUT_OF_DELIVERY_RANGE':
        return 'Alamat Anda di luar jangkauan antar warung ini. Silakan pilih ambil sendiri.';
      case 'BUYER_BLOCKED':
        return 'Pesanan tidak dapat dibuat. Silakan hubungi warung langsung.';
      default:
        // Kode teknis (mis. OUTLET_CLOSED) jangan ditampilkan mentah.
        if (raw.isEmpty || RegExp(r'^[A-Z_]+$').hasMatch(raw)) {
          return 'Pesanan gagal dibuat. Periksa koneksi lalu coba lagi.';
        }
        return friendlyError(
          raw,
          fallback: 'Pesanan gagal dibuat. Periksa koneksi lalu coba lagi.',
        );
    }
  }

  Future<void> _promptRelogin() async {
    ref.invalidate(appCustomerProvider);
    final goLogin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sesi berakhir'),
        content: const Text(
            'Silakan masuk kembali supaya pesanan bisa dibuat dan dipantau.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Nanti'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Masuk'),
          ),
        ],
      ),
    );
    if (!mounted || goLogin != true) return;
    Navigator.of(context).pop();
    if (mounted) context.go('/buyer');
  }

  Future<void> _submit() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    if (cart.outletId.isNotEmpty && cart.outletId != widget.outletId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Keranjang berisi produk dari warung lain. Kosongkan dulu lalu pilih produk warung ini.'),
        ),
      );
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp wajib diisi.')),
      );
      return;
    }
    if (_fulfillment == 'delivery' && _addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alamat lengkap wajib diisi untuk pengantaran.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    final res = await _orderService.submitOrder(
      outletId: widget.outletId,
      items: cart.items.map((e) => e.toOrderItem()).toList(),
      fulfillment: _fulfillment,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      buyerLat: widget.buyerLat,
      buyerLng: widget.buyerLng,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address:
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res['success'] == true) {
      ref.read(cartProvider.notifier).clear();
      setState(() => _created = res);
    } else {
      final raw = res['error']?.toString() ?? '';
      if (raw == 'AUTH_REQUIRED') {
        await _promptRelogin();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_orderErrorMessage(raw)),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _pickProof() async {
    final o = _created;
    if (o == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        imageQuality: 70,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'order_proof_${o['order_id']}',
        base64Encode(bytes),
      );
      if (!mounted) return;
      setState(() => _proofSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bukti disimpan di perangkat ini (tidak diunggah).'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: 'Gagal memilih bukti. Silakan coba lagi.'))),
      );
    }
  }

  Future<void> _sendWaSummary() async {
    final o = _created;
    if (o == null) return;
    final wa = await _supabase.getPublicOutletWa(widget.outletId);
    if (!mounted) return;
    if (wa == null || wa.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WA warung belum tersedia.')),
      );
      return;
    }
    final total = (o['total'] as num?)?.toDouble() ?? 0;
    final subtotal = (o['subtotal'] as num?)?.toDouble() ?? 0;
    final fee = (o['delivery_fee'] as num?)?.toDouble() ?? 0;
    final uniqueCode = (o['unique_code'] as num?)?.toInt();
    final payAmount = (o['pay_amount'] as num?)?.toDouble() ??
        total + (uniqueCode ?? 0);
    final code = '${o['code'] ?? o['order_id']}';
    final buffer = StringBuffer()
      ..writeln('Halo ${widget.outletName}, saya sudah pesan via aplikasi:')
      ..writeln('Kode: $code')
      ..writeln('Nama: ${_nameCtrl.text.trim()}')
      ..writeln('Tipe: ${_fulfillment == 'delivery' ? 'Diantar' : 'Ambil sendiri'}');
    if (_fulfillment == 'delivery' && _addressCtrl.text.trim().isNotEmpty) {
      buffer.writeln('Alamat: ${_addressCtrl.text.trim()}');
    }
    for (final item in ref.read(cartProvider).items) {
      buffer.writeln('- ${item.name} x${item.qty}');
    }
    buffer
      ..writeln('Subtotal: ${Formatters.currency(subtotal)}')
      ..writeln('Ongkir: ${Formatters.currency(fee)}')
      ..writeln('Total: ${Formatters.currency(total)}');
    if (uniqueCode != null) {
      buffer
        ..writeln('Kode unik: $uniqueCode')
        ..writeln('Transfer TEPAT: ${Formatters.currency(payAmount)}')
        ..writeln('Catatan transfer WAJIB: $code');
    }
    buffer.writeln('Status: Menunggu validasi kasir');
    await WaHelper.sendWhatsAppMessage(phone: wa, message: buffer.toString());
  }

  void _openTracking() {
    final o = _created;
    if (o == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BuyerOrderTrackingScreen(
          orderId: o['order_id'].toString(),
          outletName: widget.outletName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        title: Text(
          _created == null ? 'Checkout' : 'Pesanan Dibuat',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: CentennialBackground(
        child: _created == null
            ? _buildForm(cart)
            : _buildPaymentPanel(_created!),
      ),
    );
  }

  Widget _buildForm(dynamic cart) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.outletName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              for (final item in cart.items as List)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.name} x${item.qty}',
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
              Row(
                children: [
                  Text(
                    'Subtotal',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Formatters.currency(cart.subtotal),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cara Terima',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _fulfillOption(
                'pickup',
                'Ambil Sendiri',
                'Datang ke warung (Click & Collect)',
                Icons.storefront_rounded,
              ),
              if (widget.hasDelivery) ...[
                const SizedBox(height: 8),
                _fulfillOption(
                  'delivery',
                  'Diantar',
                  'Ongkir otomatis dari aturan warung',
                  Icons.delivery_dining_rounded,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _nameCtrl,
                label: 'Nama',
                hint: 'Nama penerima',
                prefixIcon: Icons.person_rounded,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _phoneCtrl,
                label: 'Nomor WhatsApp',
                hint: '08xxxxxxxxxx',
                prefixIcon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),
              if (_fulfillment == 'delivery') ...[
                const SizedBox(height: 12),
                AppTextField(
                  controller: _addressCtrl,
                  label: 'Alamat Lengkap (wajib untuk diantar)',
                  hint: 'Jl. / Gang, No. rumah, RT/RW, patokan, kelurahan',
                  prefixIcon: Icons.location_on_rounded,
                  maxLines: 3,
                ),
              ],
              const SizedBox(height: 12),
              AppTextField(
                controller: _noteCtrl,
                label: 'Catatan (opsional)',
                hint: 'Mis. tanpa sambal, antar ke pagar',
                prefixIcon: Icons.notes_rounded,
                maxLines: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Buat Pesanan',
          icon: Icons.check_rounded,
          isLoading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
      ],
    );
  }

  Widget _fulfillOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final selected = _fulfillment == value;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      onTap: () => setState(() => _fulfillment = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.06)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentPanel(Map<String, dynamic> o) {
    final total = (o['total'] as num?)?.toDouble() ?? 0;
    final subtotal = (o['subtotal'] as num?)?.toDouble() ?? 0;
    final fee = (o['delivery_fee'] as num?)?.toDouble() ?? 0;
    final uniqueCode = (o['unique_code'] as num?)?.toInt();
    final payAmount =
        (o['pay_amount'] as num?)?.toDouble() ?? total + (uniqueCode ?? 0);
    final orderCode = '${o['code'] ?? ''}';
    final bank = _str(_payment, 'bank_wallet');
    final account = _str(_payment, 'account_number');
    final merchant = _str(_payment, 'merchant_name');
    final qrisImage = _str(_payment, 'qris_image');

    Uint8List? qrisBytes;
    if (qrisImage.trim().isNotEmpty) {
      try {
        qrisBytes = base64Decode(qrisImage);
      } catch (_) {
        qrisBytes = null;
      }
    }
    // QRIS hanya bisa discan bila gambar benar-benar ada. NMID tanpa gambar
    // tidak cukup — jangan tampilkan blok "Scan QRIS" yang menyesatkan.
    final hasQris = qrisBytes != null;
    final hasBank = account.isNotEmpty || bank.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pesanan ${o['code'] ?? ''} dibuat',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _row('Subtotal', Formatters.currency(subtotal)),
              if (_fulfillment == 'delivery')
                _row('Ongkir', Formatters.currency(fee)),
              _row('Total', Formatters.currency(total)),
              if (uniqueCode != null) ...[
                _row('Kode unik', '+$uniqueCode'),
                const SizedBox(height: 4),
                _row('Transfer tepat', Formatters.currency(payAmount),
                    bold: true),
              ] else
                _row('Transfer', Formatters.currency(total), bold: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pembayaran',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              if (_loadingPayment)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (hasQris) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            qrisBytes,
                            height: 220,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.qr_code_2_rounded,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Scan QRIS ${merchant.isNotEmpty ? merchant : widget.outletName} '
                              'senilai ${Formatters.currency(payAmount)}, lalu tekan '
                              '"Saya Sudah Bayar".',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                height: 1.35,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else if (hasBank) ...[
                if (bank.isNotEmpty) _row('Bank / E-Wallet', bank),
                if (account.isNotEmpty) _row('No. Rekening', account),
                if (uniqueCode != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transfer TEPAT ${Formatters.currency(payAmount)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Jangan dibulatkan (nominal unik agar kasir mudah '
                          'mencocokkan). Isi catatan/berita transfer dengan '
                          'kode: $orderCode',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            height: 1.35,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else
                Text(
                  'Warung belum mengatur info pembayaran. Bayar tunai di kasir.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: _proofSaved ? 'Bukti Tersimpan' : 'Saya Sudah Bayar',
          icon: _proofSaved ? Icons.check_rounded : Icons.upload_rounded,
          variant:
              _proofSaved ? AppButtonVariant.secondary : AppButtonVariant.primary,
          onPressed: _pickProof,
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Kirim Ringkasan ke WA Warung',
          icon: Icons.chat_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: _sendWaSummary,
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Lacak Pesanan',
          icon: Icons.local_shipping_rounded,
          onPressed: _openTracking,
        ),
      ],
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
