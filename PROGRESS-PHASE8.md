# PROGRESS PHASE 8 — Modul per outlet_type

Roadmap: docs/KASIRGO-WORKFLOW-LENGKAP.md Bagian 3.2 / 8.
Aturan modul: kelontong = semua kecuali QR Meja; warteg/cafe = semua kecuali PPOB;
retail = semua kecuali QR Meja & KDS; gerobak = semua kecuali PPOB & QR Meja.

## SELESAI

### ST8-1 — Migrasi DB + Registry Modul (2026-10-01)
- `docs/migrations/2026-10-01-kasirgo-8.sql` — RAN di live DB:
  - Tabel baru: `product_variants` (barcode, sku, price_delta, stock, is_active),
    `recipes` (yield_qty, UNIQUE outlet+product), `recipe_items` (ingredient_product_id+qty),
    `shifts` (opening/closing cash, expected/difference, total cash/qris/transfer/tip, note),
    `tips` (transaction_id, user_id, shift_id, amount), `transaction_payments` (split bill,
    method cash/qris/bank_transfer + ref + shift_id), `stock_logs` (product/variant, change,
    reason penjualan|resep|restock|koreksi|lainnya, ref_id).
  - Kolom baru: `products.has_variants BOOLEAN DEFAULT false`.
  - RLS pola outlet_id: Owner FULL; Admin manage variants + read lainnya;
    Cashier read variants/recipes, INSERT shifts/tips/transaction_payments/stock_logs
    (sendiri); superadmin via service key.
  - Index: variants(product/outlet/barcode), recipes(outlet+product), recipe_items,
    shifts(outlet+opened_at, user), tips(shift/transaction/user), transaction_payments,
    stock_logs(outlet+created, product, variant), products(outlet, has_variants).
- `lib/services/module_registry.dart` — registry modul dinamis:
  default per outlet_type (ModuleConfig) + override `feature_flags` key `module_<nama>`
  (enabled=false matikan walau default on; =true nyalakan walau default off);
  cache TTL 5 menit, offline fallback default.
- `lib/providers/module_provider.dart` — `activeModulesProvider` kini memakai
  `ModuleRegistry.effectiveModules` (flag dimuat via `moduleFlagsProvider`).
- Menu owner home sudah memfilter kartu modul lewat `activeModulesProvider`
  (Kasbon/PPOB/B2B/KDS/QR Meja dst tampil sesuai outlet_type).

### Cara uji ST8-1
1. Login owner Cafe → menu tampil KDS + QR Meja, tanpa PPOB.
2. Login owner Warung (kelontong) → PPOB tampil, QR Meja tidak.
3. Superadmin buat feature_flag `module_ppob` enabled=false → PPOB hilang dari kelontong
   setelah refresh (cache 5 menit / restart app).

### ST8-2 — Variant Produk (2026-10-01)
- Migrasi section 7 (RAN live): `transaction_items.variant_id UUID`;
  trigger `decrement_stock()` baru — item dengan `variant_id` mengurangi stok VARIAN
  + `stock_logs` reason 'penjualan', tanpa varian tetap produk; trigger lama duplikat
  `tr_decrement_stock` DIHAPUS (sebabnya stok berkurang 2x).
- `models/product.dart` +`hasVariants`; `models/variant.dart`: +outletId/barcode/isActive,
  StockLog sinkron kolom DB (`change`, fallback `delta`).
- `supabase_service.dart`: +updateProductVariant, syncProductVariants (insert/update/delete),
  getVariantCounts, deleteProductVariant, setProductHasVariants; `createTransaction`
  kini mengirim `variant_id` pada item.
- `widgets/common/variant_editor.dart` (baru); `product_form_screen.dart`: toggle
  "Produk punya varian" + editor + sync saat simpan.
- `product_list_screen.dart`: badge "N varian" + bottom sheet detail varian
  (stok/SKU/harga final).
- POS (`pos_screen.dart`): produk has_variants → bottom sheet pilih varian
  (stok per varian dijaga, harga = harga produk + price_delta, nama item
  "Produk - Varian", keranjang unik per productId+variantId).
- Catatan: toggle varian saat ini tampil untuk semua outlet_type; gate khusus
  retail dikerjakan di ST8-6 QA.

### Cara uji ST8-2
1. Owner retail buat produk "Kopi Sachet" punya varian (Original/Renyah, delta +2000).
2. POS klik produk → pilih varian → qty 2 → checkout → stok varian berkurang 2,
   `stock_logs` muncul baris reason 'penjualan' dengan variant_id.
3. List produk tampil badge "2 varian"; tap badge → detail varian.

## BERIKUTNYA
- ST8-3: Resep/BOM (cafe/warteg) — recipe_screen, recipe_items, HPP = sum qty x cost
  bahan, margin + harga saran, stok bahan berkurang saat penjualan produk ber-resep
  (reason 'resep'), HPP di product_form & laporan.
