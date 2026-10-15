import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/outlet_location.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../utils/geo.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';

/// ST17-7 (Phase 17 - Ekosistem Hyper-Local): Lapak Live owner.
///
/// Menggabungkan:
///  - Gerobak keliling: toggle "Buka Lapak" (outlets.is_open) + broadcast
///    lokasi berkala ke `outlet_locations` selama layar terbuka.
///  - Antrean jasa (bengkel/cukur): aktifkan antrean + kelola nomor.
class LapakLiveScreen extends ConsumerStatefulWidget {
  const LapakLiveScreen({super.key, this.locationService, this.service});

  final LocationService? locationService;
  final SupabaseService? service;

  @override
  ConsumerState<LapakLiveScreen> createState() => _LapakLiveScreenState();
}

class _LapakLiveScreenState extends ConsumerState<LapakLiveScreen> {
  late final LocationService _loc = widget.locationService ?? LocationService();
  late final SupabaseService _supabase = widget.service ?? SupabaseService();

  bool _loading = true;
  bool _saving = false;

  bool _isOpen = false;
  bool _isMobile = false;
  bool _queueEnabled = false;

  bool _manualOngkir = false;
  final TextEditingController _manualCtrl = TextEditingController();

  List<String> _allCategories = [];

  /// Item 1: tipe usaha outlet (menggantikan "Kategori Produk Aktif").
  String _businessType = '';

  double? _lat;
  double? _lng;
  DateTime? _locationUpdatedAt;

  StreamSubscription<List<ServiceQueueEntry>>? _queueSub;
  List<ServiceQueueEntry> _queue = const [];

  /// Item 1: pilih tipe usaha (satu pilihan).
  void _selectBusinessType(String type) {
    setState(() => _businessType = type);
  }

  Future<void> _saveBusinessType() async {
    final outletId = _outletId;
    if (outletId.isEmpty || _businessType.isEmpty) return;

    setState(() => _saving = true);
    final ok = await _supabase.updateOutletType(
      outletId: outletId,
      businessType: _businessType,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    _snack(
      ok ? 'Tipe usaha disimpan.' : 'Gagal menyimpan tipe usaha.',
      ok ? AppTheme.successColor : AppTheme.errorColor,
    );
  }

  Timer? _broadcastTimer;

  String get _outletId => ref.read(currentUserProvider)?.outletId ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _broadcastTimer?.cancel();
    _queueSub?.cancel();
    _manualCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final outletId = _outletId;
    if (outletId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final cfg = await _supabase.getOutletLiveConfig(outletId);
    final loc = await _loc.getOutletLocation(outletId);
    final rules = await _supabase.getOutletDeliveryRules(outletId);
    if (!mounted) return;

    final manualValue = (rules['manual_value'] as num?)?.toDouble() ?? 0;

    // Item 1: tipe usaha outlet (kanonik, case-insensitive match ke daftar).
    final rawType = (cfg?['type'] as String?)?.trim() ?? '';
    final businessTypes = AppConstants.businessTypes;
    final matchedType = businessTypes.firstWhere(
      (t) => t.toLowerCase() == rawType.toLowerCase(),
      orElse: () => rawType.isEmpty ? businessTypes.first : rawType,
    );

    setState(() {
      _isOpen = cfg?['is_open'] == true;
      _isMobile = cfg?['is_mobile'] == true;
      _queueEnabled = cfg?['service_queue_enabled'] == true;
      _manualOngkir = rules['manual'] == true;
      _manualCtrl.text = manualValue > 0 ? manualValue.toStringAsFixed(0) : '';
      _allCategories = businessTypes;
      _businessType = matchedType;
      _lat = loc?.latitude;
      _lng = loc?.longitude;
      _locationUpdatedAt = loc?.updatedAt;
      _loading = false;
    });

    _startQueueWatch();
    _restartBroadcast();
  }

  void _startQueueWatch() {
    _queueSub?.cancel();
    if (_outletId.isEmpty) return;
    _queueSub = _loc.watchQueue(_outletId).listen((rows) {
      if (!mounted) return;
      setState(() => _queue = rows);
    });
  }

  void _restartBroadcast() {
    _broadcastTimer?.cancel();
    if (_isOpen && _isMobile) {
      _broadcastTimer =
          Timer.periodic(const Duration(seconds: 60), (_) => _broadcast(silent: true));
    }
  }

  Future<void> _broadcast({bool silent = false}) async {
    final outletId = _outletId;
    if (outletId.isEmpty) return;

    final detected = await getBrowserPosition();
    final pos = detected ??
        ((_lat != null && _lng != null)
            ? GeoPosition(lat: _lat!, lng: _lng!)
            : null);
    if (pos == null) {
      if (!silent) _enterManualCoordinates();
      return;
    }

    final ok = await _loc.updateOutletLocation(
      outletId: outletId,
      lat: pos.lat,
      lng: pos.lng,
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _lat = pos.lat;
        _lng = pos.lng;
        _locationUpdatedAt = DateTime.now();
      });
      if (!silent) {
        _snack('Lokasi lapak diperbarui.', AppTheme.successColor);
      }
    } else if (!silent) {
      _snack('Gagal memperbarui lokasi.', AppTheme.errorColor);
    }
  }

  Future<void> _enterManualCoordinates() async {
    final latCtl = TextEditingController(text: _lat?.toStringAsFixed(6) ?? '');
    final lngCtl = TextEditingController(text: _lng?.toStringAsFixed(6) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Text('Koordinat Lapak',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: latCtl,
              label: 'Latitude',
              hint: '-6.200000',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: lngCtl,
              label: 'Longitude',
              hint: '106.800000',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Simpan',
                style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final lat = double.tryParse(latCtl.text.trim());
    final lng = double.tryParse(lngCtl.text.trim());
    if (lat == null || lng == null) {
      _snack('Koordinat tidak valid.', AppTheme.errorColor);
      return;
    }
    final outletId = _outletId;
    if (outletId.isEmpty) return;

    setState(() => _saving = true);
    await _supabase.setOutletCoordinates(
        outletId: outletId, lat: lat, lng: lng);
    final ok2 =
        await _loc.updateOutletLocation(outletId: outletId, lat: lat, lng: lng);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok2) {
        _lat = lat;
        _lng = lng;
        _locationUpdatedAt = DateTime.now();
      }
    });
    if (ok2) {
      _snack('Lokasi lapak disimpan.', AppTheme.successColor);
    } else {
      _snack('Gagal menyimpan lokasi.', AppTheme.errorColor);
    }
  }

  Future<void> _setFlag({
    bool? isOpen,
    bool? isMobile,
    bool? serviceQueueEnabled,
  }) async {
    final outletId = _outletId;
    if (outletId.isEmpty) return;

    setState(() {
      if (isOpen != null) _isOpen = isOpen;
      if (isMobile != null) _isMobile = isMobile;
      if (serviceQueueEnabled != null) _queueEnabled = serviceQueueEnabled;
      _saving = true;
    });

    final ok = await _supabase.setOutletLiveFlags(
      outletId: outletId,
      isOpen: isOpen,
      isMobile: isMobile,
      serviceQueueEnabled: serviceQueueEnabled,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      _snack('Gagal menyimpan pengaturan.', AppTheme.errorColor);
      _load();
      return;
    }

    _restartBroadcast();
    if (isOpen == true && isMobile == true) {
      await _broadcast(silent: true);
    }
  }

  double get _manualValue =>
      double.tryParse(_manualCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  Future<void> _setManualOngkir(bool enabled) async {
    final outletId = _outletId;
    if (outletId.isEmpty) return;

    setState(() {
      _manualOngkir = enabled;
      _saving = true;
    });

    final ok = await _supabase.saveOutletManualOngkir(
      outletId: outletId,
      enabled: enabled,
      value: _manualValue,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      _snack('Gagal menyimpan ongkir manual.', AppTheme.errorColor);
      _load();
      return;
    }
    _snack(
      enabled
          ? 'Ongkir manual aktif: ${Formatters.currency(_manualValue)}.'
          : 'Ongkir manual dimatikan (otomatis).',
      AppTheme.successColor,
    );
  }

  Future<void> _saveManualValue() async {
    if (_manualValue <= 0) {
      _snack('Isi nominal ongkir manual.', AppTheme.errorColor);
      return;
    }
    final outletId = _outletId;
    if (outletId.isEmpty) return;

    setState(() => _saving = true);
    final ok = await _supabase.saveOutletManualOngkir(
      outletId: outletId,
      enabled: true,
      value: _manualValue,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    _snack(
      ok ? 'Ongkir manual disimpan.' : 'Gagal menyimpan ongkir manual.',
      ok ? AppTheme.successColor : AppTheme.errorColor,
    );
  }

  Future<void> _setQueueStatus(ServiceQueueEntry entry, String status) async {
    final ok = await _loc.setQueueStatus(entry.id, status);
    if (!mounted) return;
    if (ok) {
      _snack('Antrean #${entry.number} -> $status.', AppTheme.successColor);
    } else {
      _snack('Gagal memperbarui antrean.', AppTheme.errorColor);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Lapak Live',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
               children: [
                 _statusCard(),
                 const SizedBox(height: 16),
                 _locationCard(),
                 const SizedBox(height: 16),
                 _deliveryCard(),
                 const SizedBox(height: 16),
                 _businessTypeCard(),
                 const SizedBox(height: 16),
                 _queueCard(),
               ],
            ),
    );
  }

  Widget _statusCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            title: 'Status Lapak',
            subtitle: 'Tampilkan lapak di radar warung terdekat',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.primaryColor,
            value: _isOpen,
            title: Text('Buka Lapak',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            subtitle: Text('Pembeli bisa melihat & memesan',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppTheme.textSecondary)),
            onChanged: _saving ? null : (v) => _setFlag(isOpen: v),
          ),
          const Divider(height: 1, color: AppTheme.borderColor),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.primaryColor,
            value: _isMobile,
            title: Text('Gerobak Keliling',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            subtitle: Text('Broadcast posisi lapak berkala',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppTheme.textSecondary)),
            onChanged: _saving ? null : (v) => _setFlag(isMobile: v),
          ),
        ],
      ),
    );
  }

  Widget _locationCard() {
    final updated = _locationUpdatedAt == null
        ? 'Belum ada lokasi'
        : 'Diperbarui ${Formatters.dateTime(_locationUpdatedAt!)}';
    final coords = (_lat == null || _lng == null)
        ? 'Koordinat belum diatur'
        : '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            title: 'Posisi Lapak',
            subtitle: 'Dipakai peta hyper-local',
            icon: Icons.my_location_rounded,
          ),
          Text(coords,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(updated,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Perbarui Lokasi',
                  icon: Icons.gps_fixed_rounded,
                  isLoading: _saving,
                  onPressed: _saving ? null : () => _broadcast(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Manual',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.edit_location_alt_rounded,
                  onPressed: _saving ? null : _enterManualCoordinates,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deliveryCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            title: 'Ongkir Pengiriman',
            subtitle: 'Atur ongkir pesanan "Diantar"',
            icon: Icons.delivery_dining_rounded,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.primaryColor,
            value: _manualOngkir,
            title: Text('Ongkir Manual',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            subtitle: Text('Nominal tetap untuk semua pesanan antar',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppTheme.textSecondary)),
            onChanged: _saving ? null : _setManualOngkir,
          ),
          if (_manualOngkir) ...[
            const Divider(height: 1, color: AppTheme.borderColor),
            const SizedBox(height: 12),
            AppTextField(
              controller: _manualCtrl,
              label: 'Nominal ongkir (Rp)',
              hint: '5000',
              prefixIcon: Icons.payments_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Simpan Ongkir',
              icon: Icons.save_rounded,
              isLoading: _saving,
              onPressed: _saving ? null : _saveManualValue,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Ongkir dihitung otomatis dari Pengaturan > Pengiriman.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _businessTypeCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            title: 'Tipe Usaha',
            subtitle: 'Tipe usaha ini tampil di lapak & pencarian pembeli',
            icon: Icons.storefront_rounded,
          ),
          if (_allCategories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tipe usaha belum tersedia.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allCategories.map((type) {
                final active = _businessType.toLowerCase() == type.toLowerCase();
                return GestureDetector(
                  onTap: () => _selectBusinessType(type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(
                        color: active ? AppTheme.primaryColor : AppTheme.borderColor,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          active
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: active ? AppTheme.primaryColor : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          type,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Simpan Tipe Usaha',
            icon: Icons.save_rounded,
            isLoading: _saving,
            onPressed: _saving ? null : _saveBusinessType,
            expanded: true,
          ),
        ],
      ),
    );
  }

  Widget _queueCard() {
    final active =
        _queue.where((e) => e.status == 'menunggu' || e.status == 'dipanggil');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            title: 'Antrean Jasa',
            subtitle: 'Bengkel, cukur, servis',
            icon: Icons.groups_rounded,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.primaryColor,
            value: _queueEnabled,
            title: Text('Aktifkan Antrean',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            subtitle: Text('Pembeli dapat mengambil nomor',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppTheme.textSecondary)),
            onChanged:
                _saving ? null : (v) => _setFlag(serviceQueueEnabled: v),
          ),
          if (_queueEnabled) ...[
            const Divider(height: 1, color: AppTheme.borderColor),
            const SizedBox(height: 8),
            if (active.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Belum ada antrean menunggu.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5, color: AppTheme.textSecondary)),
              )
            else
              ...active.map(_queueTile),
          ],
        ],
      ),
    );
  }

  Widget _queueTile(ServiceQueueEntry e) {
    final isCalled = e.status == 'dipanggil';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCalled
                  ? AppTheme.warningColor.withValues(alpha: 0.15)
                  : AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Text('#${e.number}',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: isCalled
                        ? AppTheme.warningColor
                        : AppTheme.primaryColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(isCalled ? 'Dipanggil' : 'Menunggu',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ),
          if (!isCalled)
            TextButton(
              onPressed: () => _setQueueStatus(e, 'dipanggil'),
              child: Text('Panggil',
                  style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700)),
            ),
          TextButton(
            onPressed: () => _setQueueStatus(e, 'selesai'),
            child: Text('Selesai',
                style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
