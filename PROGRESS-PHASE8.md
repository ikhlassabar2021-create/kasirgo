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

## BERIKUTNYA
- ST8-2: Variant produk (retail) — model, CRUD, form toggle + daftar varian,
  badge di list, pilih varian di POS, stok varian + stock_logs.
