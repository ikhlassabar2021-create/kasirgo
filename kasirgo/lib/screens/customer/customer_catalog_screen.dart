import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../config/supabase_config.dart';
import '../../models/product.dart';
import '../../services/ad_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';
import '../../utils/wa_helper.dart';
import '../../widgets/ads/sponsor_ad_slot.dart';

/// Katalog online publik (tanpa login, mode tanpa meja).
///
/// Dibuka lewat deep-link `{appUrl}#/catalog?outlet=<OUTLET_ID>` sehingga satu
/// web app melayani semua outlet. Pelanggan melihat produk lalu memesan lewat
/// WhatsApp toko (bila nomor WA owner sudah diatur).
class CustomerCatalogScreen extends StatefulWidget {
  final String initialOutletId;

  const CustomerCatalogScreen({super.key, this.initialOutletId = ''});

  @override
  State<CustomerCatalogScreen> createState() => _CustomerCatalogScreenState();
}

class _CustomerCatalogScreenState extends State<CustomerCatalogScreen> {
  final _service = SupabaseService();
  final _outletController = TextEditingController();
  final _searchController = TextEditingController();

  List<Product> _products = [];
  String _outletName = '';
  String _outletId = '';
  String _waNumber = '';
  bool _isLoading = false;
  String _error = '';
  String _selectedCategory = 'Semua';
  String _searchQuery = '';
  bool _adConsent = false;

  @override
  void initState() {
    super.initState();
    _outletController.text = widget.initialOutletId;
    _loadAdConsent();
    if (widget.initialOutletId.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _load(widget.initialOutletId.trim());
      });
    }
  }

  Future<void> _loadAdConsent() async {
    final consent = await AdService().getConsent();
    if (mounted) setState(() => _adConsent = consent == true);
  }

  @override
  void dispose() {
    _outletController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load(String outletId) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    final outlet = await _service.findOutlet(outletId);
    if (!mounted) return;
    if (outlet == null) {
      setState(() {
        _isLoading = false;
        _error = 'Toko tidak ditemukan. Pastikan tautan katalog benar.';
      });
      return;
    }

    final wa = await _service.getPublicOutletWa(outlet.id);
    final data = await _service.getPublicCatalog(outlet.id);
    if (!mounted) return;
    setState(() {
      _outletId = outlet.id;
      _outletName = outlet.name;
      _waNumber = wa ?? '';
      _products = data.where((p) => p.isActive).toList();
      _isLoading = false;
      if (_products.isEmpty) {
        _error = 'Katalog masih kosong. Silakan cek kembali nanti.';
      }
    });
  }

  List<String> get _categories {
    final cats = _products
        .map((p) => p.category)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    return ['Semua', ...cats];
  }

  List<Product> get _filtered {
    final query = _searchQuery.trim().toLowerCase();
    return _products.where((p) {
      final matchCat =
          _selectedCategory == 'Semua' || p.category == _selectedCategory;
      final matchQuery = query.isEmpty || p.name.toLowerCase().contains(query);
      return matchCat && matchQuery;
    }).toList();
  }

  Future<void> _orderViaWhatsApp(Product product) async {
    if (_waNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Toko belum mengatur nomor WhatsApp pemesanan.'),
          backgroundColor: AppTheme.warningColor,
        ));
      return;
    }
    final message = 'Halo *$_outletName*, saya ingin memesan:\n\n'
        '*${product.name}*\n'
        'Harga: ${Formatters.currency(product.price)}\n'
        'Jumlah: 1\n\n'
        'Pesan dari katalog online (${SupabaseConfig.catalogUrl(_outletId)}).';
    await WaHelper.sendWhatsAppMessage(phone: _waNumber, message: message);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_outletId.isEmpty) {
      return _buildLookupScaffold();
    }

    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _outletName.isNotEmpty ? _outletName : 'Katalog Toko',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.textPrimary),
            ),
            Text(
              'Katalog Online',
              style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              SponsorAdSlot(
                outletId: _outletId,
                consentGiven: _adConsent,
                onConsentChanged: (v) => setState(() => _adConsent = v),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Cari produk...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              if (_categories.length > 1)
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final cat = _categories[idx];
                      final isSel = _selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSel,
                        showCheckmark: false,
                        selectedColor: AppTheme.primaryColor,
                        backgroundColor: AppTheme.surfaceColor,
                        side: BorderSide(
                            color: isSel
                                ? AppTheme.primaryColor
                                : AppTheme.borderColor),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      );
                    },
                  ),
                ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _error.isNotEmpty
                              ? _error
                              : 'Tidak ada produk ditemukan',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final cols = w >= 1000
                              ? 5
                              : w >= 760
                                  ? 4
                                  : w >= 520
                                      ? 3
                                      : 2;
                          return GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              childAspectRatio: 0.82,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) =>
                                _buildProductCard(filtered[index]),
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

  Widget _buildLookupScaffold() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Katalog Online',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppTheme.textPrimary),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  'Buka Katalog Toko',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Masukkan ID toko atau buka tautan katalog yang dibagikan pemilik toko.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _outletController,
                  decoration: const InputDecoration(
                    labelText: 'ID / Kode Outlet',
                    hintText: 'Tempel ID toko...',
                    prefixIcon: Icon(Icons.storefront_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final id = _outletController.text.trim();
                      if (id.isNotEmpty) _load(id);
                    },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Buka Katalog'),
                  ),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.errorColor, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isOut = product.stock <= 0;
    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
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
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOut
                              ? AppTheme.errorColor
                              : product.stock <= 10
                                  ? AppTheme.warningColor
                                  : AppTheme.successColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOut
                              ? 'HABIS'
                              : '${product.stock} ${product.unit ?? 'pcs'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 5,
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      Formatters.currency(product.price),
                      style: GoogleFonts.inter(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 34,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.whatsAppColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                        ),
                        onPressed: isOut ? null : () => _orderViaWhatsApp(product),
                        icon: const Icon(Icons.chat_outlined, size: 16),
                        label: const Text('Pesan WA',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
