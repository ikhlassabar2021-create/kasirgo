import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

class RecipeScreen extends ConsumerStatefulWidget {
  const RecipeScreen({super.key});

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  bool _loading = true;
  List<Product> _products = [];
  Map<String, Recipe> _recipes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final outletId = ref.read(currentUserProvider)?.outletId ?? '';
    if (outletId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final products = await SupabaseService().getProducts(outletId);
    final recipes = await SupabaseService().getRecipesForOutlet(outletId);
    if (!mounted) return;
    setState(() {
      _products = products;
      _recipes = {for (final r in recipes) r.productId: r};
      _loading = false;
    });
  }

  double _hppPerPorsi(Recipe recipe) {
    if (recipe.yieldQty <= 0) return 0;
    double total = 0;
    for (final item in recipe.items) {
      final ing = _ingredient(item.ingredientProductId);
      if (ing == null) continue;
      total += item.qty * (ing.costPrice ?? 0);
    }
    return total / recipe.yieldQty;
  }

  Product? _ingredient(String? id) {
    if (id == null) return null;
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _openEditor(Product product) async {
    final existing = _recipes[product.id];
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RecipeEditor(
        product: product,
        products: _products,
        existing: existing,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _confirmDelete(Product product, Recipe recipe) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Text('Hapus resep?',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTheme.textPrimary)),
        content: Text(
            'Resep ${product.name} akan dihapus. Stok bahan tidak berubah.',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Batal',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Hapus',
                  style: GoogleFonts.inter(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    await SupabaseService().deleteRecipe(recipe.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Resep ${product.name} dihapus'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final productsWithRecipe =
        _products.where((p) => _recipes.containsKey(p.id)).toList();
    final productsWithout =
        _products.where((p) => !_recipes.containsKey(p.id)).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Resep & Bahan (HPP)',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded,
                  color: AppTheme.textSecondary)),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _products.isEmpty
              ? Center(
                  child: Text('Belum ada produk',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppTheme.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (productsWithRecipe.isNotEmpty) ...[
                      _sectionLabel('Produk dengan resep'),
                      ...productsWithRecipe.map(_recipeCard),
                      const SizedBox(height: 16),
                    ],
                    _sectionLabel('Produk tanpa resep'),
                    if (productsWithout.isEmpty)
                      _emptyNote('Semua produk sudah punya resep.')
                    else
                      ...productsWithout.map(_plainCard),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(),
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppTheme.textSecondary)),
    );
  }

  Widget _emptyNote(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 12.5, color: AppTheme.textSecondary)),
    );
  }

  Widget _recipeCard(Product product) {
    final recipe = _recipes[product.id]!;
    final hpp = _hppPerPorsi(recipe);
    final price = product.price > 0
        ? product.price
        : (recipe.items.isNotEmpty ? 0.0 : 0.0);
    final margin =
        hpp > 0 && price > 0 ? ((price - hpp) / price * 100) : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () => _openEditor(product),
        title: Text(product.name,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${recipe.items.length} bahan - yield ${_fmtNum(recipe.yieldQty)} porsi - HPP ${Formatters.currency(hpp)}/porsi - margin ${margin.toStringAsFixed(0)}%',
            style: GoogleFonts.inter(
                fontSize: 11.5, color: AppTheme.textSecondary),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                tooltip: 'Hapus resep',
                onPressed: () => _confirmDelete(product, recipe),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppTheme.errorColor)),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _plainCard(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () => _openEditor(product),
        title: Text(product.name,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Harga jual ${Formatters.currency(product.price)} - belum ada resep',
            style: GoogleFonts.inter(
                fontSize: 11.5, color: AppTheme.textSecondary),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('Buat Resep',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ),
    );
  }

  String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _RecipeEditor extends StatefulWidget {
  final Product product;
  final List<Product> products;
  final Recipe? existing;

  const _RecipeEditor({
    required this.product,
    required this.products,
    this.existing,
  });

  @override
  State<_RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<_RecipeEditor> {
  late double _yieldQty;
  late List<RecipeItem> _items;
  late bool _syncCost;
  double _targetMargin = 30;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _yieldQty = widget.existing?.yieldQty ?? 1;
    _items = List.from(widget.existing?.items ?? const []);
    _syncCost = widget.existing != null;
  }

  double get _hppBatch {
    double total = 0;
    for (final item in _items) {
      final ing = _ingredient(item.ingredientProductId);
      if (ing == null) continue;
      total += item.qty * (ing.costPrice ?? 0);
    }
    return total;
  }

  double get _hppPorsi =>
      _yieldQty > 0 ? _hppBatch / _yieldQty : 0;

  double get _hargaSaran {
    final m = _targetMargin.clamp(0, 95) / 100;
    if (m >= 1) return _hppPorsi;
    return _hppPorsi / (1 - m);
  }

  Product? _ingredient(String? id) {
    if (id == null) return null;
    for (final p in widget.products) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _addIngredient() {
    setState(() {
      _items.add(const RecipeItem(
          id: '', recipeId: '', ingredientProductId: null, qty: 1, unit: 'gram'));
    });
  }

  Future<void> _save() async {
    final valid = _items
        .where((i) => (i.ingredientProductId ?? '').isNotEmpty && i.qty > 0)
        .toList();
    if (valid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tambah minimal 1 bahan dengan jumlah > 0'),
          backgroundColor: AppTheme.errorColor));
      return;
    }
    if (_yieldQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Hasil (porsi) harus lebih dari 0'),
          backgroundColor: AppTheme.errorColor));
      return;
    }
    setState(() => _saving = true);
    final recipe = Recipe(
      id: widget.existing?.id ?? '',
      outletId: widget.product.outletId,
      productId: widget.product.id,
      yieldQty: _yieldQty,
      items: valid,
    );
    final saved =
        await SupabaseService().saveRecipe(recipe, valid);
    if (saved != null && _syncCost) {
      final updated = widget.product.copyWith(costPrice: _hppPorsi);
      await SupabaseService().updateProduct(updated);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Resep - ${widget.product.name}',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              _yieldField(),
              const SizedBox(height: 12),
              Text('BAHAN BAKU',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              ..._items.asMap().entries.map((e) => _itemRow(e.key, e.value)),
              TextButton.icon(
                onPressed: _addIngredient,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Tambah Bahan',
                    style: GoogleFonts.inter(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    alignment: Alignment.centerLeft),
              ),
              const SizedBox(height: 8),
              _hppCard(),
              const SizedBox(height: 12),
              _marginField(),
              const SizedBox(height: 4),
              _syncCostSwitch(),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Simpan Resep',
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _yieldField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Text('Hasil (porsi)',
              style: GoogleFonts.inter(
                  fontSize: 12.5, color: AppTheme.textSecondary)),
          const Spacer(),
          IconButton(
              onPressed: () {
                if (_yieldQty > 1) setState(() => _yieldQty -= 1);
              },
              icon: const Icon(Icons.remove_circle_outline_rounded,
                  size: 20, color: AppTheme.textSecondary)),
          Text(_fmt(_yieldQty),
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          IconButton(
              onPressed: () => setState(() => _yieldQty += 1),
              icon: const Icon(Icons.add_circle_outline_rounded,
                  size: 20, color: AppTheme.primaryColor)),
        ],
      ),
    );
  }

  Widget _itemRow(int index, RecipeItem item) {
    final ing = _ingredient(item.ingredientProductId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: item.ingredientProductId,
                    isDense: true,
                    hint: Text('Pilih bahan',
                        style: GoogleFonts.inter(fontSize: 12.5)),
                    items: widget.products
                        .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                                '${p.name} (${Formatters.currency(p.costPrice ?? 0)}/${(p.unit == null || p.unit!.isEmpty) ? 'unit' : p.unit})',
                                style: GoogleFonts.inter(fontSize: 12.5))))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _items[index] = item.copyWith(ingredientProductId: v);
                    }),
                  ),
                ),
              ),
              IconButton(
                  onPressed: () => setState(() => _items.removeAt(index)),
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppTheme.errorColor)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _fmt(item.qty),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Jumlah',
                      labelStyle: GoogleFonts.inter(fontSize: 11)),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    if (parsed != null) {
                      _items[index] = item.copyWith(qty: parsed);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: item.unit ?? '',
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Satuan',
                      hintText: 'gram/ml/biji',
                      hintStyle: GoogleFonts.inter(fontSize: 11),
                      labelStyle: GoogleFonts.inter(fontSize: 11)),
                  onChanged: (v) {
                    _items[index] = item.copyWith(unit: v.trim());
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ing == null ? '-' : Formatters.currency(item.qty * (ing.costPrice ?? 0)),
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hppCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total biaya resep',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary)),
              Text(Formatters.currency(_hppBatch),
                  style: GoogleFonts.inter(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('HPP per porsi',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary)),
              Text(Formatters.currency(_hppPorsi),
                  style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Harga saran (margin ${_targetMargin.toStringAsFixed(0)}%)',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary)),
              Text(Formatters.currency(_hargaSaran),
                  style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.successColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _marginField() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Target margin',
                style: GoogleFonts.inter(
                    fontSize: 12.5, color: AppTheme.textSecondary)),
            Text('${_targetMargin.toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primaryColor,
            inactiveTrackColor: AppTheme.borderColor,
            thumbColor: AppTheme.primaryColor,
            overlayColor: AppTheme.primaryColor.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: _targetMargin,
            min: 0,
            max: 90,
            divisions: 90,
            onChanged: (v) => setState(() => _targetMargin = v),
          ),
        ),
      ],
    );
  }

  Widget _syncCostSwitch() {
    return Row(
      children: [
        Expanded(
          child: Text(
              'Set HPP produk = HPP per porsi (dipakai laporan laba)',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppTheme.textSecondary)),
        ),
        Switch(
          value: _syncCost,
          activeThumbColor: AppTheme.primaryColor,
          onChanged: (v) => setState(() => _syncCost = v),
        ),
      ],
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
