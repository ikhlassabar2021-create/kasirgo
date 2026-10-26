# PROGRESS PHASE 17 - Ekosistem Hyper-Local

STATUS: ST17-7 SELESAI. PHASE 17 TUNTAS.
Sumber spec: `KASIRGO-WORKFLOW-LENGKAP.md` BAGIAN 17 (SUB-TASK ~2943; ST17-1..ST17-7;
17.3 RPC; 17.5 RISIKO).

## Prinsip (WAJIB)
- SATU APK mode ganda (Penjual/Pembeli); identitas Pembeli = Supabase anonymous auth +
  `app_customers`; order terpisah dari `transactions` (transactions dibuat saat order selesai).
- QRIS dual-mode (statis + validasi manual default); zero-custody / zero-logistics.
- `delivery_pass_through` (uang titipan ongkir) BUKAN omzet.
- Peta Rp0 (`flutter_map` + OSM tidak dipasang; radar `CustomPaint` sebagai gantinya).
- Bukti transfer Pembeli disimpan LOKAL di HP Pembeli (bukan Supabase Storage/R2).
- 1 sub-task = 1 commit + push, lalu STOP. Bahasa Indonesia. Design System v2.

## Subtask

### ST17-1 Fondasi Hyper-Local - SELESAI
- Migrasi `docs/migrations/2026-10-31-kasirgo-17a-hyperlocal.sql` DITERAPKAN:
  - Extension `postgis`; ALTER `outlets` (+`latitude`,`longitude`,`is_mobile`,`is_open`,
    `open_hours`,`service_queue_enabled`,`delivery_rules`) + index GIST `idx_outlets_geog`.
  - Tabel `app_customers`, `orders`, `order_items`, `outlet_locations`, `service_queue`.
  - ALTER `transactions` (+`channel`,`order_id`,`product_revenue`,`delivery_pass_through`).
  - RPC `current_app_customer_id`/`nearby_outlets`/`submit_order`/`validate_order_payment`/
    `complete_order`; RLS + Realtime publication; seed `platform_configs.hyperlocal`.
- Model: `models/outlet_location.dart`, `models/order.dart`, `models/app_customer.dart`.
- Service: `services/location_service.dart`, `services/order_service.dart`,
  `services/app_customer_service.dart`.
- E2E RPC (rollback) LULUS: `gross_amount=29000, product_revenue=24000,
  delivery_pass_through=5000, channel=online, payment_method=qris, order_status=selesai`.
- Commit `959202f`.

### ST17-2 Pesanan Online Masuk - SELESAI
- Migrasi `docs/migrations/2026-11-01-kasirgo-17b-online-orders-staff.sql` DITERAPKAN:
  akses order online owner + kasir/admin via helper `is_outlet_member(outlet)`.
- Layar `screens/cashier/online_orders_screen.dart` (realtime channel per outlet,
  validasi mutasi manual, selesaikan order) + tab di `incoming_orders_screen.dart`.
- Notifikasi + bunyi order (`notification_service.dart`, channel Android `kasirgo_orders`).
- Tombol 'Pesanan Online' di `pos_screen.dart`.
- Commit `ffe4c1d`.

### ST17-3 Laporan Keuangan Otomatis - SELESAI
- `report_screen.dart`: omzet = `productRevenue` (fallback `finalAmount - deliveryPassThrough`);
  titipan ongkir terpisah; "Arus Kas Masuk" = omzet + titipan (bukan omzet).
- Laporan & ekspor (Excel/PDF/WA) konsisten memakai `_productRevenueOf`; kolom Kas Masuk = Σ `finalAmount`.
- `dart analyze` bersih. Commit `8833171`.

### ST17-4 Mode Ganda Penjual/Pembeli - SELESAI
- `AppModeService` (SharedPreferences) + `AppModeProvider` + `ModeGate` reaktif di root router.
- Anonymous auth diaktifkan via Management API `/config/auth`
  (`external_anonymous_users_enabled: true`).
- Pembeli: `BuyerShell` + `BuyerOnboardingScreen` (consent UU PDP lokasi + nohp, disimpan LOKAL).
- `app_customers` upsert onConflict `auth_uid`. Navigasi mode tidak imperatif (reaktif).
- Commit `0e349e8`.

### ST17-5 App Pembeli (Radar + Katalog + Keranjang) - SELESAI
- Opsi A (tanpa dependency baru): radar visual `CustomPaint` + daftar; seam peta pluggable.
- `models/cart.dart` + `providers/cart_provider.dart` (in-memory; SATU toko per transaksi).
- `models/geo_position.dart` + `utils/geo*.dart` (conditional import; web Geolocation API).
- `services/buyer_location_service.dart` (lokasi lokal UU PDP).
- `screens/buyer/buyer_home_tab.dart`: radar `nearby_outlets`, katalog `get_public_catalog`,
  keranjang, iklan sisi pelanggan (`SponsorAdSlot`).
- Commit `ce05664`.

### ST17-6 Checkout + Tracking Pembeli - SELESAI
- `services/order_service.dart`: `getOrder` + `watchOrder` (realtime).
- `screens/buyer/buyer_checkout_screen.dart` (BARU): QRIS statis + bukti transfer LOKAL
  (ImagePicker -> base64 -> SharedPreferences `order_proof_<order_id>`), ringkasan WA.
- `screens/buyer/buyer_order_tracking_screen.dart` (BARU): stepper 5 langkah + realtime.
- KEPUTUSAN USER: bukti transfer disimpan LOKAL di HP Pembeli (tanpa Storage/R2, tanpa RPC baru).
- Commit `4a89471`.

### ST17-7 Gerobak Live Tracking + Antrean Jasa + Hardening + E2E - SELESAI
- Migrasi `docs/migrations/2026-11-02-kasirgo-17c-hardening.sql` DITERAPKAN:
  - `enforce_order_rate_limit()` + trigger `trg_orders_rate_limit` BEFORE INSERT `orders`
    (baca `platform_configs.hyperlocal.order_rate_limit_per_hour`, default 5; skip bila
    `buyer_id IS NULL`; `RAISE EXCEPTION 'ORDER_RATE_LIMITED...'` ERRCODE check_violation).
  - DROP + CREATE ulang `nearby_outlets(...)` dengan kolom return BARU `service_queue_enabled`;
    GRANT anon + authenticated.
  - RPC `take_queue_number(p_outlet UUID)` -> JSONB `{success,id,number}` (guard
    `AUTH_REQUIRED`/`QUEUE_DISABLED`, nomor = max+1, status 'menunggu'); GRANT authenticated.
  - Audit RLS (dokumentasi; tanpa perubahan).
- Model: `models/outlet_location.dart` `NearbyOutlet` +field `serviceQueueEnabled`.
- Service: `supabase_service.dart` +`getOutletLiveConfig`/`setOutletLiveFlags`/
  `setOutletCoordinates`; `location_service.dart` `takeQueueNumber` pakai RPC atomik
  (fallback insert max+1).
- Owner: `screens/owner/lapak_live_screen.dart` (BARU) - toggle Buka Lapak/Gerobak Keliling,
  broadcast lokasi berkala 60s (saat app terbuka), input koordinat manual, kelola antrean
  (Panggil/Selesai). Wiring kartu 'Lapak Live' di `owner_home_screen.dart` (tanpa gate).
- Pembeli: `buyer_home_tab.dart` tampilkan posisi live (`watchOutletLocation`) + tombol
  "Ambil Nomor Antrean" saat outlet mengaktifkan antrean jasa.
- E2E (rollback, `/tmp/q33.sql`) LULUS: rate limit trigger fired setelah 5 order;
  `take_queue_number` -> `{success:true, number:1}`; `current_app_customer_id` resolve;
  `nearby_outlets` mengembalikan `service_queue_enabled`.
- Hardening lain: audit RLS (owner full + buyer self + superadmin; `orders` buyer tanpa
  UPDATE policy = by design ST17-6); iklan HANYA di sisi Pembeli (`SponsorAdSlot`);
  privasi UU PDP (lokasi/consent/bukti bayar LOKAL); ukuran APK via App Bundle/split-ABI
  (target per ABI < 10MB, kebijakan existing).
- `dart analyze` file tersentuh: hanya info pre-existing (bukan blocker).

### KDS Menampilkan Pesanan Online + Update Status Dapur - SELESAI
- `screens/modules/kitchen_display_screen.dart`: `KitchenOrder.source` (`dine_in`/`online`),
  realtime channel `owner-kds-$outletId` ikut subscribe `orders`, `_loadOnlineOrders()` baca
  `OrderService.listOrders(outletId, paymentStatus: 'divalidasi', limit: 30)` difilter hari ini
  + status `baru|diproses|siap`; badge `ONLINE`; tombol status berhenti di `ready`
  (`SIAP - TUNGGU KASIR`) karena penutupan order dilakukan kasir (`complete_order`).
- Commit `89fc628`; deploy web gh-pages `3157c6c` (bundle live memuat "TUNGGU KASIR").
- VERIFIKASI LIVE (Playwright gh-pages, outlet Toko Test sementara `type=Cafe`):
  - Kartu pesanan online tampil: `ORD26101909999 / ONLINE / Ambil di toko / DIMASAK / TANDAI SIAP SAJI`.
  - Klik status -> `SIAP SAJI` + label tombol `SIAP - TUNGGU KASIR`; DB `orders.status` = `siap`.
  - Login role kitchen (`+kokitest`) langsung masuk KDS dan melihat kartu yang sama;
    REST PATCH status oleh role kitchen -> 200 (RLS `is_outlet_member` OK). `ERRORS 0`.
  - Cleanup: order + order_item uji dihapus; `outlets.type` Toko Test dikembalikan
    ke `Warung Sembako`.

### Kasir Validasi + Selesaikan Pesanan Online (Order -> Transaksi + Pelanggan) - SELESAI
- Tujuan: verifikasi alur kasir "Pesanan Masuk" di build live gh-pages: order online
  `belum_konfirmasi` -> "Pembayaran Valid & Proses" (`validate_order_payment`) ->
  "Selesai" (`complete_order`) -> transaksi + pelanggan otomatis.
- Fixture uji (Toko Test `229c94d7-...`): produk `__QA_KASIR__` (base_price 5000,
  stock 10, unpublished), order `ORD26101908888` (`pickup`, total 10000, buyer
  `QA Kasir` / `089900000123`), item qty 2 line_total 10000.
- VERIFIKASI LIVE (Playwright gh-pages, `/workspace/e2e/cashier_orders.mjs` +
  `cashier_complete2.mjs`):
  - Login owner -> "Pesanan Masuk" -> "Pesanan Online" -> chip "Menunggu Pengecekan".
  - Klik "Pembayaran Valid & Proses" -> snackbar "Pembayaran valid. Pesanan diproses.",
    kartu pindah ke chip "Aktif"; DB `orders`: `status=diproses`,
    `payment_status=divalidasi`, `validated_at` terisi. `ERRORS 0`.
  - Klik "Selesai" pada kartu -> kartu hilang dari daftar aktif; DB `orders`:
    `status=selesai`, `transaction_id` terisi; `transactions` dibuat
    (`channel=online`, `payment_method=qris`, `final_amount=10000`,
    `status=completed`, `order_id` = order uji, `product_revenue=10000`);
    `transaction_items` 2 x 5000 = 10000; `customers` baru
    (`QA Kasir` / `089900000123`, `total_spent=10000`).
- CATATAN A11Y (temuan, belum diubah): pada chip "Aktif", kartu pesanan terpapar
  sebagai SATU node `role="button"` (aria-label kosong, seluruh teks kartu di
  `textContent`) sehingga tombol "Selesai" tidak bisa diklik lewat selector
  semantik; klik koordinat pada baris aksi tetap berfungsi dan alur DB terbukti
  benar. Pada chip "Menunggu" tombol anak tetap terpapar normal. Tidak ada
  perubahan kode (murni verifikasi); perlu widget/semantics test terpisah bila
  ingin memperbaiki.
- CLEANUP (REST, owner JWT): order + order_item + product dihapus; transaksi
  dihapus via RPC `delete_transaction` (stok produk sudah tidak ada -> 0 baris,
  `stock_logs` koreksi yang terbentuk ikut dihapus); baris `customers` uji
  dihapus. Residu diverifikasi 0 (orders/order_items/transactions/
  transaction_items/customers/products/stock_logs). Order `ORD26101900049`
  (uji pertama yang salah sasaran) dikembalikan ke `baru`/`belum_konfirmasi`
  dengan `validated_at`/`validated_by` NULL.
- Tidak ada perubahan build web -> tidak perlu deploy gh-pages.

### Perbaikan Semantik Tombol Kartu Pesanan (a11y) - SELESAI
- Akar masalah: `BubbleButton` (`lib/widgets/common/bubble_glass.dart`) membungkus
  isinya dengan `Semantics(button: true, ...)` TANPA `container: true`. Pada kartu
  yang hanya punya SATU tombol aksi (chip "Aktif"), semantik tombol melebur ke node
  kartu induk -> kartu terpapar `role=button` dan tombol "Selesai" tak punya node
  sendiri (tak bisa diklik via selector semantik / pembaca layar).
- Fix: tambah `container: true` pada `Semantics` di `_BubbleButtonState.build`
  (berlaku untuk semua kartu, bukan tambal per layar).
- Test regresi baru `test/bubble_button_semantics_test.dart` (3 test): tombol tunggal
  tetap node terpisah dari kartu, dua tombol tetap terpisah, tombol disabled
  melaporkan `isEnabled == Tristate.isFalse`. Terbukti GAGAL tanpa fix, LULUS
  dengan fix (`+3 All tests passed`). `flutter analyze` 2 file bersih.
- VERIFIKASI LIVE (Playwright gh-pages, `/workspace/e2e/a11y_semantics_verify.mjs`):
  fixture order `ORD26101907777` (Toko Test, pickup, 2 x __QA_A11Y__ Rp10.000)
  divalidasi -> chip "Aktif" -> kartu terpapar `role=group` (BUKAN button) dengan
  `aria-label` berisi data pesanan, dan "Selesai" menjadi node `role=button`
  terpisah di dalam kartu -> klik label berhasil: DB `orders.status=selesai`,
  `transaction_id` terisi; `transactions` `channel=online`, `final_amount=10000`,
  `status=completed`; `ERRORS 0`. Cleanup penuh (RPC `delete_transaction`,
  order/order_items/produk/pelanggan) -> residu 0.
- Deploy web release gh-pages `37b4817` (md5 `main.dart.js`
  `0d78ae79f501fb42ba7e6a631ebd0134` cocok build lokal).

### Radar Pembeli: Deteksi Lokasi Lintas Platform + Radius - SELESAI
- Akar masalah "hanya Toko Test muncul": 8 dari 10 outlet `latitude/longitude`
  NULL karena tombol "Deteksi lokasi" di Lapak Live dulu hanya jalan di web
  (`dart:html`) -> di APK lokasi owner tak pernah tersimpan.
- `lib/utils/geo.dart`: `detectDevicePosition({prompt})` -> `kIsWeb` pakai
  Geolocation API (conditional import `geo_stub.dart`/`geo_web.dart`), native
  pakai `geolocator` (`getCurrentPosition(desiredAccuracy: best, timeLimit: 15s)`).
  `prompt:false` dipakai broadcast 60 detik agar tak memicu dialog izin OS.
- `AndroidManifest.xml`: `ACCESS_COARSE_LOCATION` + `ACCESS_FINE_LOCATION`.
  `lapak_live_screen.dart` + `buyer_location_service.dart` memakai helper baru.
- Radar pembeli: chip radius 3/5/10 km (default 10 sesuai config
  `radius_default_km`), subtitle "Dalam radius X km dari lokasimu", empty state
  mengarahkan owner menayangkan lewat Lapak Live.
- Migrasi `docs/migrations/2026-10-24-kasirgo-18-tickets-radar.sql`
  (`support_tickets` + radius 10 km) sudah diterapkan di DB live.
- Verifikasi REST: RPC `nearby_outlets` radius 10 km dari Jakarta
  (-6.395,106.841) mengembalikan Toko Test + Gerobak Test (~0.02 km).
- E2E LIVE Playwright (`/tmp/opencode/radar_buyer_e2e.js`, mode Pembeli ->
  login `qa.checkout@kasirgo.test`): `Toko Terdekat` tampil, `Lokasi aktif
  -6.3950, 106.8410` terdeteksi otomatis (tanpa input manual), chip
  `3/5/10 km` ada, `Toko Test` + `Gerobak Test` (20 m) tampil; klik chip
  `3 km` -> subtitle "Dalam radius 3 km dari lokasimu"; `ERRORS 0`.
 - Commit `ab24b4d`; deploy web gh-pages `2c2e030` (md5
   `f14a1fd55b011003c23e94be7eb68013` cocok build lokal).
 - APK 1.0.8 RILIS: commit workflow `ae8490d` (tag push tanpa secret keystore
   tetap build debug-signed), tag `v1.0.8-apk-20261026` -> CI run `40263784331`
   SUKSES; artefak diunduh + zipalign + re-sign lokal dengan keystore rilis
   (SHA-1 `a617302d91c6...414c28`, sama dengan 1.0.7) + AAB ditandatangani
   jarsigner; GitHub Release **`v1.0.8-apk-20261026`** (id `423974683`)
   berisi 3 APK + AAB + `SHA256SUMS-1.0.8.txt`. Verifikasi: re-download arm64
   sha256 MATCH, `apksigner verify` cocok, `versionName 1.0.8` / `versionCode
   2009`, permission `ACCESS_FINE/COARSE_LOCATION` ada di manifest.

## Catatan
- `flutter_map`/`latlong2` TIDAK dipasang (hemat token Phase 17); radar `CustomPaint`.
- `geolocator` + `geolocator_web` DIPASANG (versi app 1.0.8+9) untuk deteksi
  lokasi lintas platform; fix hanya efektif di APK 1.0.8+9 ke atas.
- Supabase Storage TIDAK dipakai (q30 `[]`); bukti transfer LOKAL; thumbnail online opt-in R2.
- Rate limit memakai trigger (bukan RPC) agar semua jalur INSERT `orders` tercakup.
