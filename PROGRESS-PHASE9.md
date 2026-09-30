# PROGRESS PHASE 9 — PPOB + Closed-loop + B2B Restock

Roadmap: docs/KASIRGO-WORKFLOW-LENGKAP.md Bagian PHASE 9 (ST9-1..ST9-3).
Kontrol: semua nilai provider/api_key/margin diatur superadmin via platform_configs('ppob').

## SELESAI

### ST9-1 — Fondasi PPOB + Harga Jual Margin Otomatis (2026-09-29)
- Migrasi `docs/migrations/2026-10-01-kasirgo-9.sql` — RAN live:
  - `ppob_products` (sku UNIQUE, category, nominal, cost_price/modal,
    sell_price optional override, provider, is_active) + RLS read publik (aktif).
  - `ppob_transactions` (outlet_id, user_id, ppob_product_id, product_name,
    customer_ref, amount/cost_amount/profit, status pending|success|failed,
    payment_method cash|qris|saldo, provider_ref, note) + RLS outlet_id:
    Owner FULL; admin/cashier read + insert; superadmin service key.
  - Index: products(category), tx(outlet+created, status, product, customer_ref).
  - Seed 15 produk demo (pulsa 5k-100k, data 2/5/10GB, token PLN, game, e-money).
  - Config `platform_configs('ppob', global)`: provider demo, api_key '',
    margin_percent 5.
- `lib/models/ppob.dart`: PpobTransaction +userId/productName/costAmount/profit/
  paymentMethod/note; serializer sinkron kolom DB.
- `lib/services/ppob_service.dart` (baru):
  - `loadConfig()` — baca platform_configs('ppob') + cache SharedPreferences
    TTL 5 menit + fallback default (offline-safe).
  - `sellPriceFor()` — harga jual = cost + margin% (atau sell_price override);
    BUKAN hardcode; margin diubah superadmin -> harga katalog auto ikut.
  - `inquire/inquireSync` + `validateRef` per kategori (HP 08/628 10-13 digit,
    PLN 10-12 digit, game/e-money min length).
  - `purchase()` — insert pending -> mode demo (api_key kosong): langsung
    success + provider_ref 'DEMO-<ts>'; mode provider nyata: kirim ke Edge
    Function endpoint (config) -> update status/provider_ref.
  - `getProducts/getCategories/getHistory/getSummary` (summary hanya success).
- `lib/screens/owner/ppob_screen.dart` (baru): kategori chips, grid katalog
  (harga jual otomatis), dialog inquiry (validasi live + pilih bayar Tunai/
  QRIS; Saldo disabled s.d. ST9-2), dialog hasil + provider_ref, riwayat
  transaksi + badge status. Card sudah ada di owner home (gated module ppob).
- Laporan: `report_screen.dart` tab Ringkasan menambah section PPOB
  (Penjualan PPOB + Laba PPOB + modal) saat ada transaksi sukses;
  `report_scheduler_service.dart` (laporan WA ke bos) menambah baris
  "PPOB: jual X - laba Y".
- QA DB: insert tx pulsa 10k -> amount 10.762,50 (modal 10.250 + 5%),
  profit 512,50; summary cocok. Data QA dibersihkan.

### Cara uji ST9-1
1. Owner kelontong/retail: menu "PPOB & Pulsa" -> kategori Pulsa ->
   pilih Pulsa 10.000 -> input 08xx valid -> Bayar Tunai ->
   popup "Transaksi Berhasil" + ref DEMO-...
2. Ubah margin di platform_configs('ppob').margin_percent jadi 8 ->
   harga katalog otomatis naik setelah cache 5 menit / refresh.
3. Laporan Ringkasan (periode hari ini) -> section PPOB tampil jual + laba;
   laporan WA harian ikut menyertakan laba PPOB.

## BERIKUTNYA
- ST9-2: Closed-loop settlement (saldo QRIS -> beli PPOB real-time) +
  integrasi provider nyata (endpoint/webhook), aktifkan metode bayar Saldo.
