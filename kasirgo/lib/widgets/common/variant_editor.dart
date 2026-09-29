import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../models/variant.dart';

/// Editor daftar varian produk (Phase 8 / ST8-2) — Design System v2
/// "Centennial Modern Ocean White": token warna dari AppTheme, tanpa hardcode.
class VariantEditor extends StatelessWidget {
  final List<ProductVariant> variants;
  final ValueChanged<List<ProductVariant>> onChanged;

  const VariantEditor({
    super.key,
    required this.variants,
    required this.onChanged,
  });

  void _add() {
    onChanged([
      ...variants,
      ProductVariant(id: '', productId: '', name: ''),
    ]);
  }

  void _removeAt(int i) {
    final out = List<ProductVariant>.from(variants)..removeAt(i);
    onChanged(out);
  }

  void _update(int i, ProductVariant v) {
    final out = List<ProductVariant>.from(variants);
    out[i] = v;
    onChanged(out);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category_outlined,
                  size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Daftar Varian',
                    style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ),
              Text('${variants.length} varian',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Harga jual = harga dasar + selisih varian. Stok dihitung per varian.',
            style: GoogleFonts.inter(
                fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          ...List.generate(variants.length, (i) => _row(context, i)),
          if (variants.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('Belum ada varian. Tambahkan minimal satu.',
                  style: GoogleFonts.inter(
                      fontSize: 11.5, color: AppTheme.textSecondary)),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Varian'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int i) {
    final v = variants[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceMutedColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: v.name,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Nama varian (mis. Pedas, Ice)',
                      border: OutlineInputBorder(),
                    ),
                    style: GoogleFonts.inter(fontSize: 13),
                    onChanged: (t) => _update(i, v.copyWith(name: t)),
                    validator: (t) =>
                        (t == null || t.trim().isEmpty) && variants.length > 1
                            ? 'Isi nama varian'
                            : null,
                  ),
                ),
                IconButton(
                  onPressed: () => _removeAt(i),
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppTheme.errorColor),
                  tooltip: 'Hapus varian',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: v.sku ?? '',
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'SKU/Barcode (opsional)',
                      border: OutlineInputBorder(),
                    ),
                    style: GoogleFonts.inter(fontSize: 13),
                    onChanged: (t) => _update(
                        i,
                        v.copyWith(
                            sku: t.trim().isEmpty ? null : t.trim())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue:
                        v.priceDelta == 0 ? '' : v.priceDelta.toStringAsFixed(0),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Selisih harga (Rp)',
                      border: OutlineInputBorder(),
                    ),
                    style: GoogleFonts.inter(fontSize: 13),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (t) =>
                        _update(i, v.copyWith(priceDelta: double.tryParse(t) ?? 0)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: v.stock == 0 ? '' : v.stock.toStringAsFixed(0),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Stok',
                      border: OutlineInputBorder(),
                    ),
                    style: GoogleFonts.inter(fontSize: 13),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (t) =>
                        _update(i, v.copyWith(stock: double.tryParse(t) ?? 0)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
