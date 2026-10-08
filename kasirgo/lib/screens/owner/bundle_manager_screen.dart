import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/growth_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/centennial_background.dart';

/// ST15-3 (13.25.5): manajer bundling — paket produk dijual 1 harga.
/// Diakses dari dashboard owner / aksi resep Dokter Bisnis.
class BundleManagerScreen extends ConsumerStatefulWidget {
  const BundleManagerScreen({super.key});

  @override
  ConsumerState<BundleManagerScreen> createState() =>
      _BundleManagerScreenState();
}

class _BundleManagerScreenState extends ConsumerState<BundleManagerScreen> {
  final GrowthService _service = GrowthService();
  bool _loading = true;
  List<Map<String, dynamic>> _bundles = [];
  List<Product> _products = [];

  String? get _outletId {
    final id = ref.read(currentUserProvider)?.outletId;
    return (id == null || id.isEmpty) ? null : id;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final outletId = _outletId;
    if (outletId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final bundles = await _service.listBundles(outletId);
      if (mounted) setState(() => _bundles = bundles);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openBundleForm([Map<String, dynamic>? bundle]) async {
    final outletId = _outletId;
    if (outletId == null) return;
    // Muat produk untuk pemilihan isi paket.
    try {
      final client = _service.productsClient;
      final res = await client
          .from('products')
          .select('id, name, base_price, stock, category, outlet_id')
          .eq('outlet_id', outletId);
      _products = (res as List)
          .map((p) => Product(
                id: p['id'],
                outletId: p['outlet_id'],
                name: p['name'],
                basePrice: (p['base_price'] as num?)?.toDouble() ?? 0,
                stock: ((p['stock'] as num?)?.toDouble() ?? 0).toInt(),
              ))
          .toList();
    } catch (_) {}

    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BundleFormSheet(
        products: _products,
        bundle: bundle,
        onSave: ({
          required name,
          required description,
          required bundlePrice,
          required originalPrice,
          required items,
          required isActive,
        }) async {
          await _service.saveBundle(
            bundleId: bundle?['id'],
            outletId: outletId,
            name: name,
            description: description,
            bundlePrice: bundlePrice,
            originalPrice: originalPrice,
            items: items
                .map((p) => {
                      'product_id': p.product.id,
                      'quantity': p.quantity,
                    })
                .toList(),
            isActive: isActive,
          );
          return true;
        },
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Paket Bundling',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: CentennialBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _bundles.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 120),
                          _EmptyBundles(onCreate: () => _openBundleForm()),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bundles.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _BundleCard(
                          bundle: _bundles[i],
                          onEdit: () => _openBundleForm(_bundles[i]),
                          onToggle: () async {
                            await _service.toggleBundle(
                              _bundles[i]['id'],
                              !(_bundles[i]['is_active'] == true),
                            );
                            _load();
                          },
                          onDelete: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Hapus paket?'),
                                content: Text(
                                    'Paket "${_bundles[i]['name']}" akan dihapus permanen.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Batal')),
                                  FilledButton(
                                      style: FilledButton.styleFrom(
                                          backgroundColor: AppTheme.errorColor),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Hapus')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await _service.deleteBundle(_bundles[i]['id']);
                              _load();
                            }
                          },
                        ),
                      ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bundle_add',
        onPressed: () => _openBundleForm(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Paket Baru'),
      ),
    );
  }
}

class _EmptyBundles extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyBundles({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_rounded,
                  size: 44, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text('Belum Ada Paket Bundling',
                style: GoogleFonts.inter(
                    fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Gabungkan produk margin tinggi dengan slow-moving jadi satu harga paket. Terjual sebagai 1 item di POS.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Buat Paket Pertama'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  final Map<String, dynamic> bundle;
  final VoidCallback onEdit;
  final Future<void> Function() onToggle;
  final Future<void> Function() onDelete;

  const _BundleCard({
    required this.bundle,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = bundle['name']?.toString() ?? 'Paket';
    final price = (bundle['bundle_price'] as num?)?.toDouble() ?? 0;
    final original = (bundle['original_price'] as num?)?.toDouble() ?? 0;
    final isActive = bundle['is_active'] == true;
    final items = (bundle['product_bundle_items'] as List?) ?? [];
    final saving = original > price ? original - price : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') onEdit();
                  if (v == 'toggle') await onToggle();
                  if (v == 'delete') await onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit', child: Text('Ubah Paket')),
                  PopupMenuItem(
                      value: 'toggle',
                      child: Text(isActive ? 'Nonaktifkan' : 'Aktifkan')),
                  const PopupMenuItem(
                      value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final it in items)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${it['quantity']?.toStringAsFixed(0) ?? '1'}x ${_itemName(it)}',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(Formatters.currency(price),
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor)),
              const SizedBox(width: 8),
              if (original > price)
                Text(
                  Formatters.currency(original),
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                      decoration: TextDecoration.lineThrough),
                ),
              if (saving > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Hemat ${Formatters.currency(saving)}',
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF15803D)),
                  ),
                ),
              ],
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isActive ? 'AKTIF' : 'NONAKTIF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isActive
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _itemName(Map<String, dynamic> item) {
    final p = item['products'];
    if (p is Map) return p['name']?.toString() ?? 'Produk';
    return 'Produk';
  }
}

class _BundleItemPick {
  final Product product;
  final int quantity;
  const _BundleItemPick(this.product, this.quantity);
}

class _BundleFormSheet extends StatefulWidget {
  final List<Product> products;
  final Map<String, dynamic>? bundle;
  final Future<bool> Function({
    required String name,
    required String description,
    required double bundlePrice,
    required double originalPrice,
    required List<_BundleItemPick> items,
    required bool isActive,
  }) onSave;

  const _BundleFormSheet({
    required this.products,
    this.bundle,
    required this.onSave,
  });

  @override
  State<_BundleFormSheet> createState() => _BundleFormSheetState();
}

class _BundleFormSheetState extends State<_BundleFormSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final Map<String, int> _qty = {};
  bool _saving = false;
  bool _isActive = true;

  double get _original => _qty.entries.fold(0.0, (s, e) {
        final p = widget.products.firstWhere((p) => p.id == e.key);
        return s + p.basePrice * e.value;
      });

  @override
  void initState() {
    super.initState();
    final b = widget.bundle;
    if (b != null) {
      _nameCtrl.text = b['name']?.toString() ?? '';
      _descCtrl.text = b['description']?.toString() ?? '';
      _priceCtrl.text =
          ((b['bundle_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
      _isActive = b['is_active'] == true;
      for (final it in (b['product_bundle_items'] as List? ?? [])) {
        final pid = it['product_id']?.toString();
        if (pid != null) {
          _qty[pid] = ((it['quantity'] as num?)?.toInt() ?? 1);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final original = _qty.isNotEmpty ? _original : 0.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bundle == null ? 'Paket Bundling Baru' : 'Ubah Paket',
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Paket',
                hintText: 'mis. Sembako Hemat',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga Paket (Rp)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Harga Normal',
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.textSecondary)),
                      Text(
                        Formatters.currency(original),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Paket aktif (tampil di POS)',
                  style: TextStyle(fontSize: 13)),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 6),
            const Text('Isi Paket',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.products.length,
                itemBuilder: (_, i) {
                  final p = widget.products[i];
                  final q = _qty[p.id] ?? 0;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                        Formatters.currency(p.basePrice),
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                          onPressed: () => setState(() {
                            final cur = _qty[p.id] ?? 0;
                            if (cur <= 1) {
                              _qty.remove(p.id);
                            } else {
                              _qty[p.id] = cur - 1;
                            }
                          }),
                        ),
                        Text('$q',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                          onPressed: () => setState(() {
                            _qty[p.id] = (_qty[p.id] ?? 0) + 1;
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(widget.bundle == null ? 'Buat Paket' : 'Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (name.isEmpty || price <= 0 || _qty.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lengkapi nama, harga, dan isi paket')));
      return;
    }
    setState(() => _saving = true);
    try {
      final items = _qty.entries
          .map((e) => _BundleItemPick(
              widget.products.firstWhere((p) => p.id == e.key), e.value))
          .toList();
      final ok = await widget.onSave(
        name: name,
        description: _descCtrl.text.trim(),
        bundlePrice: price,
        originalPrice: _original,
        items: items,
        isActive: _isActive,
      );
      if (ok && mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
