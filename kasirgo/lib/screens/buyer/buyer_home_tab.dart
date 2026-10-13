import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../models/app_customer.dart';
import '../../models/cart.dart';
import '../../models/geo_position.dart';
import '../../models/marketplace_result.dart';
import '../../models/outlet_location.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../services/buyer_location_service.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/ads/sponsor_ad_slot.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import 'buyer_checkout_screen.dart';

/// ST17-5 (Phase 17 - Ekosistem Hyper-Local): Beranda Pembeli.
///
/// Radar hyper-local (daftar warung/gerobak terdekat via `nearby_outlets`) +
/// katalog publik per outlet + keranjang satu toko per transaksi.
/// Peta interaktif (flutter_map/OSM) belum terpasang demi aturan hemat token,
/// sehingga radar digambar skematis (berdasarkan jarak) dengan fallback daftar.
class BuyerHomeTab extends ConsumerStatefulWidget {
  final AppCustomer customer;

  const BuyerHomeTab({super.key, required this.customer});

  @override
  ConsumerState<BuyerHomeTab> createState() => _BuyerHomeTabState();
}

class _BuyerHomeTabState extends ConsumerState<BuyerHomeTab> {
  final _locationService = LocationService();
  final _supabase = SupabaseService();
  final _buyerLocation = BuyerLocationService();

  GeoPosition? _location;
  bool _locating = false;
  bool _loadingOutlets = false;
  List<NearbyOutlet> _outlets = const [];

  NearbyOutlet? _selected;
  bool _loadingCatalog = false;
  List<Product> _catalog = const [];

  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _searching = false;
  List<MarketplaceResult> _searchResults = const [];

  StreamSubscription<OutletLocation>? _liveSub;
  OutletLocation? _livePosition;

  ServiceQueueEntry? _myQueue;
  bool _takingQueue = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searchQuery = q);
    _searchDebounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _searchQuery;
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final results = await _supabase.searchMarketplace(
      query: q,
      lat: _location?.lat,
      lng: _location?.lng,
    );
    if (!mounted || _searchQuery != q) return;
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = const [];
      _searching = false;
    });
  }

  void _openSearchResult(MarketplaceResult r) {
    _clearSearch();
    _openOutlet(r.toOutlet());
  }

  void _addSearchResultToCart(MarketplaceResult r) {
    _addToCart(r.toOutlet(), r.toProduct());
  }

  Future<void> _init() async {
    final saved = await _buyerLocation.loadSaved();
    if (!mounted) return;
    if (saved != null) {
      setState(() => _location = saved);
      await _loadOutlets();
    }
  }

  Future<void> _loadOutlets() async {
    final loc = _location;
    if (loc == null) return;
    setState(() => _loadingOutlets = true);
    final list =
        await _locationService.nearbyOutlets(lat: loc.lat, lng: loc.lng);
    if (!mounted) return;
    setState(() {
      _outlets = list;
      _loadingOutlets = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final pos = await _buyerLocation.detect();
    if (!mounted) return;
    if (pos == null) {
      setState(() => _locating = false);
      await _enterManualLocation();
      return;
    }
    await _buyerLocation.save(pos);
    if (!mounted) return;
    setState(() {
      _location = pos;
      _locating = false;
    });
    await _loadOutlets();
  }

  Future<void> _enterManualLocation() async {
    final latCtl = TextEditingController(text: _location?.lat.toString() ?? '');
    final lngCtl = TextEditingController(text: _location?.lng.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atur Lokasi Manual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan koordinat lokasimu. Contoh: -6.2000 dan 106.8000.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: latCtl,
              label: 'Latitude',
              hint: '-6.2000',
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: lngCtl,
              label: 'Longitude',
              hint: '106.8000',
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final lat = double.tryParse(latCtl.text.trim());
      final lng = double.tryParse(lngCtl.text.trim());
      if (lat != null && lng != null) {
        final pos = GeoPosition(lat: lat, lng: lng);
        await _buyerLocation.save(pos);
        if (!mounted) return;
        setState(() => _location = pos);
        await _loadOutlets();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koordinat tidak valid.')),
        );
      }
    }
    latCtl.dispose();
    lngCtl.dispose();
  }

  Future<void> _openOutlet(NearbyOutlet outlet) async {
    setState(() {
      _selected = outlet;
      _loadingCatalog = true;
      _catalog = const [];
    });
    _startLiveWatch(outlet.id);
    final products = await _supabase.getPublicCatalog(outlet.id);
    if (!mounted) return;
    setState(() {
      _catalog = products;
      _loadingCatalog = false;
    });
  }

  /// ST17-7: pantau posisi live gerobak/warung yang sedang dilihat pembeli.
  void _startLiveWatch(String outletId) {
    _liveSub?.cancel();
    _livePosition = null;
    _liveSub = _locationService.watchOutletLocation(outletId).listen((loc) {
      if (!mounted) return;
      setState(() => _livePosition = loc);
    });
  }

  void _stopLiveWatch() {
    _liveSub?.cancel();
    _liveSub = null;
    _livePosition = null;
  }

  Future<void> _takeQueue(NearbyOutlet outlet) async {
    setState(() => _takingQueue = true);
    final entry = await _locationService.takeQueueNumber(outlet.id);
    if (!mounted) return;
    setState(() {
      _takingQueue = false;
      _myQueue = entry;
    });
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(entry == null
            ? 'Gagal mengambil nomor antrean. Coba lagi.'
            : 'Nomor antreanmu: ${entry.number}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildLiveSection(NearbyOutlet o) {
    final live = _livePosition;
    final hasLive = live != null && (live.latitude != 0 || live.longitude != 0);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location_rounded,
                  size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Posisi Live',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (o.isMobile)
                const _MetaChip(
                    icon: Icons.directions_bike_rounded, label: 'Keliling'),
            ],
          ),
          const SizedBox(height: 8),
          if (hasLive)
            Text(
              'Lat ${live.latitude.toStringAsFixed(5)}, '
              'Lng ${live.longitude.toStringAsFixed(5)}'
              '${live.updatedAt != null ? '\nDiperbarui ${Formatters.dateTime(live.updatedAt!)}' : ''}',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            )
          else
            Text(
              o.isMobile
                  ? 'Penjual belum membagikan posisi terkini.'
                  : 'Posisi toko belum dibagikan.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
          if (o.serviceQueueEnabled) ...[
            const SizedBox(height: 12),
            if (_myQueue != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Text(
                  'Nomor antreanmu: ${_myQueue!.number} (${_myQueue!.status})',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              )
            else
              AppButton(
                label: 'Ambil Nomor Antrean',
                icon: Icons.confirmation_number_rounded,
                variant: AppButtonVariant.secondary,
                isLoading: _takingQueue,
                onPressed: () => _takeQueue(o),
              ),
          ],
        ],
      ),
    );
  }

  void _addToCart(NearbyOutlet outlet, Product product) {
    final replaced = ref.read(cartProvider.notifier).add(
          outletId: outlet.id,
          outletName: outlet.name,
          item: CartItem(
            productId: product.id,
            name: product.name,
            price: product.price,
            unit: product.unit,
            stock: product.stock,
          ),
        );
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          replaced
              ? 'Keranjang diganti ke ${outlet.name} (satu toko per transaksi).'
              : '${product.name} ditambahkan ke keranjang.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openCart() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) => _CartSheet(
        customer: widget.customer,
        outlet: _selected,
        buyerLat: _location?.lat,
        buyerLng: _location?.lng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _location == null ? () async {} : _loadOutlets,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, cart.isNotEmpty ? 100 : 16),
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildLocationCard(),
              const SizedBox(height: 20),
              if (_searchQuery.isNotEmpty)
                ..._buildSearchResults()
              else if (_selected == null)
                ..._buildRadarSection()
              else
                ..._buildCatalogSection(),
            ],
          ),
        ),
        if (cart.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildCartBar(cart),
          ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      gradient: AppTheme.primaryGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Halo, ${widget.customer.displayName}!',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Temukan warung & produk di sekitarmu. Pesan, bayar, ambil atau diantar.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return AppTextField(
      controller: _searchCtrl,
      hint: 'Cari produk atau warung (mis. kopi, roti)...',
      prefixIcon: Icons.search_rounded,
      onChanged: _onSearchChanged,
      suffixIcon: _searchQuery.isEmpty
          ? null
          : IconButton(
              onPressed: _clearSearch,
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Bersihkan',
            ),
    );
  }

  List<Widget> _buildSearchResults() {
    return [
      AppSectionTitle(
        title: 'Hasil Pencarian',
        subtitle: 'Untuk $_searchQuery',
        icon: Icons.search_rounded,
        trailing: IconButton(
          onPressed: _searching ? null : _runSearch,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Cari ulang',
        ),
      ),
      const SizedBox(height: 12),
      if (_searching)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_searchResults.isEmpty)
        AppCard(
          child: Column(
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 40, color: AppTheme.textSecondary),
              const SizedBox(height: 10),
              Text(
                'Produk tidak ditemukan',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Coba kata kunci lain, atau aktifkan lokasi agar hasil lebih dekat.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        )
      else
        for (final r in _searchResults)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildSearchResultCard(r),
          ),
    ];
  }

  Widget _buildSearchResultCard(MarketplaceResult r) {
    final cart = ref.watch(cartProvider);
    final qty = cart.outletId == r.outletId ? cart.qtyOf(r.productId) : 0;
    final isOut = r.stock <= 0;
    return AppCard(
      onTap: () => _openSearchResult(r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Center(
              child: Text(
                r.productName.isNotEmpty
                    ? r.productName[0].toUpperCase()
                    : '?',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r.outletName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  Formatters.currency(r.price),
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MetaChip(
                      icon: Icons.place_rounded,
                      label: r.distanceLabel,
                    ),
                    if (r.hasDelivery)
                      const _MetaChip(
                          icon: Icons.delivery_dining_rounded,
                          label: 'Bisa diantar'),
                    _MetaChip(
                      icon: isOut
                          ? Icons.remove_shopping_cart_rounded
                          : Icons.inventory_2_rounded,
                      label: isOut ? 'Stok habis' : 'Stok ${r.stock}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Column(
              children: [
                if (qty > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'x$qty',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed:
                      isOut ? null : () => _addSearchResultToCart(r),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  color: AppTheme.primaryColor,
                  tooltip: 'Tambah ke keranjang',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final loc = _location;
    return AppCard(
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: const Icon(Icons.my_location_rounded, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc == null ? 'Lokasi belum diatur' : 'Lokasi aktif',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loc == null
                      ? 'Aktifkan agar radar warung sekitar berfungsi.'
                      : '${loc.lat.toStringAsFixed(4)}, ${loc.lng.toStringAsFixed(4)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_locating)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: loc == null ? _useCurrentLocation : _enterManualLocation,
              child: Text(loc == null ? 'Atur Lokasi' : 'Ubah'),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildRadarSection() {
    return [
      AppSectionTitle(
        title: 'Radar Warung Terdekat',
        subtitle: _location == null
            ? 'Atur lokasi untuk melihat warung sekitar'
            : 'Dalam radius 1-3 km dari lokasimu',
        icon: Icons.radar_rounded,
        trailing: _location == null
            ? null
            : IconButton(
                onPressed: _loadingOutlets ? null : _loadOutlets,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Muat ulang',
              ),
      ),
      const SizedBox(height: 12),
      if (_location == null)
        _buildRadarEmpty()
      else if (_loadingOutlets)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_outlets.isEmpty)
        _buildNoOutlets()
      else ...[
        _RadarSketch(outlets: _outlets),
        const SizedBox(height: 8),
        Text(
          'Sebaran skematis berdasarkan jarak (bukan arah sebenarnya).',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        for (final o in _outlets)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildOutletCard(o),
          ),
      ],
      const SizedBox(height: 16),
      AppButton(
        label: 'Pesan Manual via Kode Warung',
        icon: Icons.qr_code_rounded,
        variant: AppButtonVariant.outline,
        onPressed: () => context.push('/customer'),
      ),
    ];
  }

  Widget _buildRadarEmpty() {
    return AppCard(
      child: Column(
        children: [
          const Icon(Icons.location_searching_rounded,
              size: 40, color: AppTheme.primaryColor),
          const SizedBox(height: 10),
          Text(
            'Radar Hyper-Local',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Aktifkan lokasi untuk menemukan warung, gerobak, dan status buka/tutup dalam radius 1-3 km.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'Gunakan Lokasi Saya',
            icon: Icons.my_location_rounded,
            isLoading: _locating,
            onPressed: _useCurrentLocation,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Isi Koordinat Manual',
            icon: Icons.edit_location_alt_rounded,
            variant: AppButtonVariant.outline,
            onPressed: _enterManualLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildNoOutlets() {
    return AppCard(
      child: Column(
        children: [
          const Icon(Icons.store_mall_directory_outlined,
              size: 40, color: AppTheme.textSecondary),
          const SizedBox(height: 10),
          Text(
            'Belum ada warung terdeteksi',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Coba perbarui lokasi atau perluas area pencarian.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletCard(NearbyOutlet o) {
    return AppCard(
      onTap: () => _openOutlet(o),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Icon(
                  o.isMobile
                      ? Icons.storefront_rounded
                      : Icons.store_mall_directory_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [o.type, o.distanceLabel].whereType<String>().join(' - '),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(open: o.isOpen),
            ],
          ),
          if ((o.address ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              o.address!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.groups_rounded,
                label: 'Antrean ${o.queueCount}',
              ),
              if (o.hasDelivery)
                const _MetaChip(icon: Icons.delivery_dining_rounded, label: 'Bisa diantar'),
              if (o.isMobile)
                const _MetaChip(icon: Icons.directions_bike_rounded, label: 'Keliling'),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Lihat Katalog',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCatalogSection() {
    final o = _selected!;
    final cart = ref.watch(cartProvider);
    return [
      Row(
        children: [
          IconButton(
            onPressed: () => setState(() {
              _selected = null;
              _catalog = const [];
              _stopLiveWatch();
            }),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Kembali ke radar',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.name,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  [o.type, o.distanceLabel].whereType<String>().join(' - '),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(open: o.isOpen),
        ],
      ),
      const SizedBox(height: 12),
      if (o.isMobile || o.serviceQueueEnabled) ...[
        _buildLiveSection(o),
        const SizedBox(height: 12),
      ],
      SponsorAdSlot(outletId: o.id, compact: true),
      const SizedBox(height: 12),
      if (_loadingCatalog)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_catalog.isEmpty)
        AppCard(
          child: Column(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 40, color: AppTheme.textSecondary),
              const SizedBox(height: 10),
              Text(
                'Belum ada produk dipublikasikan',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Warung ini belum menaruh produknya di katalog online.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 210,
            childAspectRatio: 0.76,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _catalog.length,
          itemBuilder: (_, i) {
            final p = _catalog[i];
            return _ProductCard(
              product: p,
              qty: cart.outletId == o.id ? cart.qtyOf(p.id) : 0,
              onAdd: p.stock > 0 ? () => _addToCart(o, p) : null,
            );
          },
        ),
    ];
  }

  Widget _buildCartBar(Cart cart) {
    return Material(
      color: Colors.transparent,
      child: AppCard(
        elevated: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: const Icon(Icons.shopping_cart_rounded,
                  color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cart.itemCount} item - ${cart.outletName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    Formatters.currency(cart.subtotal),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _openCart,
              child: const Text('Lihat Keranjang'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool open;

  const _StatusBadge({required this.open});

  @override
  Widget build(BuildContext context) {
    final color = open ? AppTheme.successColor : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        open ? 'Buka' : 'Tutup',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMutedColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final int qty;
  final VoidCallback? onAdd;

  const _ProductCard({
    required this.product,
    required this.qty,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isOut = product.stock <= 0;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      product.name.isNotEmpty
                          ? product.name[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  if (qty > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$qty',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.currency(product.price),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isOut ? 'Stok habis' : 'Stok ${product.stock}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isOut ? AppTheme.errorColor : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: onAdd,
                      icon: Icon(
                        qty > 0
                            ? Icons.add_shopping_cart_rounded
                            : Icons.add_rounded,
                        size: 16,
                      ),
                      label: Text(qty > 0 ? 'Tambah lagi' : 'Keranjang'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        foregroundColor: isOut
                            ? AppTheme.textSecondary
                            : AppTheme.primaryColor,
                        backgroundColor: isOut
                            ? AppTheme.surfaceMutedColor
                            : AppTheme.primaryColor.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keranjang (satu toko per transaksi).
class _CartSheet extends ConsumerWidget {
  final AppCustomer customer;
  final NearbyOutlet? outlet;
  final double? buyerLat;
  final double? buyerLng;

  const _CartSheet({
    required this.customer,
    this.outlet,
    this.buyerLat,
    this.buyerLng,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keranjang',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        cart.outletName,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: cart.isEmpty ? null : notifier.clear,
                  child: const Text('Kosongkan'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (cart.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Keranjang kosong',
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              )
            else ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: cart.items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppTheme.borderColor),
                  itemBuilder: (_, i) {
                    final item = cart.items[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  Formatters.currency(item.price),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _QtyStepper(
                            qty: item.qty,
                            onMinus: () =>
                                notifier.decrement(item.productId),
                            onPlus: () => notifier.increment(item.productId),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 24, color: AppTheme.borderColor),
              Row(
                children: [
                  Text(
                    'Subtotal',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Formatters.currency(cart.subtotal),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Satu toko per transaksi. Ongkir dihitung saat checkout.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              AppButton(
                label: 'Lanjut ke Checkout',
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BuyerCheckoutScreen(
                        outletId: cart.outletId,
                        outletName: cart.outletName,
                        customer: customer,
                        hasDelivery: outlet?.hasDelivery ?? false,
                        buyerLat: buyerLat,
                        buyerLng: buyerLng,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QtyStepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove_rounded, onMinus),
          SizedBox(
            width: 34,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          _btn(Icons.add_rounded, onPlus),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 34,
        width: 34,
        child: Icon(icon, size: 16, color: AppTheme.primaryColor),
      ),
    );
  }
}

/// Sketsa radar skematis (jarak saja; arah tidak tersedia dari `nearby_outlets`).
class _RadarSketch extends StatelessWidget {
  final List<NearbyOutlet> outlets;

  const _RadarSketch({required this.outlets});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        height: 220,
        child: CustomPaint(
          painter: _RadarPainter(outlets),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<NearbyOutlet> outlets;

  _RadarPainter(this.outlets);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = (size.shortestSide / 2) - 10;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppTheme.borderColor
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxR * i / 3, ringPaint);
    }

    final crossPaint = Paint()
      ..color = AppTheme.borderColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - maxR, center.dy),
      Offset(center.dx + maxR, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxR),
      Offset(center.dx, center.dy + maxR),
      crossPaint,
    );

    final maxDist = outlets.fold<double>(
      0.01,
      (m, o) => o.distanceKm > m ? o.distanceKm : m,
    );

    for (var i = 0; i < outlets.length; i++) {
      final o = outlets[i];
      final r = maxR * (o.distanceKm / maxDist).clamp(0.0, 1.0);
      final angle = i * 2.399963;
      final pos = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      canvas.drawCircle(
        pos,
        6,
        Paint()..color = o.isOpen ? AppTheme.successColor : AppTheme.textSecondary,
      );
      canvas.drawCircle(
        pos,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppTheme.surfaceColor
          ..strokeWidth = 2,
      );
    }

    canvas.drawCircle(center, 7, Paint()..color = AppTheme.primaryColor);
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppTheme.surfaceColor
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.outlets != outlets;
}
