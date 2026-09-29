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

### ST8-3 — Resep/BOM + HPP (2026-09-29)
- `models/recipe.dart`: RecipeItem +`unit` (gram/ml/biji).
- `supabase_service.dart`:
  - `saveRecipe` jadi UPSERT (`ON CONFLICT outlet_id,product_id`), replace items,
    kirim `outlet_id` pada items (kolom NOT NULL di DB);
  - +`deleteRecipe`, `getRecipesForOutlet` (join product name/price/cost);
  - +`deductRecipeIngredients`: konsumsi bahan = qty_resep x (terjual / yield_qty),
    kurangi stok bahan + `stock_logs` reason 'resep' ref_id=transaction id (best effort).
- `screens/owner/recipe_screen.dart` (baru): daftar produk dengan/tanpa resep,
  editor resep (yield porsi, pilih bahan + qty + satuan), HPP resep = sum qty x
  cost bahan, HPP per porsi, slider target margin -> harga saran,
  opsi "Set HPP produk = HPP per porsi" (dipakai laporan laba).
- `owner_home_screen.dart`: kartu modul "Resep & HPP" (gated recipeIngredients).
- `pos_screen.dart`: setelah transaksi sukses, kurangi stok bahan per item
  (deductRecipeIngredients per product, fire-and-forget).
- `product_form_screen.dart`: info "produk punya resep" di dekat Harga Modal.
- QA DB (cafe outlet): upsert resep OK (UNIQUE outlet+product), item tercatat,
  deduksi 1000 -> 900 (yield 2, jual 2, qty 100 gram), stock_logs reason 'resep' OK.
  Data QA dibersihkan.
- Catatan: `stock_logs.ref_id` bertipe UUID (id transaksi/resep, bukan string bebas).

### Cara uji ST8-3
1. Owner cafe: Produk -> buat "Gula Pasir" (modal Rp15.000/kg) & "Es Teh" (jual Rp5.000).
2. Menu "Resep & HPP" -> Es Teh -> Buat Resep -> bahan Gula 20 gram, yield 1 ->
   HPP porsi = 300; target margin 60% -> harga saran ~Rp750; aktifkan Set HPP.
3. POS jual 2 Es Teh -> stok Gula berkurang 40, stock_logs ada baris reason 'resep'.
4. Laporan -> Estimasi Laba memakai HPP baru.

### ST8-4 — KDS Lengkap (2026-09-29)
- KDS sudah punya: Realtime (postgres_changes transactions per outlet),
  filter chips Semua/Menunggu/Dimasak/Siap, transisi status via RPC
  `set_order_status(p_tx, p_status)` (RPC ada di live DB).
- Peningkatan ST8-4:
  - `getDineInOrders` kini hanya pesanan HARI INI (gte start of day) -
    tiket kemarin tidak lagi menggantung.
  - Indikator antrean >10 menit merah tebal (sebelumnya 15).
  - Timer 30 detik menyegarkan umur tiket tanpa menunggu event.

### Cara uji ST8-4
1. Pelanggan scan QR meja (channel dine_in) -> pesanan muncul di KDS tanpa refresh.
2. Tekan tiket -> MENUNGGU -> DIMASAK -> SIAP SAJI -> hilang dari antrean.
3. Tiket >10 menit tampil merah; umur tiket bertambah sendiri tiap 30 detik.

### ST8-5 — Shift Kasir + Tip + Split Bill (2026-09-29)
- `models/shift.dart` REWRITE ke skema baru (status open/closed, opening/closing/
  expected cash, difference, total cash/qris/transfer/tip, note, user_id);
  `models/tip.dart` +shift_id +note.
- `supabase_service.dart`:
  - +getOpenShift, openShift (tolak double open), getShiftHistory,
    closeShift (rekap dari transaction_payments per metode + tips,
    expected = opening + cash, difference = fisik - expected),
    addTransactionPayment, addTip;
  - hapus stub lama openShift/closeShift duplikat; getActiveShift pakai status='open'.
- `checkout_dialog.dart`: +SplitPayment; opsi "Split Bill (Bayar Gabungan)" -
  baris [metode | nominal], indikator "Sisa belum dibayar", validasi total
  pembayaran = tagihan (toleransi Rp1) sebelum LUNAS; tip tetap terpisah.
- `pos_screen.dart`: muat shift terbuka saat init; setelah transaksi sukses
  catat transaction_payments (per split, atau tunggal) + tips dengan shift_id.
- `screens/owner/shift_screen.dart` (baru): banner shift aktif (modal awal, tip),
  tombol Buka Shift (modal awal) / Tutup Shift (hitung fisik + catatan,
  tampilkan selisih), riwayat shift dengan badge "KAS PAS"/"Selisih".
- `owner_home_screen.dart`: kartu "Shift Kasir" (gated splitBill).
- QA DB (cafe outlet): shift open + split cash 60k/qris 40k (= tagihan 100k)
  + tip 5k -> closeShift total_cash 60k, total_qris 40k, tip 5k,
  expected 260k (modal 200k+cash), difference 0. Data QA dibersihkan.
- Catatan: shifts.user_id & tips.user_id FK ke auth.users (NOT NULL utk shifts).

### Cara uji ST8-5
1. Owner/kasir: "Shift Kasir" -> Buka Shift modal Rp200.000.
2. POS belanja Rp100.000 -> pilih Split Bill -> cash 60.000 + QRIS 40.000 ->
   sisa 0 -> konfirmasi (tanpa split, pembayaran tunggal tercatat normal).
3. Tambahkan tip Rp5.000 pada transaksi -> tercatat di tips.
4. Tutup Shift -> hitung fisik Rp260.000 -> "KAS PAS", riwayat tampil rekap.

### ST8-6 — QA + Gate + Docs + Deploy (2026-09-29)
- Gate varian: toggle "Produk punya varian" di product_form hanya tampil
  untuk outlet_type retail (via `outletTypeProvider`); kasir_home di-retrofit
  ke API Shift baru (tanpa kolom shift pagi/siang/malam, selisih kas di snackbar,
  tip menyertakan shift_id aktif).
- `flutter analyze lib`: 0 error, 0 warning (21 info pre-existing).
- QA DB lulus: trigger stok varian (sekali per insert, trigger duplikat lama
  `tr_decrement_stock` dihapus), upsert resep + deduksi bahan (1000->900,
  stock_logs 'resep'), shift + split bill + tip (expected 260k, selisih 0).
  Semua data QA dibersihkan.
- Docs: KASIRGO-WORKFLOW-LENGKAP Bagian Phase 8 (SELESAI), AGENTS.md tracker
  Phase 8 SELESAI.
- Deploy: flutter build web --base-href /kasirgo/ -> gh-pages.

## STATUS PHASE 8: SELESAI (ST8-1 s/d ST8-6)

## BERIKUTNYA
- Phase 9: PPOB + Closed-loop settlement + Embedded B2B Restock (ST9-1..ST9-3).
