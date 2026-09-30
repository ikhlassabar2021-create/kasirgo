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
- Phase 10: Fintech Lead + Hyperlocal Data + Micro-insurance
  (lihat workflow Bagian PHASE 10; mulai dari docs/PROMPT-GILIRAN.md).

## STATUS PHASE 9: SELESAI

### ST9-2 — Closed-Loop Settlement: Saldo QRIS -> PPOB (2026-09-30)
- Migrasi tambahan (bagian 6 kasirgo-9.sql) — RAN live:
  - `settlements` (ledger): amount bertanda (positif = QRIS masuk,
    negatif = dipakai PPOB), source qris|ppob|manual,
    status pending|success|failed|PPOB_USED, ppob_transaction_id, note.
    Saldo outlet = SUM(amount) WHERE status IN (success, PPOB_USED).
  - RLS: Owner FULL, staf read; index (outlet+created, status).
  - RPC (SECURITY DEFINER, cek auth.uid() owner/staf):
    `get_outlet_saldo(p_outlet)`, `ppob_use_saldo(p_outlet, p_tx, p_amount)`
    — atomik (cek cukup -> tx success+payment_method saldo -> catat
    PPOB_USED; raise insufficient_saldo/tx_not_pending/forbidden),
    `settlement_add_qris(p_outlet, p_amount, p_note)` (owner saja).
  - Config `platform_configs('ppob')` + key `enabled` (default true).
- `PpobService`: `PpobException`; config `enabled`; `getSaldo()` (RPC +
  fallback select), `addQrisToSaldo()`, `refreshStatus()` (sinkron status
  pending dari provider); `purchase()` metode 'saldo' -> RPC atomik
  (saldo kurang -> tx ditandai failed + pesan ramah).
- `ppob_screen.dart`:
  - Kartu saldo gradient (closed-loop) + refresh + tombol owner
    "Setor QRIS ke Saldo" (jumlah + catatan).
  - Metode Saldo AKTIF bila saldo >= harga; label "Saldo kurang" bila
    tidak cukup.
  - Rincian transparan di inquiry: harga jual / modal provider / margin
    (modal+margin hanya owner & admin; kasir lihat harga saja).
  - Hasil saldo: sisa saldo ditampilkan; riwayat pending ada aksi
    "Cek" (rekonsiliasi status dari provider).
- Gate: modul ppob (outlet_type) DAN config `enabled` (superadmin).
  `ppobEnabledProvider` (module_provider) memagari kartu di owner home;
  screen menampilkan "PPOB Belum Diaktifkan" bila config off.
- `screens/modules/ppob_screen.dart` kini re-export implementasi nyata
  (owner/ppob_screen.dart) — sebelumnya placeholder "segera".
- QA DB (SET LOCAL ROLE authenticated sebagai owner):
  setor 200.000 -> saldo 200.000; beli via saldo 10.762,50 -> saldo
  189.237,50; tx success + provider_ref SALDO-<id>; settlements 2 baris
  (+QRIS, -PPOB_USED); beli > saldo -> exception insufficient_saldo.
  Data QA dibersihkan (saldo kembali 0).

### Cara uji ST9-2
1. Owner: PPOB -> "Setor QRIS ke Saldo" 200.000 -> beli Pulsa 10.000
   pilih metode Saldo -> popup sukses + sisa saldo terpotong otomatis.
2. Coba beli melebihi saldo -> opsi Saldo nonaktif ("Saldo kurang").
3. Superadmin: platform_configs('ppob').enabled=false -> kartu PPOB
   hilang dari owner home + screen menampilkan status nonaktif.

### ST9-3 — Embedded B2B Restock (2026-09-30)
- Migrasi tambahan (bagian 7 kasirgo-9.sql) — RAN live:
  - `restock_orders` (outlet_id, user_id, distributor, tracking_id UNIQUE,
    amount, commission, status draft|pending|confirmed|shipped|completed|
    cancelled, items_note) + RLS: Owner FULL; staf read + insert; index
    (outlet+created, status).
  - Config `platform_configs('b2b_restock', global)`: enabled=false,
    distributor_url='', distributor_name, commission_percent=2,
    allowed_domains=[] — link & komisi diatur superadmin TANPA ubah
    koding.
- `lib/services/b2b_service.dart` (baru): B2bConfig (parse + hosts untuk
  domain lock), `loadConfig()`, `buildTrackingId()` (RST-<outlet8>-<ts>),
  `buildCatalogUrl()` (tambah ref + tracking_id), `commissionFor()`,
  `getSummary()` periode.
- `lib/models/restock.dart`: +userId/commission/itemsNote/updatedAt
  (serializer sinkron kolom DB).
- `lib/screens/modules/restock_screen.dart` (REWRITE dari placeholder):
  - Header distributor (nama + komisi%) + tombol "Buka Katalog".
  - WebView `RestockWebViewScreen`: DOMAIN LOCK anti-bypass (hanya host
    config + allowed_domains; redirect luar diblokir + snackbar),
    tracking_id di app bar + di URL katalog, error state + retry.
  - FAB "Sudah Order": catat total belanja -> restock_orders +
    komisi otomatis (config) -> snackbar estimasi komisi.
  - Riwayat restock: tracking_id, amount, komisi, badge status.
- Laporan: `report_screen.dart` section "Restock B2B (Kulakan)" (Total +
  Komisi Platform); `report_scheduler_service.dart` baris WA
  "Restock B2B: order X - komisi Y".
- Gate: modul restockB2B (outlet_type); config off/URL kosong -> state
  "Katalog Distributor Belum Aktif" (order tetap bisa dicatat manual).
- pubspec: +`webview_flutter: ^4.13.0` (pub get OK).
- QA DB: insert order (tracking RST-QATEST-1) OK; RLS read owner OK;
  duplikat tracking_id ditolak UNIQUE; data QA dibersihkan.

### Cara uji ST9-3
1. Superadmin: platform_configs('b2b_restock') set enabled=true +
   distributor_url='https://distributor.example.com' + commission_percent
   -> owner home kartu "Kulakan B2B" langsung pakai link baru.
2. Owner: Buka Katalog (WebView terkunci ke domain tsb; coba redirect
   luar -> diblokir) -> tekan centang -> "Sudah Order" 500.000 ->
   komisi 2% (10.000) tercatat + muncul di laporan & WA harian.
