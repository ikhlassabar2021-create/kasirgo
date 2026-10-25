# KasirGo -- Project Memory

## Project Summary
Aplikasi kasir UMKM super-app untuk Indonesia (warung Madura, kelontong, retail, cafe, restoran). Bukan sekadar POS -- alat peningkat omset: AI Co-Pilot + WhatsApp Commerce + Social Commerce Sync.

## Tech Stack
- Flutter (Dart) -- single APK semua role (owner/admin/kasir/customer), offline-first SQLite
- React.js + Vite + Tailwind -- superadmin web dashboard (Vercel)
- Supabase -- PostgreSQL, Auth, RLS, Storage, Edge Functions
- Vercel free tier + Supabase free tier = Rp0 infrastruktur

## Database (Supabase PostgreSQL)
13 tabel: outlets, user_roles, products, product_prices, product_discounts, transactions, transaction_items, customers, employees, subscriptions, affiliates, affiliate_referrals, ai_insights.
Tabel 3.0 (+): merchants, supporters, supporter_benefits, product_variants, stock_logs, shifts, tips,
recipes, recipe_items, ppob_products, ppob_transactions, restock_orders, fintech_leads, receipt_sponsors,
platform_financial_configs, settlements, disbursements, platform_integrations, outlet_kyc,
outlet_staff_quota, affiliate_payouts.

RLS: Owner full access outlet sendiri (termasuk HAPUS produk) + kelola staf; Admin tambah/edit produk + read reports (DELETE produk ditolak); Cashier read produk + insert transaksi; Superadmin via service key.
Triggers: `handle_new_user` auto-create outlet on signup; `decrement_stock` auto-kurang stok on transaction item insert.
Schema SQL lengkap: docs/KASIRGO-WORKFLOW-LENGKAP.md Phase 1.

## Roles
| Role | Akses | Platform |
|------|-------|----------|
| Owner | Full access semua modul + hapus produk + kelola staf + affiliate | Flutter Mobile |
| Admin | Tambah/edit produk + laporan standar (tanpa hapus produk) | Flutter Mobile |
| Cashier | Lihat/pilih produk + QRIS manual | Flutter Mobile |
| Customer | Scan QR meja -> order (cafe/resto) | Flutter Mobile |
| Superadmin | User mgmt, impersonate, backup/restore, affiliate, revenue, Control Plane (setting integrasi) | React Web |

## Program Pendukung + Kuota Staf
GRATIS SELAMANYA untuk fitur inti. Fitur kosmetik/bonus via Program Pendukung.
Rencana 7.8: SATU harga Rp50.000/bulan (menggantikan 3 tier Pendukung/Pro/Setia).
Kuota akun staf gratis per outlet: 1 Admin + 1 Kasir (Owner create & hapus sendiri). Lebih banyak -> Program Pendukung.

## Control Plane (setting via Superadmin, TANPA ubah koding)
Semua nilai integrasi/margin disimpan di DB (`platform_integrations` + `platform_financial_configs`),
di-cache app + fallback default. Grup setting: Payment Gateway (Duitku dll + margin + pencairan),
PPOB (api key + modal + margin persen -> harga jual auto), B2B Kulakan (link affiliate distributor),
Affiliate (komisi upgrade + pencairan otomatis), Fintech (link partner), Storage (Cloudflare R2),
Database (url/user/password/apikey), WA Bisnis (api key). Detail: workflow Bagian 1.10 & 7D (Phase 7.7).

## AI Co-Pilot (Semua Paket, local compute, Rp0)
Prediksi penjualan (moving average), deteksi anomali (z-score), rekomendasi produk serupa (association rule), ABC ranking (Pareto), margin alert, daily digest, flash sale auto-suggest, best time to sell. Implementasi: `utils/ai_engine.dart`.

## Design System v2 - "Centennial Modern Ocean White" (WAJIB)
Menggantikan dark Glassmorphism. Referensi layout: kasirmurah.com. Palet: bg #F8FAFC, surface #FFFFFF + border #E2E8F0, primary #0284C7, gradient #06B6D4 -> #0284C7, teks #0F172A / #64748B, sukses #10B981, warning #F59E0B, error #EF4444, badge AI #06B6D4 -> #4F46E5. Font Inter. Radius 16/12, shadow halus. Touch target 56dp/48dp.
Responsif: Mobile 360-599, Tablet 600-859, Desktop >=860. Desktop: sidebar tetap 240dp + header 60dp + konten maxWidth 1100 (form maxWidth 760) + bottom nav null. Mobile: app bar glass + drawer + bottom nav frosted glass.
Katalog/POS: grid 4 kolom, `childAspectRatio 0.95`, thumbnail 1:1, badge stok (Hijau>10, Kuning1-10, Merah0).
Satu sumber token: `config/app_theme.dart` + `tailwind.config.js` admin. DILARANG hardcode warna/font di screen.
Spesifikasi lengkap + Phase 7.6 (retrofit semua role) di `docs/KASIRGO-WORKFLOW-LENGKAP.md` Bagian 1.6 & 7C. UI-only: dilarang ubah fitur/logic/provider/schema.

## Offline-First
SQLite (drift) lokal untuk produk & transaksi. Sync ke Supabase setiap 30 detik saat online. Conflict: last-write-wins.

## Kebijakan Foto & Penyimpanan (WAJIB)
- **Foto produk = LOKAL saja** (path di HP). Tidak pernah upload ke Supabase Storage.
- **Database = teks & angka saja** (nama, harga, stok, kategori, `image_local_path`).
- **Thumbnail online = opt-in** ke Cloudflare R2 (WebP, maks 512px, ~15-30KB) hanya untuk produk yang dipublikasikan ke toko online / QR menu. `thumb_key` null jika tidak dipublikasikan.
- **R2, bukan Supabase Storage** untuk file (R2: 10GB gratis + egress Rp0).
- Transaksi: HOT (SQLite, semua) -> WARM (Supabase, 30 hari + agregat harian) -> COLD (R2 arsip).
- Backup penuh opsional ke Google Drive milik warung (biaya user, bukan developer).
- Skema: `image_url` (Supabase) DIGANTI menjadi `image_local_path` + `thumb_key`.

## File Structure
```
kasirgo/lib/
  main.dart, app.dart
  config/ (supabase_config, app_theme, constants)
  models/ (product.dart dll)
  services/ (supabase_service, sync_service, local_db_service, auth_service)
  screens/auth/ (login, register)
  screens/owner/ (owner_home, product_list, product_form, pos, report, customer_list, employee, settings, social_commerce, health_score, whatsapp_broadcast, qr_table, online_catalog)
  screens/admin/ (admin_home)
  screens/cashier/ (cashier_home)
  screens/customer/ (customer_menu)
  widgets/pos/ (cart_panel, checkout_dialog)
  utils/ (ai_engine, wa_helper)

kasirgo-admin/src/
  pages/ (Login, Dashboard, Users, UserDetail, Affiliates, Backup, Revenue)
  components/ (Layout)
```

## Dependencies (pubspec.yaml)
supabase_flutter, drift, sqlite3_flutter_libs, path_provider, go_router, flutter_riverpod, shared_preferences, intl, mobile_scanner, qr_flutter, barcode, pdf, printing, excel, url_launcher, connectivity_plus, google_fonts, flutter_animate, flutter_slidable, fl_chart, cached_network_image, image_picker

## Development Workflow
- **Testing cepat (MonkeyCode):** `flutter run -d web-server --web-renderer html --web-hostname 0.0.0.0 --web-port 8080`
  Gunakan HTML renderer (bukan CanvasKit) supaya preview langsung muncul, tidak blank.
- **Testing APK:** `flutter build apk --debug` untuk test cepat di HP.
- **APK rilis:** `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info`
  Target: per ABI di bawah 10MB. Gunakan `--split-per-abi` (3 APK: arm64, armeabi, x86_64).
- **Web build:** `flutter build web --release --base-href /kasirgo/` (WAJIB --base-href agar
  gh-pages tidak blank; source web/index.html memakai placeholder $FLUTTER_BASE_HREF).
  Deploy: salin build/web ke worktree gh-pages (assets, canvaskit, icons, *.* termasuk
  index.html yang sudah ber-base /kasirgo/).
- **Ukuran APK ditekan:** hapus package tidak perlu, gambar WebP bukan PNG, font subset Inter, `proguard-rules.pro`, tree-shaking Dart otomatis.

## Repository & Env
- GITHUB_URL: repo aktif = https://github.com/ikhlassabar2021-create/kasirgo.git
- Remote origin sudah dikonfigurasi. Branch utama: main (bukan master). Branch deploy: gh-pages.
- STATUS PUSH: SUDAH TER-PUSH (main + gh-pages sinkron).
- App: https://ikhlassabar2021-create.github.io/kasirgo/ (base /kasirgo/, hash URL).
- Superadmin React: https://ikhlassabar2021-create.github.io/kasirgo/admin/ (auth Supabase nyata).
  Akun: superadmin@kasirgo.com / sabar2021 (app_metadata.role=superadmin + baris admin_users).
- SUPABASE: project id lmvjecdvfzsmrowwwpck; URL & anon key terisi di
  kasirgo/lib/config/supabase_config.dart dan kasirgo-admin/src/config/supabase.ts.
  service_role TIDAK disimpan di repo/APK.
- Deployment: Flutter web -> gh-pages root; React admin -> gh-pages /admin/ (BUKAN Vercel).
  Flutter APK release via flutter build apk --release.

## Dokumen Referensi
- **Prompt siap-tempel tiap sub-task (BARU): docs/PROMPT-GILIRAN.md** -> pakai ini untuk memulai task baru.
- Workflow lengkap (sumber kebenaran): docs/KASIRGO-WORKFLOW-LENGKAP.md
- Design spec lama (USANG, digantikan Design System v2 Bagian 1.6): docs/superpowers/specs/2026-09-08-pos-app-design.md
- PRD lama (USANG): docs/PRD-KasirGo.md

## Handoff Phase 1 (TERVERIFIKASI)
Status: SELESAI. Project Supabase sudah dibuat dan schema terpasang serta diuji.

- Schema: 13 tabel, 16 RLS policy (di 11 tabel; `affiliates` + `affiliate_referrals` RLS aktif tanpa policy = by design, superadmin via service key), 2 trigger (`handle_new_user`, `decrement_stock`), 2 function, 9 index.
- Verifikasi fungsional:
  - `handle_new_user` PASS -- insert user -> outlet auto-create, `business_name` + `business_type` dari `user_metadata` terbaca.
  - `decrement_stock` PASS -- stok 10 -> 7 setelah insert transaction item quantity 3.
  - Login API PASS* -- user hasil direct-SQL tidak punya `auth.identities`, jadi password grant gagal. Full test via `signUp()` SDK di Phase 2.
- Data test sudah dibersihkan (user `test-phase1@kasirgo.test` + product `__TEST_DECREMENT__` = 0).
- Kredensial: `SUPABASE_URL` + anon key diisi manual di `config/supabase_config.dart` (Phase 2). `service_role` TIDAK disimpan di repo/APK.
- Sisa: full auth flow diuji di Phase 2.

## Progress Tracker (selaras roadmap Phase 3.0 - lihat workflow Bagian 4)
- [x] Phase 1: Supabase DB + Auth
- [x] Phase 2: Flutter App Shell + Auth + Offline Engine
- [x] Phase 3: Produk + POS + QRIS manual + AI Co-Pilot
- [x] Phase 4: Laporan + Pelanggan + Karyawan
- [x] Phase 5 / 5.5A / 5.5B / 5.5C: Retrofit 3.0 (DB, UI, Security)
- [x] Phase 6: Kasbon/Piutang + WA + Sponsored Receipt
- [x] Phase 7: Dynamic QRIS Payment Gateway + webhook HMAC
- [x] Phase 7.5: Zero-Friction Onboarding + Dual-Mode QRIS + Settlement + Superowner Financial Config
- [x] Phase 7.6: UI Retrofit "Centennial Modern Ocean White" (semua role + semua fitur, UI-only)
- [x] Phase 7.7: Control Plane + KYC Auto-Verify + Izin Produk/Staf + Owner Affiliate
- [x] Phase 7.8: Monetisasi & Program Pendukung (1 harga Rp50k/bln) + Iklan Pelanggan + Laporan ke Bos + KYC Wajib + Panduan + Skala Superadmin  (SELESAI)
- [x] Phase 8: Modul outlet_type (BOM/Resep, KDS/QR Meja, Variant, Shift/Tip)  (SELESAI)
- [x] Phase 9: PPOB + Closed-loop + Embedded B2B Restock  (SELESAI)
- [x] Phase 10: Fintech Lead + Hyperlocal Data + Micro-insurance  (SELESAI)
- [x] Phase 11: Superadmin Web (12 revenue engine, RBAC, rules engine, monitoring)  (SELESAI)
- [x] Phase 12: Polish + Security Audit + Release
  (ST12-1: tutup bocor secret_config, strip api_key, RLS kitchen, INTERNET
  permission, R8 minify -- migrasi 2026-10-02-kasirgo-12-security.sql;
  ST12-2: wiring offline end-to-end + fix data-loss resolver + lock antrean +
  dead-letter + katalog offline -- 10 test pass;
  ST12-3: web+admin deploy gh-pages, CI APK release-apk.yml, panduan
  docs/RELEASE.md. Detail: PROGRESS-PHASE12.md)
- [x] Phase 13: Superadmin Web + Control Plane
  (ST13-1: halaman Laporan Utama /Outlet Terdaftar/Fitur Utama + migrasi
  2026-10-03-kasirgo-13-admin.sql;
  ST13-2: Control Plane Iklan (banner lokal) + Payment Gateway + PPOB +
  B2B Kulakan + Modal Usaha + migrasi
  2026-10-04-kasirgo-13-control-plane.sql. Detail: PROGRESS-PHASE13.md)
- [x] Phase 13C: QR Meja food-only + Laporan kasir + backup bulanan + hapus UI
  asuransi + pendaftaran afiliasi mandiri. Migrasi
  `2026-10-06-kasirgo-13c-fixes.sql`.
- [x] Payment Gateway RCB (Raga Cipta Bersama)
  (tabel `payment_orders` + RLS + RPC `get_pg_client_config`/`confirm_pg_order`,
   `create_supporter_checkout` return `supporter_id`; PaymentService RCB
   sandbox-direct + fallback Edge Function; QRIS dinamis di POS
   (`checkout_dialog`) & Program Pendukung (`supporter_screen`) dengan polling
    status otomatis; Control Plane field provider/mode/base_url/callback;
    Edge Functions `rcb_create_charge`, `rcb_webhook` (SHA256), `rcb_check_status`.
    Migrasi `2026-10-07-kasirgo-rcb-pg.sql` + `-2.sql`. SUDAH deploy web+admin.
    CATATAN: mode `sandbox_direct` menaruh API key sandbox di klien =
    HANYA untuk tes; wajib pindah ke Edge Function (mode `live_server`) sebelum
    produksi. Edge Functions RCB SUDAH ter-deploy (rcb_create_charge /
    rcb_check_status verify_jwt=true, rcb_webhook verify_jwt=false).)
- [x] Payment Gateway RCB - Provider-aware + zero-custody (SELESAI, sesi 2026-10-08)
  (Aplikasi kini memilih provider otomatis dari RPC `get_pg_client_config`
   (cache prefs): `RcbProvider` (default) atau `MidtransProvider`, dibaca dari
   `platform_integrations.payment_gateway.provider`. Superadmin dapat mengganti
   provider (RCB/Midtrans) dan mode (sandbox/production) via Control Plane tab
   Payment Gateway TANPA ubah kode. Semua charge/poll RCB lewat Edge Function
   (zero-custody; `api_key` TIDAK lagi dikembalikan `get_pg_client_config`).
   FIX EF `rcb_create_charge`: `expired_time` epoch (int) dikonversi ke ISO ->
   kolom `expired_at` timestamptz (sebelumnya insert gagal senyap -> webhook
   "Order tidak ditemukan"); ditambah cek error insert. Migrasi
   `2026-10-08-kasirgo-rcb-provider-normalize.sql` (config -> provider rcb +
   mode sandbox_server). E2E LULUS: create_supporter_checkout -> rcb_create_charge
   (subscription) -> webhook SHA256 PAID -> `supporters` active +30 hari;
   `confirm_pg_order` (polling fallback) OK. Default = RCB sandbox.)
- [x] Phase 13A: Payment Gateway Midtrans (QRIS dinamis, zero-custody)
  (tabel `outlet_pg_configs` server key di Supabase Vault (`server_key_secret_id`
  uuid, bukan teks; column-grant: authenticated tak bisa baca); RPC
  `get_outlet_payment_config` ter-mask; RPC `vault_put_secret`/`vault_read_secret`
  (service_role); `transactions.provider_ref`/`paid_at`; `payment_orders.provider_order_id`.
  4 EF ter-deploy: `save_payment_config`, `test_payment_connection`,
  `create_payment` (Midtrans Core API `/v2/charge` qris), `midtrans_webhook`
  (SHA512, verify_jwt=false). Migrasi `2026-10-12-kasirgo-13a-midtrans-schema.sql`
  + `-2.sql`. E2E: webhook -> PAID + idempotent + tandai transaksi paid LULUS.
  BLOCKER EKSTERNAL: channel QRIS akun Midtrans production belum aktif
  (`402 Payment channel is not activated`) -> charge nyata belum hasilkan qr_string.
  App belum di-retrofit (payment_service.dart masih RCB) -> Phase 13B.)
- [x] Phase 13B: Retrofit app ke Midtrans (zero-custody)
  (payment_service.dart ditulis ulang: lapisan `PgProviderClient` + `MidtransProvider`;
  `createQris` -> EF `create_payment`, `checkStatus` baca `payment_orders` (di-update
  webhook), `confirmPaid` no-op; `PgPaymentOrder.rcbOrderId` -> `providerOrderId`.
  `getFinancialConfig` async dari RPC `get_financial_config` + cache SharedPreferences;
  checkout QRIS baca `_finCfg` (min/max/free). Wizard "Hubungkan Midtrans"
  (`screens/owner/midtrans_connect_screen.dart`): status koneksi, panduan + deep link
  Access Keys, form Merchant ID/Client Key/Server Key (mask), toggle Produksi/Sandbox,
  Tes Koneksi via EF `test_payment_connection` + `save_payment_config`. Server Key
  hanya dikirim ke server (Vault) = zero-custody. Gating QRIS dinamis via
  `hasFeature('payment_gateway')`; QRIS statis tetap gratis. Commit: ST13B-1 `3b6765a`,
  ST13B-3 `6cddb0a`. BLOCKER sama: channel QRIS production belum aktif.)
- [x] Phase 13C: Superadmin kelola Payment Gateway + uji sandbox + go-live + audit
  (ST13C-1 SELESAI: migrasi `2026-10-13-kasirgo-13c-superadmin-pg.sql` ->
  RPC `admin_list_outlet_pg_configs` (daftar outlet + status PG ter-mask, cek
  `is_platform_admin`, tanpa server key) + `admin_set_outlet_pg_status(outlet,status)`
  (verified|disabled|pending, tulis `log_admin_action`). Tab "Payment Gateway"
  superadmin (`ControlPlane.tsx` `FinancialTab`) kini punya tabel "Status Payment
  Gateway per Outlet" (badge Aktif/Nonaktif/Menunggu/Belum diatur, mode Produksi/
  Sandbox, hasil tes terakhir, tombol Tes + Aktifkan/Nonaktifkan). Helper
  `controlPlane.ts` `listOutletPgConfigs`/`setOutletPgStatus` + type `OutletPgConfig`.
  EF `test_payment_connection` izinkan superadmin (selain owner). EF `create_payment`
  tolak `status='disabled'`. Verifikasi REST: superadmin list 7 outlet, toggle
  verified<->disabled + audit tercatat, non-admin 403; EF superadmin valid + non-owner
  403; create_payment saat disabled diblok. Deploy EF 2 fungsi.
  ST13C-2 SELESAI: E2E sandbox outlet **Warung Test** (kredensial sandbox via
  `save_payment_config`, Server Key -> Vault) lulus semua: tes koneksi `valid:true`;
  charge QRIS dinamis -> `qris_string` + `qris_url` PNG; webhook `settlement` -> PAID,
  ulang -> `idempotent:true`; signature salah -> 401; alur POS penuh transaksi
  `unpaid` -> charge (dengan `transaction_id`) -> webhook -> `payment_orders=PAID` +
  `transactions.payment_status='paid'` + `paid_at` + `provider_ref`.
  ST13C-3 SELESAI: audit keamanan bersih (tidak ada kunci di repo/history/bundle;
  hanya anon key; RLS/grant/Vault benar; webhook signature+idempotent benar);
  REMEDIASI `create_payment` (validasi transaction_id: milik outlet 403, belum
  dibayar 409, nominal = final_amount 400) ter-deploy + regression E2E lulus;
  dokumen `docs/GO-LIVE-PAYMENT-GATEWAY.md` (checklist go-live, rotate key,
  alternatif provider QRIS PJP: Xendit/iPaymu/Tripay; QRIS statis tidak bisa
  otomatis -> fallback manual). **PHASE 13 TUNTAS.**)
- [x] Edge Functions create_staff + onboard_merchant DIDELOY + Fix WA Katalog
  (create_staff & onboard_merchant deployed via SUPABASE_ACCESS_TOKEN; smoke
   test create_staff OK: user langsung confirmed + user_roles dibuat fungsi.
   report_scheduler/stock_alert belum dideploy: butuh pg_cron + RESEND_API_KEY,
   dipakai cron (client punya jadwal sendiri).
   Migrasi `2026-10-09-kasirgo-wa-fallback.sql`: RPC `get_public_outlet_wa`
   kini fallback outlet_kyc.phone -> outlets.phone. Akibatnya tombol "Pesan WA"
   di katalog pelanggan langsung jalan (nomor KYC owner terpakai) tanpa setting
   manual. Verifikasi anon REST OK: Toko Test -> 085778074355.)
- [x] Alur Bayar Dine-in + Katalog/Meja DB + Pembersihan Fitur
  (PELANGGAN (QR meja & katalog web): pilihan bayar HANYA QRIS/Tunai,
  tombol "Kirim Pesanan" -> transaksi payment_status='unpaid' -> kasir
  "Pesanan Masuk" (chip Menunggu Bayar + tombol KONFIRMASI BAYAR via RPC
  `confirm_dinein_payment`) -> BARU lanjut ke KDS (filter paid). Transfer bank
  dihapus di sisi pelanggan (POS kasir tetap ada). Migrasi
  `2026-10-09-kasirgo-payment-flow-catalog.sql`: kolom transactions.payment_status,
  products.is_published, tabel outlet_tables + RLS, RPC confirm_dinein_payment /
  get_public_catalog, place_dine_in_order rewrite (cash/qris + unpaid).
  HAPUS FITUR: split bill (UI checkout; struct SplitPayment dipertahankan),
  varian (form/daftar/POS/module_registry; kolom has_variants dipertahankan),
  Buku Kasbon (unwire home), PDF laporan (Excel tetap), transfer bank pelanggan.
  FIX: PPOB payment method reset saat ketik (notifier di-hoist+dispose);
  B2B guard config belum siap (dialog, bukan WebView kosong).
  PERSIST DB: katalog toggle -> products.is_published (RPC get_public_catalog
  utk anon); QR Meja -> tabel outlet_tables (CRUD owner, tidak lagi hardcoded).
  Iklan sponsor juga di katalog pelanggan (SponsorAdSlot).
  E2E terverifikasi via REST+psql: unpaid -> confirm owner -> paid; anon
  get_public_catalog hanya produk is_published; outlet_tables insert/delete OK.
  Deploy web gh-pages e40a4f7; main 06004a2.)
- [x] Phase 14: Dokter Bisnis AI (SELESAI)
  (7 tabel doctor + RLS + view ter-mask + seed `platform_configs.business_doctor`,
  migrasi `2026-10-06-kasirgo-14-dokter-bisnis.sql`; EF `business_doctor_chat`
  (tools snapshot/trend/stok/kasflow/aksi/memori/resep/escalate + web `fetch_url`)
  dengan fase A/B/C, ESCALATION LADDER, gating Program Pendukung; app owner chat +
  intake wizard + peta resep + catat promosi/ROI + Riwayat Kasus; Control Plane tab
  Dokter Bisnis AI + override provider per outlet + rate limit/kuota harian.
  ST14-1..ST14-10. Detail: sesi "Phase 14 Dokter Bisnis AI".)
- [x] Phase 15: Master Prompt Karakter & Skill + 12 Fitur Bos Virtual
  (15A ST15-1 Master Prompt + Daftar Skill SELESAI; 15B ST15-2 Bos Virtual Analitik SELESAI;
  15C ST15-3 Bos Virtual Growth SELESAI; 15D ST15-4 Addendum L-O + Hardening SELESAI.
  PHASE 15 SELESAI. Detail: `PROGRESS-PHASE15.md`.)
- [x] Phase 16: Squad Digital Marketing AI (Team Desain + Promosi + Iklan)
  (ST16-1 fondasi (7 tabel dm_* + RPC admin + EF `dm_creative` + tab superadmin);
  ST16-2 Studio Desain (copy/gambar/video); ST16-3 Studio Promosi (kalender + posting);
  ST16-4 Studio Iklan (campaign draft Meta/Google/TikTok/Shopee -> approval owner ->
  ROAS/CTR/CPC + pause otomatis ROAS<target + audit_logs + rekomendasi ke Dokter Bisnis)
  + HARDENING: `platform_configs` client SELECT tidak lagi memaparkan kredensial LLM
  (`business_doctor`/`digital_marketing_llm`) - hanya service_role + superadmin.
  Migrasi `docs/migrations/2026-10-27-kasirgo-16d-ads.sql`. PHASE 16 SELESAI.
  Detail: `PROGRESS-PHASE16.md`.)
- [x] Phase 17: Ekosistem Hyper-Local
  (ST17-1 fondasi (PostGIS, orders, app_customers, outlet_locations, service_queue,
  RPC nearby_outlets/submit_order/validate_order_payment/complete_order, RLS, Realtime) -
  migrasi `2026-10-31-kasirgo-17a-hyperlocal.sql`; ST17-2 pesanan online masuk (akses
  owner+kasir/admin via `is_outlet_member`, realtime, notifikasi) - `2026-11-01-kasirgo-17b`; 
  ST17-3 laporan omzet produk vs titipan ongkir; ST17-4 mode ganda Penjual/Pembeli +
  anonymous auth + consent UU PDP; ST17-5 app Pembeli radar `nearby_outlets` + katalog
  publik + keranjang (1 toko/transaksi) + iklan sisi pelanggan; ST17-6 checkout + tracking
  realtime + bukti transfer LOKAL; ST17-7 gerobak live tracking + antrean jasa + hardening
  (rate limit order trigger, RPC take_queue_number, nearby_outlets +service_queue_enabled) -
  `2026-11-02-kasirgo-17c-hardening.sql`. PHASE 17 SELESAI. Detail: `PROGRESS-PHASE17.md`.)

Catatan: Phase 7.6 adalah redesign visual menyeluruh (semua dashboard + fitur Produk/Pelanggan/
Karyawan/Laporan/Pengaturan) tanpa mengubah fitur/logic. Spec: workflow Bagian 1.6 & 7C.
Phase 7.7 = Control Plane: semua setting integrasi/margin lewat superadmin tanpa ubah koding. Spec: Bagian 1.10 & 7D.
KYC owner wajib (email/nohp/nama toko/alamat/KTP/selfie) + auto-verify. Spec: Bagian 7D (ST7.7-2).
Phase 7.8 = Monetisasi: Program Pendukung SATU harga Rp50.000/bulan, iklan HANYA di sisi pelanggan (web,
tidak di APK, tanpa iklan tersembunyi), laporan ke bos, KYC wajib, panduan in-app, skala Superadmin. Spec: workflow Bagian 4 + Phase 7.8.
STATUS PHASE 7.8: SELESAI. Control Plane superadmin (10 tab) live di /kasirgo/admin/. Superadmin nyata:
superadmin@kasirgo.com / sabar2021. Migrasi KYC + control-plane-admin + platform-integrations sudah dijalankan.
Phase 8 = Modul per outlet_type: module_registry (override feature_flags `module_<nama>`), product_variants
+ trigger stok varian (stock_logs), recipes/BOM (HPP bahan, deduksi stok bahan saat penjualan),
KDS dine-in (realtime, filter hari ini), shifts/tips/transaction_payments (shift kasir, split bill).
Migrasi: docs/migrations/2026-10-01-kasirgo-8.sql. Detail: PROGRESS-PHASE8.md.

## Sesi 2026-10-03: Role Koki + Status Pesanan + Multi-Outlet + Struk Logo (SELESAI)
- ROLE KOKI (outlet_type cafe/warteg): dropdown Karyawan ada "Koki (KDS Dapur Saja)";
  create_staff EF izinkan 'kitchen' (SUDAH redeploy + teruji); migrasi
  `2026-10-09-kasirgo-koki-status.sql`: handle_new_user whitelist kitchen,
  set_order_status izinkan kitchen, user_roles_role_check + kitchen (constraint
  live dulu HANYA admin/cashier/owner = penyebab gagal create koki).
  Koki login -> langsung KDS (screens/kitchen/kitchen_shell.dart, route /kitchen);
  admin juga punya tab Dapur. Akun test: ikhlassabar2021+kokitest@gmail.com / sabar2021.
- STATUS PESANAN REALTIME PELANGGAN: polling RPC `get_public_order_status`
  (anon, by outlet+table, order terbaru hari ini) di customer_order_screen ->
  banner: unpaid="Silakan Bayar di Kasir", diproses="Pesanan Sedang Diproses".
  E2E REST lulus: place_dine_in_order(unpaid) -> confirm_dinein_payment(owner)
  -> set_order_status(koki diproses) -> status paid+diproses.
- PDF LAPORAN KEMBALI: report_screen tombol PDF + PDFExporter (revert ST13-1).
- MULTI-OUTLET PENDUKUNG: settings toggle + owner/multi_outlet_screen.dart +
  SupporterService.getManagedOutlets (transaksi via outlets.owner_id = uid).
- STRUK CUSTOM LOGO: settings pilih gambar (LOKAL, base64 prefs) + tombol
  Struk PDF di POS sukses (utils/receipt_generator.dart).
- GATE QRIS DINAMIS: checkout QRIS butuh Program Pendukung; QRIS statis/statis
  PNG tetap gratis. Manfaat baru: Laporan ke Bos + Bebas Iklan Pelanggan
  (SponsorAdSlot skip jika outlet aktif supporter aktif).
- Deploy: main 023a7f8, gh-pages 7f0d426 (terverifikasi live).

## Sesi 2026-10-03 (2): Bugfix Laporan Uji Owner (SELESAI)
- MULTI-OUTLET GAGAL TAMBAH: root cause select menyertakan kolom `outlet_type`
  yang TIDAK ADA di tabel outlets (hanya `type`) -> listOwnerOutlets &
  addOwnerOutlet selalu error. Fixed (hapus outlet_type dari select).
- IKLAN TAK PERNAH MUNCUL: sponsor_ad_slot cek `!d.showAds` SEBELUM
  `needsConsent` -> kartu consent UU PDP tak pernah tampil. Fixed (urutan cek).
- LAPORAN embedded (owner home): tombol PDF/Share/Excel kini tampil di mode
  embedded (sebelumnya hanya di mode standalone). Daftar transaksi kini
  menampilkan nama produk + jumlah (sebelumnya hanya kode #id).
- GATE QRIS DINAMIS: snackbar diganti dialog Pendukung (showSupporterLockedDialog).
- SETTINGS Pendukung: daftar manfaat kini = premiumFeatures (17 fitur, sama
  dengan dashboard; termasuk Laporan Otomatis ke Bos, QRIS Dinamis, Bebas Iklan).
- QR MEJA: error tambah meja jelas (addOutletTableDetailed) + fix _isAdding
  stuck. Verifikasi REST: insert outlet_tables 201, delete 204 (RLS owner OK).
- KARYAWAN: backend create_staff terverifikasi OK (admin + kitchen dibuat sukses
  via EF). UI: error handling diperkuat. Kemungkinan gagal sebelumnya = constraint
  user_roles_role_check (sudah difix sesi sebelumnya) atau build lama/cache.
- TOMBOL STRUK POS: durasi snackbar 12 detik (mudah terlewat sebelumnya).
- CATATAN PENTING: Toko Test & Warung Test masih TRIAL aktif (s.d. 14 Okt) ->
  semua fitur premium TERBUKA, gate Pendukung tidak muncul untuk akun ini.
  Test gate pakai outlet tanpa trial (mis. akun baru / trial lewat).
- Deploy: main 8c1a947, gh-pages 3994701.

## Sesi 2026-10-03 (3): AKAR MASALAH Karyawan + Iklan Tolak + Test Regresi Live (SELESAI)
- KARYAWAN ROOT CAUSE SEBENARNYA (RLS visibility): policy SELECT user_roles
  hanya `user_id = auth.uid()` -> owner TIDAK bisa membaca baris role staf
  outletnya: getEmployees selalu [] (daftar kosong), createEmployee upsert
  selalu 42501 (jalur UPDATE butuh USING = visibility), updateEmployeeRole
  gagal diam-diam. FIX migrasi `docs/migrations/2026-10-03-kasirgo-staff-visibility.sql`:
  - Fungsi `is_outlet_owner(uuid)` SECURITY DEFINER (bypass RLS).
  - Policy SELECT baru: user_id = auth.uid() OR is_outlet_owner(outlet_id).
  - WAJIB SECURITY DEFINER: policy SELECT outlets "Admin/Cashier can view own
    outlet" merujuk user_roles -> subquery outlets langsung di policy
    user_roles = infinite recursion 42P17 (sudah dialami + diperbaiki).
  Verifikasi REST: owner SELECT user_roles 200 (7 baris), upsert
  merge-duplicates 200. getEmployees/createEmployee/updateEmployeeRole kini jalan.
- IKLAN TOMBOL "TOLAK": setelah decline, decide(consentGiven:false) selalu
  needsConsent=true -> kartu consent muncul terus (tombol terlihat mati).
  FIX AdService.decide(): baca consent tersimpan; 'declined' -> decision
  kosong (slot hilang, TANPA prompt ulang); null -> needsConsent; accepted ->
  lanjut tampil iklan. Tambah AdService.clearConsent().
- TEST REGRESI LIVE BARU: test/live_owner_regression_test.dart (5 skenario,
  SEMUA LULUS): (1) createStaffAccount EF + createEmployee -> OK,
  (2) QR Meja read/add/delete OK, (3) akun tanpa-trial hasAccess=false,
  (4) decide tanpa consent -> needsConsent, (5) setelah Tolak -> slot hilang
  permanen. Pola: JANGAN TestWidgetsFlutterBinding (blokir network);
  SharedPreferences.setMockInitialValues({}) cukup; SupabaseClient langsung.
- AuthService & SupabaseService: constructor terima `client` opsional
  (injectable utk test, default tetap Supabase.instance.client).
- ai_pro/advanced_report/backup_cloud: TIDAK ada UI entry point (hanya copy
  di daftar manfaat) -> tidak digate, sengaja.
- CATATAN: file migrasi milik ROOT `docs/migrations/` (gitignore: *.sql hanya
  un-ignore di docs/migrations/ root, BUKAN kasirgo/docs/migrations/).
- Deploy: main 928fcbe, gh-pages 79ab697 (flutter_bootstrap.js live identik
  dgn build lokal). QR Meja: backend memang benar sejak awal -> bila user
  masih gagal = cache service worker, minta hard refresh.

## Sesi 2026-10-03 (4): Nama Karyawan + Password Virna (SELESAI)
- NAMA KARYAWAN TIDAK TAMPIL: user_roles tidak punya kolom nama -> UI hanya
  'Staf (ROLE)'. FIX migrasi `docs/migrations/2026-10-03-kasirgo-staff-display-name.sql`:
  kolom `display_name` + backfill dari metadata auth.users (staff_name dari
  EF create_staff; name/full_name dari signup owner) -> 19 baris terisi.
- Wiring: EF create_staff upsert sertakan display_name (PENDING redeploy,
  SUPABASE_ACCESS_TOKEN tidak tersedia di sesi ini - app sudah menulis
  display_name sendiri via upsert RLS-fixed jadi tidak memblokir);
  _ensureStaffRole param name -> display_name (upsert + insert fallback);
  createEmployee simpan display_name; getEmployees/getEmployee baca
  display_name (fallback 'Staf (ROLE)').
- LOGIN STAF GAGAL (virna@gmail.com): akun confirmed + hash bcrypt ada ->
  password-nya BUKAN sabar2021 (owner mengetik password lain saat buat
  akun). FIX: reset via psql `crypt('sabar2021', gen_salt('bf'))` ->
  login REST OK. Pelajaran: kalau owner lupa password staf, reset via psql.
- QR MEJA "tambah meja belum ada": UI add form SELALU ada di kode saat ini;
  Toko Test type=Cafe (bukan gate). Diagnosis: perangkat masih build lama
  (sebelum Phase 13C, tabel hardcoded tanpa UI tambah) -> hard refresh.
- Deploy: main 23b4d00, gh-pages f92b32b (live terverifikasi via hash).

## Sesi 2026-10-03 (5): Root Cause CRASH QR Meja + Hero Tag (SELESAI)
- QR MEJA CRASH (bukan cuma "form tak muncul"): dibuktikan via Playwright
  headless + semantics tree -> `QrTableScreen` gagal render dengan
  `BoxConstraints forces an infinite width`. PENYEBAB: theme tombol global
  `AppTheme.lightTheme.elevatedButtonTheme` memakai
  `minimumSize: const Size(double.infinity, 44)` (`config/app_theme.dart`
  ~106). `ElevatedButton.icon` "Tambah" di dalam `Row` (`qr_table_screen.dart`
  ~317) mewarisi lebar infinite -> `RenderConstrainedBox`/`RenderPhysicalShape`
  gagal layout -> layar tak tampil.
  FIX (di level tombol, TIDAK ubah theme global agar tombol lain aman):
  tambah `minimumSize: const Size(0, AppTheme.touchTargetLarge)` +
  `padding: EdgeInsets.symmetric(horizontal: 16)`.
- ERROR "multiple heroes share the same tag": dashboard owner memakai satu
  `IndexedStack` berisi `ProductListScreen(embedded)` + `ReportScreen(embedded)`,
  keduanya `FloatingActionButton.extended` default hero tag sama. FIX: heroTag
  unik di FAB ProductList/Report/Employee/Customer/MultiOutlet.
- `QrTableScreen` service injectable (`{this.service}`) untuk widget test.
- TEST BARU `test/qr_table_layout_test.dart` (fake AuthService, tanpa klien
  Supabase nyata): LULUS dgn fix, GAGAL tanpa fix (infinite width). Jalankan
  `/opt/flutter/bin/flutter test test/qr_table_layout_test.dart -r expanded`.
- VERIFIKASI LIVE release build via Playwright (login owner -> QR Meja ->
  tambah meja): layar render, "Daftar Meja (1)", `ERRORS after opening QR (0)`
  (hero error hilang). Data meja QA dibersihkan via REST DELETE (RLS owner).
- PELAJARAN: `flutter analyze` TIDAK menangkap bug layout runtime; perlu
  widget test / render nyata. `flutter build web` di Flutter 3.47 sudah tanpa
  `--web-renderer` (CanvasKit).
- Deploy: main 25ec5bb, gh-pages c130af4 (live md5 main.dart.js MATCH).

## Sesi 2026-10-03 (6): Assertion ListTile Sidebar + Bersih Data Uji (SELESAI)
- ASSERTION "ListTile background color or ink splashes may be invisible":
  ditemukan via Playwright debug (assert hanya aktif di debug; release build
  strip assert). Detail verbose diambil dengan menangkap console.log pertama
  (dumpErrorToConsole hanya verbose saat `_errorCount == 0`).
  AKAR: sidebar desktop owner (`owner_home_screen.dart` ~311) memakai
  `Container(decoration: BoxDecoration(color: Colors.white, border: right))`
  sebagai DecoratedBox berwarna, lalu `_buildDesktopNavItem` (~630) dan
  `_buildDesktopActionItem` (~610) menaruh `ListTile` langsung di dalamnya
  TANPA Material perantara -> `_debugCheckBackgroundIsHidden` (`list_tile.dart`
  ~1147) memicu `_findIntermediateWidget` menemukan DecoratedBox berwarna.
  FIX: bungkus kedua ListTile dengan `Material(type: MaterialType.transparency)`.
  VERIFIKASI Playwright debug: klik nav Dashboard/Produk/Kasir/Laporan =
  `ListTile assertions: 0`; layar Karyawan & Pengaturan juga 0.
- HTTP 422 `anonymous_provider_disabled` dari `signInAnonymously()`
  (`auth_service.dart` ~49) BUKAN bug: memang provider anon dimatikan di
  Supabase project; sudah di-catch. Tidak perlu tindakan.
- DATA UJI DIBERSIHKAN: 6 baris `user_roles` "Regresi Test" (sisa live test)
  dihapus via REST DELETE (204). `test/live_owner_regression_test.dart` kini
  membersihkan dirinya sendiri (delete user_roles by user_id / employee id
  setelah skenario tambah karyawan) agar tidak menumpuk tiap dijalankan.
- TEMUAN: `GET /rest/v1/outlet_staff_quota` -> 404 `PGRST205` (tabel tidak
  ada di DB live). Ditindaklanjuti di Sesi (7).
- Deploy: main 295a15d, gh-pages 0fd1f35 (live md5 main.dart.js MATCH
  eae0b83289debbeece0f8cdf5ec20497; smoke test live: login + nav 0 error).

## Sesi 2026-10-03 (7): Fix 404 outlet_staff_quota + Clamp Progress (SELESAI)
- ROOT CAUSE 404: tabel `outlet_staff_quota` (spesifikasi workflow Bagian 3
  ~617) tidak pernah dibuat di DB live, padahal `settings_screen.dart` ~107
  membacanya (kartu "Kuota Staff"); query di dalam try/catch -> gagal senyap.
- MIGRASI DIBUAT + DITERAPKAN ke DB live:
  `docs/migrations/2026-10-10-kasirgo-staff-quota.sql`.
  Isi: tabel spec (max_admin/max_cashier/extra_from_supporter) + kolom
  kompat-app (max_staff/current_staff_count) agar build ter-deploy langsung
  jalan; fungsi `refresh_staff_quota()` + trigger `trg_staff_quota_from_roles`
  (AFTER INSERT/UPDATE/DELETE user_roles, SECURITY DEFINER, dibungkus EXCEPTION
  agar tak memblokir signup); trigger `trg_staff_quota_before_write` (hitung
  max_staff + updated_at); backfill 7 outlet; RLS owner-read
  (`is_outlet_owner`) + superadmin-full. Idempoten (`IF NOT EXISTS`).
  Apply via psql session pooler
  `host=aws-0-ap-southeast-1.pooler.supabase.com port=5432
   user=postgres.lmvjecdvfzsmrowwwpck` (password DB dari owner) -> COMMIT OK,
  7 baris ter-backfill (mis. Toko Test 229c94d7... = current 7).
  Verifikasi REST owner: `outlet_staff_quota` 200 (bukan 404 lagi).
- BUG IKUTAN DIPERBAIKI: `_buildStaffQuotaCard` menghitung
  `percentage = current/max`; data asli (7 staff / max 2) -> `3.5` ->
  `LinearProgressIndicator` assert `value<=1` (di debug). FIX:
  `.clamp(0.0, 1.0)` + guard `max>0` (`settings_screen.dart` ~1529).
- CATATAN BELUM: `extra_from_supporter` masih default false (belum di-wire
  otomatis dari status `supporters`) -> outlet supporter dgn staf >2 tampil
  "PENUH/Upgrade Plan". Butuh keputusan jumlah slot ekstra (belum
  dispesifikasi). Gate tambah staf sendiri tetap client-side
  (`requireSupporterFeature('extra_staff')`).
- Deploy: main 06d9e2e, gh-pages 11d0efe (rebuild release dgn clamp fix).

## Sesi 2026-10-05: Auto-wire Slot Staf Pendukung = TAK TERBATAS (SELESAI)
- ROOT CAUSE: `outlet_staff_quota.extra_from_supporter` selalu default false
  -> outlet yang sedang trial/pendukung tetap dihitung max_staff = 2 -> kartu
  "Kuota Staff" tampil "PENUH/Upgrade Plan" padahal gate `extra_staff`
  (client, `entitlements.hasAccess`) SUDAH membuka fitur. Keputusan produk:
  selama Pendukung/trial aktif, slot staf = TAK TERBATAS.
- MIGRASI BARU + DITERAPKAN ke DB live:
  `docs/migrations/2026-10-11-kasirgo-staff-quota-supporter.sql`.
  `refresh_staff_quota()` kini menghitung ulang `extra_from_supporter`
  LANGSUNG dari tabel `supporters` (status active/trial, end_date > now())
  + `entitlements` (is_supporter / trial_ends_at > now()) -> otomatis
  REVOKE saat trial/langganan berakhir. `max_staff` = 999999 saat extra.
  Trigger baru `trg_staff_quota_from_supporter` pada `supporters` DAN
  `entitlements` agar kartu ikut ter-refresh saat status berubah.
  Apply via psql -> COMMIT OK. Verifikasi: Toko Test (trial s.d. 14 Okt)
  & Warung Test (trial s.d. 13 Okt) => extra=true, max_staff=999999;
  Gerobak Test (trial expired) => false, max_staff=2.
- APP (rebuild): `settings_screen.dart` baca `extra_from_supporter`;
  kartu Kuota Staff tampil "N staff aktif - Tanpa batas" + badge BEBAS
  (bukan PENUH) & tombol Upgrade disembunyikan bila Pendukung/trial aktif.
  `employee_screen.dart` `_handleAddEmployee`: kuota GRATIS 2 staf pertama
  (1 Admin + 1 Kasir) tidak lagi diblok gate; staf ke-3+ butuh Pendukung
  (via `requireSupporterFeature('extra_staff')`), dan saat Pendukung/trial
  aktif = TAK TERBATAS. Helper baru `SupabaseService.getStaffQuota()`.
- Verifikasi: `flutter analyze` 0 error (hanya info pre-existing);
  bundle `main.dart.js` memuat string "Tanpa batas" + "extra_from_supporter".
- Deploy: main 565c71a, gh-pages ade5ab0.

## Sesi 2026-10-05 (2): Phase 13A - QRIS Dinamis Midtrans (zero-custody) [SELESAI]
- Tujuan: QRIS dinamis otomatis LUNAS via webhook Midtrans; Server Key TIDAK PERNAH
  menyentuh APK/klien (zero-custody). Hanya di Edge Function + Supabase Vault.
- ST13A-1 `daac450` migrasi `2026-10-12-kasirgo-13a-midtrans-schema.sql` (DITERAPKAN):
  tabel `outlet_pg_configs` (server key = `server_key_secret_id` uuid Vault, bukan teks);
  RLS owner-read + column-grant (authenticated TIDAK bisa baca secret id, anon none);
  `transactions` + `provider_ref`/`paid_at`; RPC `get_outlet_payment_config` (ter-mask);
  `platform_integrations.payment_gateway` -> provider midtrans, `pg_duitku` dihapus.
- ST13A-2 `307e0d0`: migrasi `2026-10-12-kasirgo-13a-midtrans-2.sql` (DITERAPKAN) RPC
  `vault_put_secret`/`vault_read_secret` (SECURITY DEFINER, EXECUTE hanya service_role;
  roundtrip Vault terverifikasi) + `payment_orders.provider_order_id`; EF
  `save_payment_config` (JWT owner -> simpan server key ke Vault -> config ter-mask).
- ST13A-3 `129004d`: EF `test_payment_connection` (probe status dummy; 401 invalid,
  404/200 valid; update status verified/pending).
- ST13A-4 `d916ac0`: EF `create_payment` (Midtrans Core API `POST /v2/charge`
  `payment_type=qris`, Basic auth server key dari Vault; simpan payment_orders; return
  `qr_string` + `provider_ref`).
- ST13A-5 `a3ee31d`: EF `midtrans_webhook` (verify SHA512(order_id+status_code+
  gross_amount+ServerKey); map status -> PAID/PENDING/EXPIRED/FAILED/REFUND; idempotent;
  aktivasi langganan; tandai transaksi paid). WAJIB `verify_jwt=false`.
- Kredensial outlet Toko Test (`229c94d7-...`) DISIMPAN ke Vault via psql (server key
  terenkripsi; md5 terverifikasi). CATATAN: kunci yang diberikan user = **PRODUCTION**
  (sandbox 401, production auth valid) -> `is_production=true`. Jangan commit kunci.
- DEPLOY SELESAI (Personal Access Token `sbp_...`): Supabase CLI v2.119.0 terpasang;
  4 EF ter-deploy ke project lmvjecdvfzsmrowwwpck (`midtrans_webhook` `--no-verify-jwt`,
  sisanya verify_jwt=true). Verifikasi E2E via REST + EF:
  - `test_payment_connection` -> `{valid:true, http_status:200, is_production:true}`
    ("Kredensial valid").
  - `save_payment_config` (tanpa server_key) -> config ter-mask `has_server_key:true`,
    status `verified`; `server_key_secret_id` TIDAK pernah dikembalikan.
  - `midtrans_webhook`: signature salah -> 401 "Invalid signature"; signature benar
    (SHA512) -> PAID; panggil ulang -> `idempotent:true`. Menandai
    `transactions.payment_status='paid'` + `paid_at` + `provider_ref` (terverifikasi
    REST: transaksi uji jadi paid).
  - `create_payment`: verifikasi JWT anggota outlet + ambil server key dari Vault OK.
- BUG DITEMUKAN & DIPERBAIKI `0458dbd` (ST13A-4): Midtrans Core API membalas HTTP 200
  walau gagal (mis. `status_code:"402"` "Payment channel is not activated") -> EF lama
  mengembalikan qr_string kosong seolah sukses. Kini validasi `status_code` 2xx ->
  balas 502 + pesan asli. TER-DEPLOY + terverifikasi (kini balas 502 status_code 402).
- BLOCKER EKSTERNAL (bukan kode): akun Midtrans production Toko Test belum mengaktifkan
  channel QRIS (`402 Payment channel is not activated`) -> charge QRIS nyata belum bisa
  menghasilkan `qr_string`. Aksi user: aktifkan QRIS di dashboard Midtrans. Sisa alur
  (webhook -> PAID, idempotent, tandai transaksi) SUDAH terbukti lulus.
- Kredensial outlet Toko Test (`229c94d7-...`) tersimpan di Vault (server key terenkripsi;
  md5 terverifikasi). CATATAN: kunci yang diberikan user = **PRODUCTION**
  (sandbox 401, production auth valid) -> `is_production=true`. Jangan commit kunci.
  SARAN: rotate Server Key karena sudah melewati chat.
- Data uji (2 payment_orders + 1 transaksi `KGO-13A-*`) dibuat untuk verifikasi;
  belum dibersihkan (menunggu izin hapus).
- Docs workflow Bagian 8 (PHASE 13A) + AGENTS diperbarui. App belum di-retrofit ke
  Midtrans (payment_service.dart masih RCB) -> masuk Phase 13B.

## Sesi 2026-10-05 (3): Phase 13B - Retrofit App ke Midtrans (zero-custody) [SELESAI]
- Tujuan: app memakai Midtrans (QRIS dinamis otomatis LUNAS via webhook), Server Key
  tetap hanya di server/Vault. RCB ditinggalkan.
- ST13B-1 `3b6765a`: `payment_service.dart` ditulis ulang. Lapisan provider
  `PgProviderClient` + `MidtransProvider`; facade `PaymentService`.
  - `createQris` panggil EF `create_payment`; `checkStatus` baca tabel `payment_orders`
    via `.or(provider_order_id/external_id)`; `confirmPaid` no-op (webhook otoritatif).
  - `loadProviderConfig` (RPC `get_outlet_payment_config`, ter-mask);
    `getFinancialConfig` async RPC `get_financial_config` + cache prefs
    (`min_payment`/`max_payment`/`free_threshold`).
  - `PgPaymentOrder.rcbOrderId` -> `providerOrderId`; `fromApi` toleran
    (order_id/provider_order_id/qris_string/qr_code/qris_image_url).
  - `supporter_service.dart`/`supporter_screen.dart`/`checkout_dialog.dart` ikut
    di-update. Hapus cabang auto-pay "Pembayaran Gratis" (free_threshold = ambang
    biaya platform, bukan pembayaran gratis).
- ST13B-2 (dalam `3b6765a`): `checkout_dialog.dart` render QR asli dari `qr_string`
  (QrImageView), panel status menunggu + polling 5 dtk auto-update saat PAID/EXPIRED,
  baca batas nominal dari `_finCfg`.
- ST13B-3 `6cddb0a`: layar `MidtransConnectScreen` (wizard "Hubungkan Midtrans"):
  status koneksi, panduan 3 langkah + deep link Access Keys, form Merchant ID/Client
  Key/Server Key (obscure, tidak pernah ditampilkan kembali), toggle Produksi/Sandbox,
  Tes Koneksi (simpan + probe via EF `test_payment_connection`). `PaymentService`
  tambah `savePaymentConfig`/`testPaymentConnection`. Entry: Pengaturan >
  "Hubungkan Midtrans (QRIS Dinamis)".
- Gating: QRIS dinamis di checkout hanya bila `hasFeature('payment_gateway')`
  (Pendukung/trial), else dialog Pendukung; QRIS statis tetap gratis (fallback default).
- Verifikasi: `flutter analyze` 0 error (hanya info pre-existing); `flutter build web
  --release` SUKSES.
- BLOCKER EKSTERNAL (bukan kode): channel QRIS akun Midtrans production Toko Test
  belum aktif (`402`) -> charge nyata belum hasilkan `qr_string`. Alur webhook -> PAID
  sudah terbukti lulus di Phase 13A. Aksi user: aktifkan QRIS di dashboard Midtrans.
- CATATAN: Server Key yang diberikan user = PRODUCTION; disarankan rotate karena
  sudah melewati chat. Data uji 13A (`payment_orders` + transaksi `KGO-13A-*`) masih
  ada (menunggu izin hapus).

## Sesi 2026-10-05 (4): Phase 13C ST13C-1 - Superadmin kelola Payment Gateway [SELESAI]
- Tujuan: superadmin dapat melihat status Payment Gateway (Midtrans) tiap outlet dan
  mengaktifkan/menonaktifkannya dari Control Plane, tanpa pernah melihat Server Key.
- MIGRASI `docs/migrations/2026-10-13-kasirgo-13c-superadmin-pg.sql` (DITERAPKAN):
  - `admin_list_outlet_pg_configs()` -> JSONB daftar outlet + status PG ter-mask
    (provider, merchant_id, client_key, has_server_key, is_production, status,
    last_tested_at, last_test_result). Cek `is_platform_admin()`, `forbidden` bila bukan.
  - `admin_set_outlet_pg_status(p_outlet, p_status)` -> verified|disabled|pending,
    tulis jejak `log_admin_action('outlet_pg.set_status', ...)`.
  - Keduanya SECURITY DEFINER, `GRANT EXECUTE` authenticated. TIDAK mengembalikan
    `server_key_secret_id`.
- UI superadmin (`kasirgo-admin/src/pages/ControlPlane.tsx` tab "Payment Gateway"):
  tabel "Status Payment Gateway per Outlet" (badge Aktif/Nonaktif/Menunggu/Belum
  diatur, mode Produksi/Sandbox, hasil tes terakhir, tombol Tes + Aktifkan/
  Nonaktifkan). Helper baru di `src/lib/controlPlane.ts`: `listOutletPgConfigs`,
  `setOutletPgStatus`, type `OutletPgConfig`. Default provider/mode diubah ke
  midtrans/live_server + placeholder callback `midtrans_webhook`.
- EF `test_payment_connection` diperluas: selain owner, superadmin
  (`is_platform_admin`) boleh mengetes outlet mana pun. EF `create_payment` kini
  menolak `status='disabled'` (403) agar tombol Nonaktifkan superadmin efektif.
- Verifikasi REST (superadmin@kasirgo.com): list 7 outlet; toggle Toko Test
  verified -> disabled -> verified; 2 baris audit `outlet_pg.set_status` tercatat;
  owner non-admin -> `forbidden`. EF: superadmin probe Toko Test `valid:true
  HTTP 200`; non-owner/non-admin `Forbidden`; create_payment saat disabled ->
  `"Payment gateway outlet dinonaktifkan oleh admin."`.
- Deploy: EF `test_payment_connection` + `create_payment` (verify_jwt=true) via CLI;
  admin build `tsc -b && vite build` sukses; `dist` disalin ke gh-pages `/admin/`.
- Berikutnya: ST13C-2 (uji E2E sandbox) & ST13C-3 (go-live + audit keamanan).

## Sesi 2026-10-06: Phase 13C ST13C-2 - Uji E2E Sandbox Midtrans [SELESAI]
- Kredensial sandbox Midtrans (Merchant ID + client/server key `SB-Mid-*`) diberikan
  user via chat; disimpan ke outlet percontohan **Warung Test**
  (`5dda8727-2439-432a-91e6-308c824c4f7a`) via EF `save_payment_config` (JWT owner;
  Server Key langsung ke Vault; `is_production=false`; status awal `pending`).
- Hasil uji (semua LULUS):
  1. `test_payment_connection` -> `{valid:true, http_status:200}`; config -> `verified`.
  2. `create_payment` (Rp 11.008, `payment_type=qris`) -> `success:true, PENDING`,
     `qris_string` dinamis terbit, `qris_url` PNG (HTTP 200), `expired_at` terisi.
  3. Webhook `settlement` signature SHA512 valid -> `PAID`; ulang -> `idempotent:true`.
  4. Webhook signature salah -> 401 "Invalid signature".
  5. **Alur POS penuh**: transaksi `unpaid` (REST) -> `create_payment` dengan
     `transaction_id` -> webhook settlement -> `payment_orders.status=PAID` +
     `transactions.payment_status='paid'`, `paid_at` terisi, `provider_ref` = order id.
- Artinya QRIS dinamis Midtrans berfungsi END-TO-END di sandbox: charge -> QR ->
  (pembayaran disimulasikan via webhook, karena QR sandbox tidak bisa discan
  sungguhan) -> auto PAID -> transaksi POS ter-update otomatis.
- Data uji tertinggal di sandbox (aman, tanpa nilai): 2 payment_orders (`KGO-17912816*`,
  `KGO-17912818*`) + 2 transaksi uji di Warung Test.
- BERIKUTNYA: ST13C-3 (go-live production + audit keamanan + dokumentasi provider
  alternatif QRIS dinamis).

## Sesi 2026-10-06 (2): Phase 13C ST13C-3 - Go-live + Audit Keamanan [SELESAI]
- AUDIT KEAMANAN (semua BERSIH, detail `docs/GO-LIVE-PAYMENT-GATEWAY.md`):
  - Kunci asli (sandbox/production) tidak ada di repo, git history (`git log -S`),
    bundle web app & admin. `SB-Mid-server-...` di dart = placeholder hint saja.
  - JWT hardcoded di repo hanya anon key (app + admin, role `anon`).
  - RLS `outlet_pg_configs` aktif; kolom `server_key_secret_id` hanya
    postgres/service_role; `vault_read_secret`/`vault_put_secret` ditolak untuk
    authenticated (pen-test 403); `vault.decrypted_secrets` tak terbaca klien.
  - EF tanpa JWT -> 401 (save/test/create); `midtrans_webhook` verify_jwt=false
    (sesuai desain) tapi dilindungi signature SHA512 (pen-test 401).
- REMEDIASI `create_payment`: dulu nominal bebas dari klien. Kini bila
  `transaction_id` diberikan -> transaksi wajib milik outlet yang sama (403),
  belum dibayar (409), nominal == `final_amount` (400). Ter-deploy + terverifikasi
  (400/403/409 benar) + regression E2E POS lulus (charge -> webhook -> paid).
- DOKUMEN GO-LIVE `docs/GO-LIVE-PAYMENT-GATEWAY.md`: checklist go-live per outlet
  (aktifkan channel QRIS production, Notification URL =
  .../functions/v1/midtrans_webhook, uji nominal kecil), rotate Server Key
  (production key pernah lewat chat), dan tabel perbandingan provider QRIS dinamis
  berizin PJP: **Xendit** (rekomendasi utama), **iPaymu** (onboarding ringan),
  Tripay, Duitku. Arsitektur `PgProviderClient` siap tambah provider tanpa ubah UI.
- JAWABAN MASALAH USER: QRIS GoPay **statis** milik toko tidak bisa otomatis
  (tanpa webhook/order_id). Solusi: aktifkan channel **QRIS API (dinamis)** di
  Midtrans, atau ganti provider PJP lain; QRIS statis tetap jadi fallback manual.
- **PHASE 13 TUNTAS** (13A + 13B + 13C-1/2/3 SELESAI).

## Sesi 2026-10-06 (3): Phase 14 Dokter Bisnis AI (SELESAI)
- Tujuan: asisten AI "Dokter Bisnis" (diagnosa -> resep -> evaluasi) untuk owner
  gaptek. Skema doctor + EF LLM + tab superadmin + chat owner. Provider LLM
  dikonfigurasi superadmin (Control Plane), `api_key_enc` hanya service_role.
- ST14-1 `f2c618b`: migrasi `docs/migrations/2026-10-06-kasirgo-14-dokter-bisnis.sql`
  (DITERAPKAN): 7 tabel (`outlet_ai_configs`, `doctor_conversations`,
  `doctor_messages`, `doctor_memory`, `doctor_intake`, `doctor_action_logs`,
  `doctor_outlet_profile`) + index + seed `platform_configs.business_doctor` +
  RLS (`is_outlet_owner`/`is_platform_admin`) + view `outlet_ai_configs_public`
  (tanpa `api_key_enc`, kolom `has_api_key`) + helper `outlet_supporter_active()`.
- ST14-2 `b1cd1b8`: EF `business_doctor_chat` (deployed): konteks bisnis via tools
  (snapshot/trend/stok/kas/memori), tool-loop maks 2 putaran, output
  `{reply,blocks,phase,memory}` block types text/card/gauge/checklist/choices/action,
  gating `outlet_supporter_active`, provider override outlet else
  `platform_configs.business_doctor.provider_default`, fallback "Otak penuh belum
  aktif", regex FORBIDDEN, simpan messages/memory. Teruji 401 tanpa JWT, 200 owner.
- ST14-3 `32992a5` + dist `4d498e2` + gh-pages `ea59052`: Control Plane admin tab
  "Dokter Bisnis AI" (`DoctorTab`): config global (aktif/bahasa/prompt/guardrails/
  internet_tool/provider_default), tombol Tes Koneksi Provider + Chat Uji pilih
  outlet. EF mode `test_provider` (superadmin-only) + superadmin bypass
  membership/gating.
- ST14-4 `a6e6457` + gh-pages `5812cc1`: app owner. `business_doctor_service.dart`
  (klien EF), `business_doctor_screen.dart` (welcome 4 tombol besar: Diagnosa Usaha/
  Kenapa Omzet Turun/Saran Promosi/Cek Stok & Kas + kotak chat + renderer blocks +
  indikator loading + disclaimer), `widgets/common/business_doctor/doctor_blocks.dart`
  (renderer text/card/gauge/checklist/choices/action), kartu "Dokter Bisnis AI" di
  beranda owner (`_buildModularQuickActions`). `dart analyze` bersih (info style).
- ST14-5 `e30dde5` + gh-pages `3ee5814`: intake wizard "Cek Fisik Toko" (3 langkah
  bergambar: fisik/tampilan/perilaku, progress bar, catatan opsional) ->
  `doctor_intake_screen.dart`; ringkasan jawaban dikirim sebagai pesan diagnosa.
  `business_doctor_screen.dart` tombol CTA (tampil saat fase A) + muat fase dari
  `doctor_outlet_profile` + refresh setelah intake. `business_doctor_service.dart`
  +`saveIntake()`/`getPhase()`. EF `business_doctor_chat` (redeployed): definisi
  ALUR FASE A/B/C di system prompt (A diagnosa -> B resep -> C evaluasi). Verifikasi
  REST: insert `doctor_intake` 201, baca fase A. `flutter analyze` bersih.
- ST14-6: Peta Resep + Vonis + tool `save_prescription`. EF `business_doctor_chat`
  (redeployed): tool `save_prescription(verdict, steps[<=8])` simpan ke
  `doctor_memory` kind `prescription` (content JSON steps); system prompt wajib
  panggil tool saat masuk fase B + tampilkan peta resep sbg block checklist +
  sisipkan block action ber-`action_key` untuk langkah yang cocok fitur app.
  App `business_doctor_screen.dart`: `_handleAction`/`_actionScreen` memetakan
  `action_key` -> layar existing (`wa_marketing` -> WA Marketing ter-gate,
  `sidak_bos`/`progress_tracker` -> Laporan, `dynamic_pricing`/`bundling`/
  `cross_sell` -> Produk; `referral`/lainnya -> kirim sbg pesan). Teruji:
  no-JWT 401, owner 200 (fallback provider belum diatur). `flutter analyze` bersih.
- ST14-7: Catat Hasil Promosi + ROI + web tool. App: `doctor_promotion_log_screen.dart`
  (BARU) form chips jenis promosi/kanal/hasil + biaya & omzet tambahan + kartu ROI
  live (untung/rugi) -> `BusinessDoctorService.logPromotion()` insert
  `doctor_action_logs` (`result:{extra_revenue}`, `outcome`); `getActionLogs()`.
  `business_doctor_screen.dart`: action_key `catat_promosi` -> buka form, setelah
  simpan otomatis kirim pesan minta evaluasi ROI. EF `business_doctor_chat`
  (redeployed): tool baru `get_action_history` (riwayat promosi+biaya+hasil),
  `fetch_url` (web tool, gated `internet_tool.aktif`, guard SSRF host privat),
  riwayat aksi + aturan fase C (hitung ROI) di system prompt, action_key
  `catat_promosi` diizinkan. Teruji: no-JWT 401, owner 200, insert+delete
  `doctor_action_logs` 201/204, `flutter analyze` bersih.
- ST14-8: Escalation Ladder. EF `business_doctor_chat` (redeployed): tool baru
  `escalate_case(level 1-3, root_cause, reason)` -> update `doctor_conversations`
  (`status`: level>=3 `kasus_bandel` else `evaluasi_ulang`, `escalation_level`) +
  insert `doctor_memory` kind `lesson` (root cause); `execTool` kini terima
  `conversationId`; system prompt + blok ESCALATION LADDER (level 0 normal -> 1
  evaluasi ulang -> 2 lini kedua -> 3 kasus bandel, wajib `escalate_case`); respons
  EF + `status`/`escalation_level`. App `business_doctor_screen.dart`: state
  `_escalationLevel`/`_caseStatus` + banner (`_buildEscalationBanner`: Evaluasi
  Ulang/Lini Kedua/Kasus Bandel). Teruji: no-JWT 401, owner 200 (respons punya
  `status`/`escalation_level`), simulasi update conv level 3 -> respons
  `kasus_bandel`/3, RLS owner 204, `dart analyze` bersih.
- FIX KRITIS (infra, terpisah): kunci `anon` legacy yang di-hardcode di app +
  admin sudah DINONAKTIFKAN Supabase (`Invalid API key`). Diganti ke publishable
  key aktif `sb_publishable_8RJnG66i_37cih8GTG1sBA_0B91KOW_` di
  `kasirgo/lib/config/supabase_config.dart` + `kasirgo-admin/src/config/supabase.ts`.
- ST14-9: Memori jangka panjang + "Riwayat Kasus". App: `business_doctor_service.dart`
  +`listConversations`/`listMemories`/`listMessages` (baca `doctor_conversations`,
  `doctor_memory`, `doctor_messages` via RLS owner); layar baru
  `doctor_cases_screen.dart` (2 seksi: Kasus Konsultasi + Catatan Memori, badge
  status/fase/tingkat, tap kasus -> resume chat); `business_doctor_screen.dart`
  terima `conversationId` (resume + `_loadHistory`) + action AppBar "Riwayat Kasus".
  Memori jangka panjang (`doctor_outlet_profile.memory_digest`) sudah diperbarui tiap
  chat sejak ST14-2. Teruji REST owner: conversations 200 (5 baris), memory 200,
  messages by conversation 200; `dart analyze` bersih.
  CATATAN: cron `doctor_observe` DITUNDA -- ekstensi `pg_cron`/`pg_net` TIDAK
  terpasang di DB live (hanya `pgcrypto`). Alternatif: aktifkan di dashboard Supabase
  lalu jadwalkan, atau pakai scheduled Edge Function.
- ST14-10: Override provider AI per outlet (superadmin) + rate limit/kuota harian.
  Migrasi `docs/migrations/2026-10-14-kasirgo-14d-ai-override-ratelimit.sql`
  (DITERAPKAN): RPC `admin_list_outlet_ai_configs()` (daftar outlet + status override
  ter-mask, tanpa api_key), `admin_set_outlet_ai_config(outlet, config)` (upsert;
  api_key hanya ditimpa bila dikirim; tulis `log_admin_action`),
  `admin_delete_outlet_ai_config(outlet)`, `doctor_daily_usage(outlet)` (messages+tokens
  24 jam, service_role). Semua cek `is_platform_admin()`.
  EF `business_doctor_chat` (REDEPLOYED): rate limit non-superadmin via RPC
  `doctor_daily_usage`; config `business_doctor.rate_limit {messages_per_day=60,
  tokens_per_day=200000}` -> balas block "Batas harian tercapai" bila lewat.
  Admin Control Plane tab Dokter Bisnis AI: field Batas Pemakaian Harian + kartu
  "Override Provider per Outlet" (tabel outlet, Atur/Hapus; kunci di server saja).
  `controlPlane.ts` +`listOutletAiConfigs`/`setOutletAiConfig`/`deleteOutletAiConfig`
  +type `OutletAiConfig`.
  Teruji REST: list 7 outlet; set override Warung Test -> has_config/is_active/model/
  has_api_key benar -> delete -> kembali global; owner non-admin -> `forbidden`;
  usage service -> `{messages:7,tokens:0}`; EF rate limit (messages_per_day=1) ->
  block "Kuota Dokter Bisnis hari ini habis (7/1 pesan)" (config dipulihkan).
  Admin build sukses; gh-pages `bebb76d`.
  **PHASE 14 TUNTAS** (ST14-1..ST14-10).
- PERBAIKAN pasca-test owner (commit `2dbc202`, web gh-pages `127ad99`):
  (1) `max_tokens` provider default dinaikkan 4000 + guard (model reasoning
  `deepseek-4.1-flash` menghabiskan token; 800 bikin content kosong -> fallback);
  (2) CTA "Cek Fisik Toko" kini PERMANEN di atas chat (sebelumnya hanya saat
  percakapan kosong & fase A -> tak muncul untuk outlet yang sudah chat);
  (3) tombol "Evaluasi Resep" (Berhasil / Belum Berhasil) saat fase B/C memicu
  perbaikan resep + escalation; fase diperbarui tiap respons;
  (4) EF: push assistant tool_call sebagai objek bersih (buang reasoning_content)
  agar panggilan lanjutan tak keluarkan markup tool mentah; `extractJson`
  brace-matching ambil objek JSON pertama walau ada teks setelahnya.
  Teruji: chat fase A->B (fallback:false), prompt gagal -> escalation level 3
  `kasus_bandel` + blok card danger, reply JSON bersih.

## Sesi 2026-10-08: Phase 15A Master Prompt Karakter & Skill (ST15-1 SELESAI)
- Spec: `KASIRGO-WORKFLOW-LENGKAP.md` BAGIAN 13 (13.23-13.26) + BAGIAN 14.3.
  Progress baru: `PROGRESS-PHASE15.md` (15A SELESAI, berikutnya ST15-2).
- Migrasi `docs/migrations/2026-10-15-kasirgo-15a-master-prompt-skills.sql` (DITERAPKAN):
  merge `platform_configs.business_doctor`:
  - `prompt_utama` = teks BAGIAN 13.23 I (master prompt) + II (addendum A-O).
  - `prompt_utama_default` = salinan (untuk tombol Reset ke Default admin).
  - `skills[]` = 16 skill (chat..weekly_report).
  - `provider_default`/role_outlet/guardrails/internet_tool/rate_limit DIPERTAHANKAN.
- EF `business_doctor_chat` (REDEPLOYED): `SKILL_TOOLS` peta skill->tool; `toolAllowed()`,
  `skillList()`, `toolsFor(internetActive, skills)` mengirim tool sesuai skill terpilih
  (kosong = semua aktif); system context menyuntik "SKILL AKTIF: ..."; tool loop 2->3 putaran.
- kasirgo-admin `ControlPlane.tsx` `DoctorTab`: field "Master Prompt Karakter & Skill"
  (multi-line + Preview + Reset ke Default) + toggle "Daftar Skill" (chip 16 skill).
- Verifikasi: config live skills terisi & provider default utuh (deepseek-4.1-flash);
  EF chat superadmin fallback:false phase B menjawab; admin build EXIT 0; gh-pages admin dist.
- Penutup celah Phase 14: migrasi `2026-10-16-kasirgo-14d-unlimited-token-quota.sql` (DITERAPKAN)
  menambah `outlet_ai_configs.unlimited_tokens` + `token_quota` + RPC list/set; EF kuota per outlet
  (unlimited ON -> lewati, OFF -> token_quota/global); admin DoctorTab toggle unlimited + kuota +
  kolom Kuota. Teruji E2E (unlimited ON lolos token 255649>200000; token_quota=10 diblokir).
- ST14-6 lanjutan - Layar HASIL Diagnosa (13.21A): `doctor_result_screen.dart` (header+tanggal,
  gauge skor animasi, kartu vonis berwarna, peta resep checklist bernomor, target/timeline, footer).
  EF blok `prescription` + verdict/verdict_body/score/score_hint; tombol "Lihat Hasil Diagnosa"
  di `business_doctor_screen.dart` -> `_openResult()`. flutter_animate TIDAK terpasang (pakai
  animasi bawaan). Teruji: blok prescription berisi score 18 + verdict_body; analyze bersih.
- ST14-11: migrasi `2026-10-17-kasirgo-14e-observe-reprimand.sql` (DITERAPKAN):
  doctor_action_logs + status/due_date/reminder_count/last_reminded_at; doctor_memory
  + data/resolved_at + kind reprimand/market/scaling. EF chat tool `observe_progress`
  (omzet 7d vs 7d -> improving/flat/declining). EF BARU `doctor_observe` (REDEPLOY):
  evaluasi resep overdue -> achieved (>=80% langkah done)/failed + memori kind result;
  teguran bertingkat level 1 pengingat / 2 teguran / 3 teguran keras+sidak (anti-spam
  1/hari/outlet, simpan kind reprimand). App: banner teguran + chip alasan (lupa/waktu/
  modal/paham) -> kirim ke AI; Admin DoctorTab: kartu "Observasi & Teguran Otomatis"
  tombol Jalankan Observasi (semua/satu outlet). Teruji E2E: resep due 5 Okt ->
  eval failed + teguran level 3 tersimpan dgn data {done,total}; re-run idempotent
  (anti-spam). pg_cron/pg_net TIDAK terpasang -> jalankan via admin/dashboard scheduler.
  `PROGRESS-PHASE14.md` dibuat (ringkasan ST14-1..12 SELESAI + catatan penundaan).

## Sesi 2026-10-07: Dokter Bisnis - Resep Kaya + Jalankan (SELESAI)
- Tujuan: resep bukan sekadar teks, tapi kartu terstruktur + tombol "Jalankan"
  yang membuka fitur KasirGo terkait, plus menu "Resep Aktif" dan teguran masa target.
- EF `business_doctor_chat` (REDEPLOYED, commit `edd6bc7`):
  - `save_prescription` diperluas: `target_days` (default 7), `steps[].action_key`;
    saat simpan, resep open lama ditutup `status:'failed'`; `doctor_memory.due_at`
    = now + target_days hari; `content = JSON{verdict,target_days,started_at,steps}`.
  - tool BARU `get_active_prescription` (baca resep status open).
  - `sink: Json` diteruskan ke `execTool`; bila model lupa, blok `prescription`
    tetap di-push dari `sink.prescription` (jamin kartu tampil).
  - enum action_key valid: `sidak_bos|progress_tracker|dynamic_pricing|bundling|
    cross_sell|wa_marketing|catat_promosi|health_score|online_catalog|qr_table|
    multi_outlet|recipe` (referral & ai_copilot dihapus).
  - system prompt: daftar action_key + aturan WAJIB save_prescription saat
    menyusun/memperbarui resep; fase C pakai card+gauge+action "Catat Hasil Promosi";
    resep gagal -> escalate_case + save_prescription baru.
- App owner (commit `edd6bc7`, web gh-pages `e127061`):
  - `doctor_blocks.dart`: blok `prescription` dirender kartu (gradient badge AI,
    badge RESEP AKTIF/SELESAI, baris masa target, daftar langkah, pesan merah bila
    lewat) + callback `onPrescription(block, step, index)`; tombol "Jalankan" bila
    ada `action_key`, else "Tandai".
  - `business_doctor_service.dart`: `getActivePrescription` (parse content JSON ->
    blok) + `savePrescription` (update content/status).
  - `business_doctor_screen.dart`: muat resep aktif saat buka; kartu "Resep Aktif"
    di atas chat; `_maybeWarnOverdue` (AlertDialog bila `due_at` lewat);
    `_actionScreen` diperluas (health_score, online_catalog, qr_table, multi_outlet,
    recipe; beberapa dibungkus `SupporterFeatureGate`); `_onPrescriptionStep` buka
    fitur + tandai langkah done + auto `achieved` bila semua langkah selesai.
- TANPA migrasi baru: `doctor_memory.due_at` sudah ada; owner punya full akses
  `doctor_memory`.
- Verifikasi E2E (superadmin, outlet Warung Test): EF terpanggil -> blok `text` +
  `prescription` (5 langkah, action_key progress_tracker/sidak_bos/dynamic_pricing/
  wa_marketing/catat_promosi); baris `doctor_memory` kind prescription status `open`
  `due_at` terisi. `dart analyze` 3 file bersih (hanya info style pre-existing).
  CATATAN: rate limit owner 60 pesan/hari (superadmin dikecualikan) -- saat uji owner
  kuota sudah 30/60.

## Sesi 2026-10-08: Phase 15C Bos Virtual Growth (ST15-3 SELESAI)
- Migrasi `docs/migrations/2026-10-19-kasirgo-15c-bos-virtual-growth.sql` (DITERAPKAN):
  - `product_bundles` + `product_bundle_items`; `referral_codes` + `customer_referrals`.
  - RLS owner/superadmin (pola Phase 14/15B); `product_bundle_items` via bundle_id.
  - RPC `increment_referral_redeemed(uuid)` (SECURITY DEFINER, owner/admin).
  - RPC publik `get_public_bundles(TEXT)` untuk katalog anon (hanya paket aktif & produk published).
- Edge Function `business_doctor_chat` (REDEPLOYED):
  - Tool BARU `get_cross_sell` (association rule 200 transaksi terakhir: support/confidence/lift),
    `save_bundle` (resolve produk by nama/ID -> hitung original_price -> sink card),
    `save_referral` (kode berjenjang -> sink card).
  - `SKILL_TOOLS`: `cross_sell`, `bundling`, `referral`; helper `crossSellRules()`.
  - action_key enum + prompt DItambah kembali `referral`; sink push list + bundle/referral.
- App Flutter (commit ST15-3):
  - `utils/ai_engine.dart`: `crossSellRules(baskets, {minSupport, topN})`.
  - `services/growth_service.dart` (BARU): list/save/toggle/delete bundle, referral, tracking, stats;
    `productsClient` untuk query ad-hoc.
  - `screens/owner/bundle_manager_screen.dart` (BARU) + `referral_screen.dart` (BARU).
  - POS: strip bundling + chip cross-sell; bundling = 1 item (productId `bundle:<id>`).
  - Owner home: kartu Peluang Cross-Sell + shortcut Bundling/Referral.
  - Doctor screen: aksi resep bundling/cross_sell/referral -> layar baru (di-gate Pendukung).
  - Customer catalog: strip "Paket Hemat" (RPC get_public_bundles) + pesan via WA.
  - `supabase_service.dart`: `getPublicBundles`.
- Verifikasi E2E: referral HEMAT10 tersimpan; bundle Sembako Hemat (28000/31000, 2 item) tersimpan;
  get_cross_sell jalan (kosong karena outlet uji tanpa transaksi). `dart analyze` bersih.

## Sesi 2026-10-08: Phase 15D Addendum + Hardening (ST15-4 SELESAI) - PHASE 15 SELESAI
- Migrasi `docs/migrations/2026-10-20-kasirgo-15d-addendum-hardening.sql` (DITERAPKAN):
  - `doctor_memory` kind +`weekly_report` (constraint check diperbarui).
  - `doctor_outlet_profile` +`health_score`/`active_disease`/`active_disease_since`/`last_weekly_report_at`.
  - Tabel BARU `doctor_pending_actions` (action_type/title/body/payload/status pending|approved|rejected/
    decision_note/decided_at) + RLS owner (is_outlet_owner) & superadmin.
- Edge Function `business_doctor_chat` (REDEPLOYED):
  - Tool BARU `propose_action` (guardrail M): menulis `doctor_pending_actions` (status pending) +
    sink `pending_action`; JANGAN eksekusi langsung. Tool BARU `benchmark_hyperlocal` (N):
    agregat anonim `hyperlocal_reports` (+ fallback alamat outlet); `need_verification` bila <3 outlet.
  - `SKILL_TOOLS` +`market_intel` (`fetch_url`,`benchmark_hyperlocal`) & `weekly_report` (`propose_action`).
  - Output +`identity` (O): {fase, active_disease, active_prescription, deadline, health_score,
    business_age_days, revenue_today}; juga update `doctor_outlet_profile.health_score/active_disease`.
  - Sink push list +`pending`; prompt ditambah 2 baris (guardrail aksi otomatis + benchmark).
- Edge Function `doctor_observe` (REDEPLOYED):
  - (L) Laporan mingguan: maks 1/pekan/outlet (gate `last_weekly_report_at`); isi `doctor_memory`
    kind `weekly_report` (omzet 7 hari, produk terlaris, resep/teguran aktif) + update profil.
- App Flutter (commit ST15-4):
  - `business_doctor_service.dart`: `getLatestWeeklyReport`, `listPendingActions`,
    `decidePendingAction`, `getOutletIdentity`.
  - `business_doctor_screen.dart`: kartu Identitas Bisnis (O), kartu Laporan Mingguan (L),
    kartu Persetujuan Aksi Setujui/Tolak (M); load saat init & reload saat blok pending muncul.
- Verifikasi E2E: `propose_action` -> pending + approve owner via RLS OK; `benchmark_hyperlocal`
  tanpa wilayah -> fallback aman + "perlu verifikasi"; `doctor_observe` -> `weekly_report` omzet
  7 hari Rp30.000 & `last_weekly_report_at` terisi; `identity` (fase B, skor 42). `dart analyze` bersih.
- BLOCKER tetap: pg_cron/pg_net tak terpasang -> jadwal via manual admin/Dashboard; Midtrans prod QRIS.

## Sesi 2026-10-21: Fix List Pasca-Testing Owner + Superadmin (SELESAI)
Batch perbaikan hasil testing lengkap user (17 item owner + 3 item superadmin).
Commit berurutan di main; Flutter web + admin dist dideploy ulang.
- FIX #1 (`7629155`): login `email_not_confirmed` -> pesan khusus "konfirmasi email dulu".
- FIX #2 (`13e3429`): KYC — migrasi `2026-10-21-kasirgo-fix-kyc-nik-year.sql` (RPC `submit_kyc`
  dibuat ulang: tahun lahir NIK 2 digit APA PUN valid, hanya tolak = tahun berjalan);
  klien `ktpTextLooksReal()` (marker KTP asli), selfie-NIK match, autofill OCR, chip status.
- FIX #3 (`f0a8278`): dialog sukses checkout BARU `checkout_success_dialog.dart` + tombol
  "Struk PDF"; `receipt_generator.share()` fallback web (conditional import dart:html download).
- FIX #5/#6 (`de0de01`): field Nama Pelanggan di pembayaran + autofill dari nomor WA;
  auto-create pelanggan (`upsertCustomerFromPhone`, normalisasi 62<->08) di POS owner & kasir.
- FIX #6b/#7 (`fb4c3f5`): dialog Tambah Pelanggan diperindah (X ujung kanan) + hapus pelanggan
  (menu -> konfirmasi -> snackbar).
- FIX #7b/#8 (`ad43f21`): migrasi `2026-10-21-kasirgo-fix-product-delete.sql` — FK
  `transaction_items_product_id_fkey` ON DELETE SET NULL (fix gagal hapus produk);
  dialog hapus produk diperindah; scanner barcode X `close_rounded`.
- FIX #9 (`55b7ba9`): shortcut Peta Ekspansi & Referral dihapus dari owner home.
- FIX #10 (`3346b21`): kartu PPOB/Kulakan B2B/Modal Usaha disembunyikan di owner home;
  subtitle Pendukung "Dukung Pengembangan".
- FIX #11 (`53451a7`): checkout QRIS statis-only (info bar, mode switch dihapus).
- FIX #16 (`1cfe625`): QR Meja — tambah via keyboard done + snackbar sukses/gagal;
  REST verify insert/delete RLS OK.
- FIX #13 (`52c29d5`): aksi resep — cross_sell membuka Paket Bundling; langkah tanpa fitur
  (referral disembunyikan) cukup tercoret tanpa spam chat.
- FIX #17 (`f3aa03d`): Riwayat Kasus — filter Semua/Harian/Mingguan/Bulanan (chip);
  hapus per item (kasus + memori) & hapus semua per periode; service deleteConversation/
  deleteMemory (RLS owner ALL, pesan cascade).
- FIX #14 (`d8eac09`): hardening balasan AI — prompt EF larang jawaban Inggris/kode;
  `sanitizeReply` post-process (blok kode & jawaban mayoritas Inggris diganti pesan aman);
  EF `business_doctor_chat` dideploy ulang.
- FIX #4 (`8b0c258`): laporan Excel & PDF standar keuangan nasional (SAK EMKM):
  Excel 3 sheet (Ringkasan laba rugi, Penjualan buku kas, Per Produk); PDF MultiPage
  (Identitas Usaha, Laba Rugi, Penerimaan per metode bayar, Catatan, tanda tangan);
  unduh web via `ReceiptGenerator.share`.
- FIX #12 owner (`8e51eea`): migrasi `2026-10-21-kasirgo-fix-owner-affiliate.sql` —
  tabel `outlet_affiliate_profiles` & `outlet_affiliate_closings`, trigger auto-affiliate
  (outlet baru otomatis punya kode KGO-XXXXXX, backfill 8 outlet), RPC
  `affiliate_owner_me`/`affiliate_owner_update`; layar `AffiliateOwnerScreen` (kode+link
  referral salin, ringkasan komisi, riwayat closing, form rekening, panduan); shortcut
  Afiliasi di owner home; helper `SupabaseService.rpc()`.
- FIX #12 superadmin (`d420c83`): migrasi `2026-10-21-kasirgo-fix-superadmin-affiliate.sql`
  (RPC `platform_affiliate_closings`, `platform_outlet_affiliates`,
  `platform_outlet_affiliate_closing_add`); halaman Affiliates tab Partner/Outlet + modal
  detail closing; ControlPlane AffiliateTab + komisi outlet & pengaturan payout
  (frekuensi/tanggal/mode).
- Superadmin hide laporan (`a855d2f`): migrasi `2026-10-21-kasirgo-fix-report-visibility.sql`
  — config 'report' + 4 flag (show_ppob_report/show_pg_report/show_outlet_ppob/
  show_outlet_hist, default FALSE = disembunyikan), RPC `platform_report_visibility`;
  MainReport kartu PPOB & QRIS hidden; OutletDetail stat finansial & Riwayat Transaksi
  hidden; ControlPlane > Laporan 4 toggle untuk membuka kembali.
- Verifikasi RPC via REST (JWT owner Warung Test & superadmin): affiliate_owner_me OK,
  affiliate_owner_update OK, platform_report_visibility OK (owner forbidden sesuai desain).

## Sesi 2026-10-08 (2): BATCH #2 Perbaikan Owner (SELESAI)
Commit `7d57a00` (main) + deploy web gh-pages `680c199`.
- RESEP 2-TOMOL: `doctor_blocks.dart`/`doctor_result_screen.dart` kini tombol ganda
  "Jalankan" (buka fitur terkait + tandai langkah selesai) & "Tandai Selesai"
  (checklist murni). `business_doctor_screen.dart` `_onPrescriptionStep`/
  `_togglePrescriptionStep`/`_markPrescriptionDone` + simpan `achieved` bila semua
  langkah done; `business_doctor_service.savePrescription` `memoryId` opsional
  (resolve dari `block['memory_id']`).
- STRUK WA: `checkout_success_dialog.dart` opsi "Kirim Struk Text ke WA" &
  "Kirim Struk PDF ke WA"; `receipt_generator.dart` +`buildTextReceipt`/
  `sendTextToWhatsApp`/`sendPdfToWhatsApp` (+restore `shortId`/`methodLabel`);
  wired di `pos_screen.dart` (owner) & `cashier_pos_screen.dart` memakai
  `result.customerPhone`.
- KYC HARDENING: `kyc_checks.dart` `isValidNikFormat` cukup tepat 16 digit angka
  (tolak digit seragam `^(\d)\1{15}$`), `extractNikFromText` pakai teks
  ternormalisasi (fix offset), +`isLikelyImageBytes` (magic bytes JPEG/PNG/GIF/
  BMP/WEBP/HEIC); `kyc_ml_io.dart` `ktpTextLooksReal` butuh >=2 penanda struktural
  + NIK; `onboarding_kyc_screen.dart` tolak berkas non-gambar saat unggah.
- GATING DOKTER BISNIS AI: `supporter_service.dart` +fitur `business_doctor`
  (premiumFeatures + featureLabels); `owner_home_screen.dart` kartu Dokter Bisnis AI
  lewat `_pushGated('business_doctor', ...)`.
- TRIAL: `supporter_gate.dart` (dialog & layar kunci) tawarkan dua jalur Trial/Upgrade
  menuju `SupporterScreen`; `supporter_screen.dart` +tombol "Coba Trial Gratis"
  (`SupporterService.ensureTrial`) saat belum punya akses. Upgrade tetap pakai QRIS
  DINAMIS otomatis (`SupporterService.checkout` -> `PaymentService.createQris`).
- Verifikasi: `dart analyze lib` 0 error (hanya info pre-existing); bundle web memuat
  string fitur baru; live: https://ikhlassabar2021-create.github.io/kasirgo/

## Sesi 2026-10-08 (3): BATCH #3 Perbaikan Owner (SELESAI)
Commit `672286b` (main) + deploy web gh-pages `6a7acb2` (live md5
`ce1470a11106657969c09c21a2f18c9d`).
- KYC "VERIFIKASI GAGAL" (BACKEND, root cause): migrasi
  `2026-10-22-kasirgo-fix-submit-kyc-columns.sql` (DITERAPKAN). `submit_kyc()` dari
  migrasi `2026-10-21-kasirgo-fix-kyc-nik-year.sql` menulis kolom yang TIDAK ADA di
  `outlet_kyc` (`phone_digits` + `submitted_at`) -> setiap submit outlet non-verified
  melempar `42703 undefined_column` = "Gagal mengirim verifikasi". Fungsi ditulis ulang
  memakai kolom benar (`phone`, `auto_verified`, `verified_at`) + AUTO-VERIFY
  (`v_all_ok -> status 'verified' & auto_verified=true`), perbaikan NIK 2-digit
  dipertahankan. E2E REST (owner affiliate) LULUS: `{status:verified, auto_verified:true}`
  + baris tersimpan. Data uji dibersihkan.
- LOGIN (`login_screen.dart`): wording email belum dikonfirmasi diperjelas
  ("Email harus dikonfirmasi dulu. Silakan cek email Anda (kotak masuk / folder spam)
  untuk tautan konfirmasi.").
- DIALOG HAPUS PRODUK (`product_list_screen.dart`): `titlePadding` kanan 8 + tooltip
  "Tutup" -> tombol X di ujung kanan (mengikuti dialog Tambah Pelanggan).
- RESEP "TANDAI SELESAI" (`business_doctor_screen.dart`/`doctor_result_screen.dart`):
  - `_markPrescriptionDone` kini sinkronkan kartu resep di gelembung chat (match
    `memory_id`/referensi) agar langkah langsung tercoret, bukan hanya kartu atas.
  - `DoctorResultScreen` StatelessWidget -> Stateful; salin `_steps` lokal, tombol
    Jalankan/Tandai Selesai memutasi state lokal (langsung strikethrough) lalu panggil
    callback parent.
- RESEP "JALANKAN" cross_sell (`business_doctor_screen.dart`): action_key `cross_sell`
  kini membuka `PosScreen` (chip saran upsell saat bayar), bukan `BundleManagerScreen`
  (bundling sudah punya action_key sendiri).
- QRIS STATIS PRODUK VS DINAMIS PENDUKUNG: pembayaran produk di POS tetap
  memakai QRIS Statis manual (sesuai kebijakan bisnis UMKM). QRIS Dinamis otomatis
  dipakai saat Owner/pengguna upgrade ke Program Pendukung (`SupporterScreen` /
  `SupporterService.checkout` -> dynamic QRIS via RCB gateway).
- Verifikasi: `dart analyze` bersih; build web sukses; live md5 cocok.

## Sesi 2026-10-08 (4): BATCH #4 Perbaikan Owner (SELESAI)
Commit `731fb3b` (main) + deploy web gh-pages `d0e66bf`.
- CORS EF PAYMENT GATEWAY (root cause Upgrade Pendukung "QRIS dinamis tidak muncul"):
  preflight browser (OPTIONS) ke EF `rcb_create_charge` GAGAL ("No
  'Access-Control-Allow-Origin'") -> `createQris` throw -> app diam-diam fallback ke
  QRIS Statis. curl (server-side) berhasil, jadi tak terlihat sebelumnya.
  Ditambah CORS ke 5 EF: `rcb_create_charge`, `rcb_check_status`, `create_payment`,
  `save_payment_config`, `test_payment_connection` (pola sama `business_doctor_chat`).
  Kelimanya SUDAH DI-DEPLOY (perbaikan live tanpa rebuild app).
- SETTINGS (`settings_screen.dart`): menu "Hubungkan Midtrans (QRIS Dinamis)" dan
  kartu "Konfigurasi Platform" (`_buildFinancialConfigCard`) DIHAPUS dari UI owner.
  Import `midtrans_connect_screen.dart` + `settlement_service.dart` dibuang.
- HAPUS OUTLET (multi-outlet): migrasi
  `docs/migrations/2026-10-23-kasirgo-fix-delete-owner-outlet.sql` (DITERAPKAN).
  RPC `delete_owner_outlet(p_outlet UUID)` SECURITY DEFINER: validasi owner/admin,
  tolak outlet terakhir ("Minimal harus ada 1 outlet"), lepas FK
  `affiliate_referrals.outlet_id` (NO ACTION -> SET NULL) lalu DELETE outlet
  (sisanya CASCADE). `SupabaseService.deleteOwnerOutlet` + tombol hapus
  (konfirmasi) di `multi_outlet_screen.dart` (hanya outlet non-aktif, bila >1).
  Verifikasi REST: buat outlet `__DEL_TEST__` -> RPC hapus sukses -> baris hilang;
  guard outlet terakhir balas `{success:false,"Minimal harus ada 1 outlet"}`.
- Verifikasi: `flutter analyze` (3 file) bersih (hanya info pre-existing);
  build web sukses; live md5 cocok.

## Sesi 2026-10-08 (5): Fix QRIS Dinamis di Alur Dukung dari Pengaturan (SELESAI)
Commit `ff04bb3` (main) + deploy web gh-pages `050051c` (live md5
`44c74f7cc23397040ec9033acb39e633`).
- ROOT CAUSE laporan "klik Dukung KasirGo -> Perpanjang Sekarang -> QRIS tidak
  tampil -> langsung pesanan berhasil": `settings_screen.dart` `_handleSupport`
  memanggil `SupporterService().checkout(...)` lalu HANYA menampilkan SnackBar
  sukses; hasil QR dinamis (`qrisString`/`qrisUrl`/`paymentUrl`) dibuang sehingga
  QR tidak pernah dirender. (Jalur `SupporterScreen` sudah benar.)
- FIX: ekstrak sheet QRIS dinamis + polling status ke widget bersama
  `kasirgo/lib/widgets/common/dynamic_qris_sheet.dart` (`DynamicQrisSheet`),
  dipakai `supporter_screen.dart` (ganti kelas privat `_DynamicQrisSheet`) DAN
  `settings_screen.dart` (`_handleSupport` kini `showModalBottomSheet` bila
  `result.hasDynamicQr`; fallback statis tetap SnackBar).
- CATATAN: `checkout(qrisType:...)` sebenarnya selalu mencoba `createQris` lalu
  fallback statis saat catch; param `qrisType` tidak menentukan. Masalahnya murni
  hasil QR tidak ditampilkan.
- Verifikasi live Playwright (Gerobak Test, route `#/owner/settings`): klik
  "Dukung KasirGo Sekarang" -> "Dukung Sekarang" -> sheet "Pembayaran QRIS"
  TAMPIL + EF `rcb_create_charge` 200 + polling `rcb_check_status` PENDING.
  `flutter analyze` 3 file bersih.

## Sesi Bersih Data Uji (Item #9) (SELESAI)
- Tujuan: hapus semua akun/outlet uji, sisakan hanya akun milik
  `ikhlassabar2021@gmail.com` (semua varian `+tag` DIPERTAHANKAN) + `superadmin@kasirgo.com`.
- Eksekusi via Supabase Management API `POST /v1/projects/lmvjecdvfzsmrowwwpck/database/query`:
  `delete from auth.users where email is null or (email not like 'ikhlassabar2021%'
  and email <> 'superadmin@kasirgo.com')`.
- Sebelum hapus: `outlets_owner_id_fkey` = ON DELETE CASCADE (tervalidasi) -> outlet
  ikut terhapus; FK NO ACTION (`transactions.user_id`, `employees.user_id`,
  `affiliate_referrals.referred_user_id`) dicek = 0 baris (tidak memblokir).
- Hasil: 99 user terhapus (92 anon + digitalnewss02, lifesgroups, marketingaps2016,
  rumahaps, sabarberkah2017, test, virna). Tersisa 25 user (24 `ikhlassabar2021*` +
  superadmin). `outlets` 103 -> 7; `products` 12; `transactions` 37; `customers` 3;
  `user_roles` 14. Verifikasi orphan (products/tx/customers/user_roles terhadap
  outlets) = 0. Tidak ada perubahan kode (operasi data murni).

## Sesi 2026-10-17: Squad DM Live + Hapus Onboarding Anonim (SELESAI)
- ROOT CAUSE kartu "Squad DM" tak pernah tampil: RLS `platform_configs` menutup
  key `digital_marketing_llm` untuk klien (agar api_key tidak bocor), sehingga
  `SupporterService.getConfig` mengembalikan kosong -> `dmEnabledProvider=false`.
- MIGRASI `docs/migrations/2026-11-22-kasirgo-dm-enabled-flag.sql` (DITERAPKAN):
  RPC `dm_enabled()` SECURITY DEFINER, hanya balas boolean `aktif`, EXECUTE
  authenticated+service_role (anon 401). `dmEnabledProvider` kini panggil RPC.
- `design_studio_screen.dart`: tambah aksi AppBar "Studio Promosi" +
  "Studio Iklan" (sebelumnya kedua layar tak punya entry point).
- Commit `0d362a1` (main), deploy web gh-pages `10f4d07`; live md5
  `ad763aa3e299eb911f1d83c7ad2beab3`. Verifikasi Playwright owner Gerobak
  (1280x900): Studio Desain (panel Pratinjau), Studio Promosi, Studio Iklan
  render, 0 request gagal.
- `external_anonymous_users_enabled=false` (provider level) + onboarding anonim
  dihapus dari app (sesi sebelumnya) -> signup anon kini 422.
- BERSIH DATA: 30 user `is_anonymous` (tanpa email) + 30 outlet "Toko Baru"
  (0 produk, 0 transaksi) dihapus via Management API. Backup daftar id di
  `/tmp/opencode/backup_anon_users.json`. Hasil: users 56 -> 27, outlets 41 -> 11,
  orphan 0. Sisa 27 akun: 24 `ikhlassabar2021*` + superadmin + 2 akun lama
  (`marketingaps2016`, `sabarberkah2017`) yang TIDAK dihapus (menunggu keputusan).

## Sesi 2026-10-17 (2): Fix 5 Keluhan Bos - Dropdown, Login Pembeli, Checkout, Kunci Premium (SELESAI)
- KATEGORI USAHA (pembeli) & TIPE USAHA (Lapak Live owner) kini dropdown bottom-sheet
  via widget baru `widgets/common/app_dropdown_field.dart` (menggantikan chip horizontal
  yang terpotong). Opsi dari `AppConstants.businessTypes`.
- LOGIN PEMBELI: `buyer_auth_screen.dart` mendeteksi email sudah terdaftar -> otomatis
  mode Masuk (bukan signup senyap); `email_not_confirmed` -> kartu konfirmasi + kirim
  ulang tautan. `utils/error_messages.dart` +`errorCode()`/`isEmailNotConfirmed()`.
- CHECKOUT PEMBELI: `buyer_checkout_screen.dart` validasi `_submit` + peta pesan error
  RPC (`EMPTY_CART`, `OUTLET_NOT_FOUND`, `ADDRESS_REQUIRED`, `AUTH_REQUIRED`,
  `PRODUCT_NOT_FOUND`, `PRODUCT_NOT_PUBLISHED`, `OUT_OF_DELIVERY_RANGE`,
  `BUYER_BLOCKED`) + `_promptRelogin`. `order_service.submitOrder` -> rpc `submit_order`.
- KUNCI PREMIUM TANPA TRIAL: migrasi `docs/migrations/2026-11-23-kasirgo-lock-premium-no-trial.sql`
  (DITERAPKAN) - bersihkan trial basi, `outlet_supporter_active()` hanya mengakui trial
  bila `billing.trial_enabled=true` (default FALSE). `supporter_service.dart`:
  `hasAccess => isSupporter || isTrialActive`, KYC tidak lagi membuka fitur,
  `ensureTrial` di-skip saat flag OFF. `owner_home_screen.dart`: Business Doctor &
  Lapak Live via `_pushGated` + kartu "Konsultasi" pakai `SupporterFeatureGate`.
- AUDIT GATE: semua `premiumFeatures` ber-UI sudah ter-gate (wa_marketing, online_catalog,
  qr_table, health_score_pro, export_excel/pdf, multi_outlet, extra_staff, custom_receipt,
  auto_bos_report, business_doctor, lapak_live, ad_free via AdService). `ai_pro`,
  `advanced_report`, `backup_cloud` tanpa entry point UI (tidak perlu gate).
- Commit `0d09ba0` (9 file); build web release + deploy gh-pages `34d8570`;
  live md5 `main.dart.js` = `855fa5c5ea5d1f913fb5c5b792f0af4a` (cocok build).
- Uji REST: login pembeli OK; submit_order EMPTY_CART/OUTLET_NOT_FOUND sesuai;
  sukses `ORD26101700040` (Toko Test, total 15000, unique_code 140, pay 15140).
  `outlet_supporter_active`: Toko Test true, Gerobak/Warung Test false (terkunci).
- `flutter analyze lib`: 22 info (0 warning/error). Data uji order belum dihapus
  (menunggu izin).
- E2E LIVE UI (Playwright, 1280x1400): login pembeli `qa.checkout@kasirgo.test` OK
  (catatan: isi password via Tab dari field Email; klik langsung field sandi gagal fokus)
  -> isi koordinat manual -> radar -> Lihat Katalog Toko Test -> tombol `Keranjang`
  -> `Lihat Keranjang` -> `Lanjut ke Checkout` -> isi Nama/WA -> `Buat Pesanan` ->
  RPC `submit_order` 200 -> kartu "Pesanan Dibuat" `ORD26101700042` (Roti Bakar,
  total Rp12.000, kode unik +142).
- E2E LIVE gate premium outlet terkunci: login owner `+warung@gmail.com` ->
  klik kartu "Dokter Bisnis AI" -> dialog "Fitur ini bagian dari Program Pendukung
  KasirGo (Rp50.000/bulan)" + tombol "Beli Sekarang". (Gerobak Test sudah diuji
  sesi sebelumnya.)
- Data uji order: `ORD26101700040`, `ORD26101700041` (REST), `ORD26101700042` (UI).

## Sesi 2026-10-18: Fix Gate Palsu Owner Aktif + Verifikasi Dropdown Lapak Live (SELESAI)
- ROOT CAUSE gate Program Pendukung muncul untuk outlet yang SUDAH berlangganan:
  `SupporterService.getEntitlements` mengambil baris `supporters` TERBARU
  (`order start_date desc limit 1`) TANPA filter status. Baris `pending` baru
  (checkout belum dibayar, Toko Test 2026-10-17 20:59) menutupi baris `active`
  (2026-10-10 s/d 2026-11-09) -> `isSupporter=false` -> `hasAccess=false`.
- FIX `lib/services/supporter_service.dart`: query baris `status='active'`
  lebih dulu, fallback ke baris terbaru hanya untuk status tampilan.
  `flutter analyze` file bersih. Commit `4543d74`.
- Deploy web: build release + gh-pages `225da11` (md5 `main.dart.js`
  `c4e64ae47345e624f9a076e4dee8d729`).
- VERIFIKASI LIVE (Playwright, serviceWorkers block + cache-bust):
  - Owner Toko Test login -> "Lapak Live" TERBUKA, tidak ada dialog Pendukung
    (`gate dialog present: false`, `gate after click: false`).
  - Dropdown "Tipe Usaha" membuka bottom sheet berisi 12 opsi: Warung Sembako,
    Warung Madura, Kelontong, Retail, Cafe, Restoran, Kedai Kopi, Minimarket,
    Toko Baju, Apotek, Gerobak, Lainnya. Catatan: klik label `Tipe Usaha`
    (bukan tombol "Simpan Tipe Usaha") untuk membuka sheet.
- Data uji `ORD26101700040..42` sudah dihapus; `orders_left=0`, orphan 0.

## Sesi 2026-10-18 (2): Dedupe Dokter Bisnis + Opsi Diantar + Bersih 2 Akun (SELESAI)
- FIX DUPLIKASI DOKTER BISNIS (server): `supabase/functions/business_doctor_chat/index.ts`
  merge blok kini dedupe singleton `dose`/`prescription` (versi server menang:
  `blocks = blocks.filter(b => b?.type !== s.type)`). EF SUDAH dideploy. Uji EF live:
  200, 3 blok (`text,prescription,dose`), masing-masing 1.
- FIX RENDER GANDA (app): `business_doctor_screen.dart` `_buildBubble` menyaring blok
  `dose` bila `_dailyDose != null`; getter `_chatShowsRecipe`; kartu `_activePrescription`
  di `_buildList` hanya tampil bila chat belum memuat peta resep.
  Verifikasi Playwright: `JALANKAN_COUNT 1`, `TUTUP_COUNT 1` (tidak dobel).
- FIX OPSI "DIANTAR" HILANG: `Cart.hasDelivery` + `Cart.empty`; `CartNotifier.add`
  menerima `hasDelivery` dan `setQty`/`remove` mempertahankannya; `buyer_home_tab`
  `_addToCart` mengirim `outlet.hasDelivery`; `_CartSheet` -> checkout memakai
  `outlet?.hasDelivery ?? cart.hasDelivery`. Verifikasi data: `nearby_outlets`
  Toko Test `true`, Gerobak Test `false`. Playwright `delivery_final.js`:
  `HAS_DIANTAR true`, `HAS_AMBIL true`.
- HAPUS 2 AKUN (disetujui Bos): `sabarberkah2017@gmail.com` + `marketingaps2016@gmail.com`
  via Management API; cascade 3 outlet kosong. Sisa users 27, outlets 10.
- Analyze: `flutter analyze lib` 22 info (0 error/warning).
- Commit `0ff7d4d` (5 file); deploy web gh-pages `2d078d0`.
- APK rilis dibangun via GitHub Actions (sandbox TIDAK punya Android SDK/Java;
  RAM tersisa ~400MB sehingga build lokal tidak layak). Tag `v1.0.0-apk-20261018`
  memicu workflow `release-apk.yml` (`--split-per-abi --obfuscate`).

### Lanjutan: Build APK rilis (v1.0.2) + kendala ukuran
- CI `release-apk.yml` gagal 2x lalu SUKSES pada tag `v1.0.2-apk-20261018`
  (run `39133305966`). Dua fix build yang diperlukan:
  1. `android/app/build.gradle.kts`: `isCoreLibraryDesugaringEnabled = true` +
     `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`
     (flutter_local_notifications 22.x mewajibkan desugaring).
  2. `pubspec.yaml`: `sqlcipher_flutter_libs` DIHAPUS (namespace
     `eu.simonbinder.sqlite3_flutter_libs` bentrok dengan `sqlite3_flutter_libs`
     -> manifest merger gagal). Kode memang memakai `sqlite3.open`, bukan SQLCipher.
- Artifact `apk-release` diunduh + dipublikasikan sebagai GitHub Release
  `v1.0.2-apk-20261018` (prerelease): `kasirgo-1.0.2-arm64-v8a.apk` 58,4 MB,
  `armeabi-v7a` 47,4 MB, `x86_64` 62,9 MB.
- CATATAN UKURAN: target <10 MB TIDAK mungkin untuk build ini. Baseline Flutter
  saja `libflutter.so` 11,7 MB + `libapp.so` 11,7 MB (~23 MB). Penyumbang besar:
  `libmlkit_google_ocr_pipeline.so` 11,1 MB + model OCR, `libface_detector_v2_jni.so`
  8,5 MB, `libbarhopper_v3.so` (barcode) 4,9 MB. Melepas seluruh ML Kit hanya
  menurunkan ke ~28 MB.

### Keputusan Bos: APK tetap fitur lengkap
- Bos memilih opsi 1 (pertahankan semua fitur, ~58 MB arm64). Tidak ada
  pemangkasan ML Kit. Release `v1.0.2-apk-20261018` = versi rilis resmi saat ini.
- Link terverifikasi HTTP 200 (arm64/armeabi-v7a/x86_64).

### Rilis 1.0.2 RELEASE-SIGNED (18 Okt 2026) - SELESAI
- Keystore rilis dibuat agen: PKCS12 alias `kasirgo`, RSA 2048, valid s.d. 2054
  (`/tmp/opencode/keystore/kasirgo-upload.p12`; JKS + `pass.txt` di folder sama;
  JANGAN commit). SHA-1 `A6:17:30:2D:91:C6:A0:9C:F3:22:14:73:2B:6C:51:42:3A:41:4C:28`.
- Signing wiring: `android/app/build.gradle.kts` baca `android/key.properties`
  (release-if-exists-else-debug); `.gitignore` menutup `key.properties`/`*.p12`/`*.jks`/`*.keystore`.
- `.github/workflows/release-apk.yml`: setup-java 17 + flutter-action, langkah
  "Siapkan keystore rilis" dari secrets (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
  `KEY_ALIAS`, `KEY_PASSWORD`), build APK split-per-abi + AAB, checksum SHA-256,
  `apksigner verify`, artifact `apk-release`/`aab-release`, input
  `debug_sign_fallback` untuk build tanpa secret.
- Label aplikasi diperbaiki: `android:label="KasirGo"` (commit `e84d571`).
- BLOCKER: token git credential = GitHub App installation token -> PUT
  `/actions/secrets/*` 403. Build dipicu `debug_sign_fallback=true`
  (run `39144383963` SUKSES), lalu ditandatangani ulang LOKAL:
  `zipalign -p -f 4` + `apksigner sign` (APK v1+v2+v3) dan
  `jarsigner` AAB setelah META-INF lama dibuang.
- GitHub Release **`v1.0.2-signed-20261018`** (id `416571011`, bukan prerelease):
  3 APK signed + `kasirgo-1.0.2.aab` + `SHA256SUMS.txt`. Verifikasi
  `apksigner verify --print-certs` = sertifikat keystore di atas.
- Prosedur + checklist Play Console: `docs/RELEASE.md`.
- TINDAK LANJUT MANUSIA: (1) isi 4 GitHub Secrets agar CI langsung signed,
  (2) backup keystore + password (hilang = tak bisa update app).

### Tipe Usaha "Jasa" + Produk Layanan Tanpa Stok (19 Okt 2026) - SELESAI
- Migrasi `docs/migrations/2026-10-19-kasirgo-jasa-service-products.sql` (DITERAPKAN):
  `products.is_service BOOLEAN NOT NULL DEFAULT false` + index
  `idx_products_outlet_is_service`; `decrement_stock()` skip produk layanan;
  `get_public_catalog`/`get_public_menu`/`search_marketplace` mengembalikan
  `is_service` dan meloloskan produk layanan walau `stock=0`.
- Client: `AppConstants.businessTypes` + "Jasa"; `ModuleConfig` modul/alias/contains
  `jasa`; `Product.isService`; form produk toggle "Produk Jasa / Layanan" (stok
  disabled, tersimpan `isService`); guard stok di POS/katalog/keranjang/AI engine
  skip layanan; badge "Layanan" di daftar produk, grid POS, katalog pelanggan;
  `MarketplaceResult.isService`; SQLite lokal kolom `is_service` (migrasi aditif).
- Verifikasi live Playwright: produk layanan `stock=0` tetap tampil di POS dengan
  badge "Layanan" + bisa masuk keranjang tanpa error stok; `get_public_catalog` &
  `get_public_menu` memuat produk layanan stok 0. Data uji dikembalikan ke semula.
- Build web release + deploy gh-pages commit `abb7e64` (sebelumnya `2d078d0`).
- Commit kode+migrasi: `333ab15` (main).

### Notifikasi Tugas Terlambat + Teguran Otomatis (Dokter Bisnis 13.21B) - SELESAI
- `lib/services/doctor_alert_service.dart` (BARU): `checkAndNotify(outletId, userId, role)`
  -> notifikasi LOKAL (bukan push) saat login. Owner: 1 rekap tugas staf terlambat
  (`N tugas staf terlambat`, 3 nama) + 1 notifikasi teguran terbaru
  (`BusinessDoctorService.getLatestReprimand`). Staf: maks 3 notifikasi per tugas
  (`Terlambat:` / `Jatuh tempo:`). Anti-spam harian via SharedPreferences
  `doctor_alert_seen_v1` (prune 200), ID notifikasi per tugas = base 78210 + hash.
- `notification_service.dart`: channel baru `kasirgo_delegations` ("Tugas & Delegasi")
  + `kasirgo_doctor` ("Dokter Bisnis"), method `showDelegationNotification` /
  `showDoctorNotification`.
- `app.dart`: `_maybeTriggerAlerts` dipanggil sekali per user (guard `_alertsForUserId`)
  dari `_initialize` & `_listenAuth`, delay 3 dtk agar plugin siap; tap payload
  `delegation:`/`doctor:` -> route ke home sesuai role (payload `report:` tetap).
- Unit test `test/doctor_alert_service_test.dart` 3/3 PASS (fake service + client dummy).
- E2E `e2e/doctor_alerts_verify.mjs` (seed `__ALERT_QA__` + cleanup): owner 2 pengingat
  (rekap+teguran), kasir 1 pengingat, `DelegationTasksCard` tampil, 0 console error.
  `doctor_delegations` & memori uji kembali 0 baris.
- `flutter analyze` bersih; `flutter build web --release --base-href /kasirgo/` sukses.

### Polish Export Excel: Hapus Sheet Kosong "Sheet1" - SELESAI
- `staff_performance_screen.dart` & `report_screen.dart`: setelah
  `setDefaultSheet('Ringkasan')` tambah `if (excel.tables.containsKey('Sheet1')) excel.delete('Sheet1')`
  -> berkas xlsx hanya berisi sheet yang dipakai (performa: Ringkasan + Detail Staf;
  laporan: Ringkasan + Penjualan + Per Produk).
- Verifikasi live Playwright (owner Toko Test): unduh `Performa_Staf_*.xlsx` &
  `Laporan_Keuangan_*.xlsx`, cek `xl/workbook.xml` -> tidak ada `Sheet1`, 0 console error.
  Data uji `__SHEET_QA__` dibersihkan (`doctor_delegations` 0 baris).
- Commit `6bc2eb4` (main) + deploy gh-pages `0e74b07` (md5 `ff456cab2da8df0e645746b6bcd25296`).

### Badge Perhatian di Kartu Dokter Bisnis AI (13.21B lanjutan) - SELESAI
- `owner_home_screen.dart`: `doctorAttentionProvider` (FutureProvider<int>) =
  `DelegationService().summary(outlet)['terlambat']` + 1 bila
  `BusinessDoctorService().getLatestReprimand(outlet) != null` (try/catch -> 0).
- `_pushGated` jadi `Future<void>` async; kartu Dokter Bisnis AI memakai
  `badgeCount: attention`, subtitle `Perlu perhatian (N)` bila > 0, dan
  `ref.invalidate(doctorAttentionProvider)` setelah layar ditutup.
- `_ModuleCard` +`badgeCount` (default 0): overlay `Positioned` badge merah
  (`AppTheme.errorColor`, teks `9+` bila > 9) dibungkus
  `MergeSemantics(Stack[card, ExcludeSemantics(badge)])` sehingga node semantics
  kartu = satu teks "Dokter Bisnis AI\nPerlu perhatian (N)" tanpa label ganda.
- Verifikasi E2E `e2e/doctor_badge_verify.mjs` (seed `__BADGE_QA__` tugas
  terlambat + teguran): `BADGE_LABEL "Dokter Bisnis AI\nPerlu perhatian (2)"`,
  `SUBTITLE Perlu perhatian (2)`, `HAS_CARD true`, `ERRORS 0`. Data uji
  dibersihkan (`doctor_delegations` 0 baris, memori `__BADGE_QA__` 0).
- `flutter analyze` 1 info pre-existing; build web sukses. Commit `eedc7bd` (main)
  + deploy gh-pages `30afe69` (live md5 `34eb04812c623f94ff803792a02cc203`).

### Layar Hasil Pemeriksaan + Simpan/Bagikan PDF & WA (13.21A) - SELESAI
- `lib/utils/doctor_result_pdf.dart` (BARU): `DoctorResultPdf.scoreTone(int?)`
  (rendah/sedang/tinggi), `build({storeName, verdictTitle, verdictBody, score,
  scoreHint, targetDays, dueDate, steps})` -> PDF A4 `pw.MultiPage` (header
  "HASIL PEMERIKSAAN USAHA", box skor 0-100, "A. Vonis Dokter", "B. Peta Resep"
  tabel langkah, "C. Target & Waktu", disclaimer) + `buildText(...)` -> teks WA.
  `score.clamp(0, 100)`; aman untuk `score == null` / `steps` kosong.
- `lib/screens/owner/doctor_result_screen.dart` (sudah ada dari ST14-6 lanjutan)
  dipakai sebagai layar hasil: header + tanggal + ikon dokter, gauge skor
  beranimasi, kartu vonis, peta resep bernomor, target & timeline, footer
  "Mulai Jalankan"/"Simpan / Bagikan"/"Tanya Dokter" (touch 56dp).
- `business_doctor_screen.dart`: `_shareResult(...)` -> bottom sheet
  "Simpan / Bagikan Hasil" berisi "Simpan / Unduh PDF" (`ReceiptGenerator.share`)
  dan "Kirim ke WhatsApp" (`DoctorResultPdf.buildText` + `WaHelper`; bila
  `boss_wa_number` kosong -> snack "Atur nomor WhatsApp bos dulu ya." +
  dialog input nomor `_editBossWa`).
- FIX nama toko di PDF: `storeName` diambil dari `currentUserProvider.name`
  (diisi `outlets.name` oleh AuthService), fallback `getOutlet().businessName`.
  Sebelumnya selalu "Usaha Saya" karena tabel `outlets` tidak punya kolom
  `business_name`.
- FIX plumbing data resep: `supabase/functions/business_doctor_chat/index.ts`
  `save_prescription` kini menyimpan `verdict_body`, `score`, `score_hint` di
  `doctor_memory.content` (sebelumnya hanya verdict/target_days/started_at/steps);
  `business_doctor_service.dart` `_toBlock` + `savePrescription` ikut membaca/
  menulis 3 field itu (`'status': ?status`).
- Test: `test/doctor_result_pdf_test.dart` (4 test) PASS - wajib
  `initializeDateFormatting('id_ID')` di `setUpAll`.
- E2E `e2e/doctor_result_share_verify.mjs` (seed resep `__SHARE_QA__` skor 42):
  `DOCTOR_OPEN/HAS_HEADER/HAS_VERDICT/HAS_BODY/HAS_SCORE42/HAS_RECIPE/
  HAS_STEP2/HAS_SHARE_BTN true`, `PDF_FILENAME Hasil_Diagnosa_21 Okt 2026.pdf`,
  `PDF_STORE/PDF_SCORE/PDF_VERDICT true` (ekstraksi stream PDF in-Node),
  `PDF_SNACK true`, `WA_ASK_PHONE/WA_SAVE_PHONE true`, popup
  `api.whatsapp.com/send?phone=6281234567890&text=...`, `ERRORS 0`.
  Catatan: tombol di bottom sheet harus diklik via JS semantics
  (`clickSemantic`) - mouse click pada tombol paling bawah sheet tidak kena.
- Data uji dibersihkan: `doctor_memory __SHARE_QA__` dihapus,
  `doctor_outlet_profile.boss_wa_number` dikembalikan ke '', delegasi QA 0 baris.
- `flutter analyze` 4 file bersih; `flutter build web --release` sukses.
- FOLLOW-UP: EF `business_doctor_chat` BELUM di-deploy (tidak ada
  `SUPABASE_ACCESS_TOKEN` di sandbox) -> resep baru dari AI belum menyimpan
  verdict_body/score sampai EF dideploy ulang.

### Sidak Bos: Audit Stok & Kas (13.24 #2) - SELESAI
- Migrasi `docs/migrations/2026-11-28-kasirgo-sidak-bos.sql` (DITERAPKAN live):
  tabel `sidak_sessions` (kas + nilai stok + findings JSONB) & `sidak_items`
  (baris selisih fisik per produk), RLS owner via `is_outlet_owner` OR
  `is_platform_admin`; RPC `sidak_cash_summary(outlet, from, to)` (agregat kas
  tunai/non-tunai dari `transactions` paid) dan `sidak_log_action(session)`
  (jejak `doctor_action_logs` action_type `sidak_bos`, outcome
  bersih/ada_selisih) - keduanya SECURITY DEFINER.
- `lib/services/sidak_service.dart` (BARU): model `SidakFinding`,
  `SidakCountRow` (diff/diffValue), `SidakSession` (isClean); service
  `loadCountRows` (produk non-layanan), `cashSummary`, `soldProductIds`
  (stock_logs 7 hari), `autoFindings` (stok minus, tanpa HPP, harga < HPP,
  harga nol, laku tanpa stok), `manualFindings` (kas/stok selisih, severity
  tinggi bila >= Rp50.000), `saveSession` (insert sesi + item selisih saja),
  `logAction`, `listSessions`, `sessionItems`.
- `lib/utils/sidak_report_pdf.dart` (BARU): `verdictLabel` (BERSIH /
  ADA SELISIH / PERLU DITINDAKLANJUTI), PDF A4 (kas laci, nilai stok,
  rincian selisih, temuan, catatan) + `buildText` untuk WhatsApp.
- `lib/screens/owner/sidak_stock_count_screen.dart` (BARU): hitung fisik per
  produk + filter "hanya selisih" + total selisih nilai.
- `lib/screens/owner/sidak_bos_screen.dart` (BARU): tab Sidak Baru/Riwayat,
  kartu kas (periode 1/7/30 hari), kartu stok, temuan otomatis+manual,
  simpan -> dialog hasil (PDF/WA), detail sesi di Riwayat.
  Nomor WA bos dibaca dari `doctor_outlet_profile.boss_wa_number`
  (`BusinessDoctorService.getProfile`), bukan config platform.
- Wiring: `business_doctor_screen.dart` action resep `sidak_bos` ->
  `SupporterFeatureGate('sidak_bos', SidakBosScreen)`; `doctor_blocks.dart`
  label "Sidak Stok & Kas"; `supporter_service.dart` +`sidak_bos` di
  `premiumFeatures`/`featureLabels`; `owner_home_screen.dart` kartu
  "Sidak Stok & Kas" (Icons.fact_check_rounded) via `_pushGated`.
- Test: `test/sidak_bos_test.dart` 13 test PASS (verdictLabel, PDF, buildText,
  model fromJson, diff/diffValue, manualFindings).
- `flutter analyze` 8 file: 1 info pre-existing (`unnecessary_underscores`
  owner_home_screen:700); `flutter build web --release` sukses; deploy
  gh-pages `5227cd1` (live md5 `c11e43967de7f2c0030b824f416b4239` MATCH).

### Dynamic Pricing AI: Atur Harga & Diskon (13.24 #4) - SELESAI
- `lib/utils/dynamic_pricing.dart` (BARU): `DynamicPricing.build(products,
  transactions, {minMarginPercent=15, daysThreshold=30})` -> `DynamicPricingPlan`
  (`discounts`/`lowMargins`/`rankOf`/`productCount`/`transactionCount`).
  Diskon kelas A 10-15%, B 10-25%, C 15-25%; harga tidak boleh di bawah
  modal + margin 15% (floor `cost/(1-minMargin)`), dibulatkan 500, diskon
  minimum 5%; margin tipis (<15%) -> saran kenaikan harga. Basis
  `AIEngine.abcRanking` + `suggestFlashSale`/`checkMargin`.
- `lib/services/dynamic_pricing_service.dart` (BARU): `loadPlan`,
  `applyDiscount` (upsert `product_discounts` 7 hari, `is_flash_sale`),
  `applyPrice` (update `products.base_price`), `logAction`
  (`doctor_action_logs` action_type `dynamic_pricing`, status `done`,
  outcome `diskon_dipasang`/`harga_naik`).
- `lib/screens/owner/dynamic_pricing_screen.dart` (BARU): intro gradient,
  tile ringkasan (Perlu diskon/Margin tipis), kartu diskon (harga coret ->
  harga baru + chip -X%), kartu margin (modal/jual + tombol
  "Naikkan ke Rp..."), badge kelas ABC, empty state "Harga Anda sudah sehat",
  error state + "Coba lagi". Service opsional di constructor (testability).
- Wiring: `business_doctor_screen.dart` `_actionScreen` `dynamic_pricing` ->
  `SupporterFeatureGate` + `DynamicPricingScreen` (dulu `ProductListScreen`);
  `owner_home_screen.dart` kartu "Atur Harga & Diskon" (Icons.price_change_rounded,
  `AppTheme.moduleAccentViolet`) via `_pushGated`; `supporter_service.dart`
  +`dynamic_pricing` di `premiumFeatures`/`featureLabels`; `doctor_blocks.dart`
  label "Atur Harga & Diskon".
- Test: `test/dynamic_pricing_test.dart` 9 test PASS (batas diskon A/B,
  floor modal+margin, margin tipis, harga < modal, tanpa HPP, produk sehat,
  produk jasa, ringkasan plan).
- E2E `e2e/dynamic_pricing_verify.mjs` PASS: kartu beranda -> layar terbuka,
  "Terapkan Diskon" -> baris `product_discounts` 13% + log `diskon_dipasang`;
  "Naikkan ke Rp..." -> `base_price` 10.000 -> 11.000 + log `harga_naik`;
  `ERRORS 0`. Data uji (`__DYN_QA__`/`__DYN_QA2__`) sudah dibersihkan.
- `flutter analyze lib` 22 info (0 warning/error, semua pre-existing);
  `flutter build web --release --base-href /kasirgo/` sukses.

### Progress Tracker: Laporan & Progres (13.24 #6) - SELESAI
- `lib/utils/progress_tracker.dart` (BARU): `ProgressTrend` + `ProgressTrendLabel`
  (label 'membaik'/'masih sama'/'menurun'), `DailySales`, `TrendInfo`,
  `ProgressTrackerReport` (targetProgress/prescriptionProgress, verdict, trendText,
  maxDaily), `ProgressTracker` statis (`dailySales` 30 hari, `trendInfo` 7 vs 7 hari,
  `classify` ambang flat 5%, `monthToDate`, `prescriptionProgress`, `build`, `scoreOf`).
  Skor 0-100 bobot ternormalisasi: tren 40 (up 100/flat 62/down 25), target 30,
  resep 20, aksi 10. Hanya transaksi lunas (`isPaid`; `paymentStatus` kosong = lunas).
- `lib/services/progress_tracker_service.dart` (BARU): `load(outletId)` =
  transaksi 29 hari + `getTargets` + `getActivePrescription` + `doctor_action_logs`
  (60 terakhir) -> `ProgressTracker.build`; `logProgress` insert
  `doctor_action_logs` (`action_type:'progress_tracker'`, status `done`, outcome =
  tren, `result` jsonb skor/tren/omzet/target/resep/aksi).
- `lib/screens/owner/progress_tracker_screen.dart` (BARU): hero gradient skor +
  vonis + tren + omzet 7 hari vs sebelumnya, kartu "Langkah Resep Dokter",
  "Target Omzet", bar chart "Omzet 7 Hari Terakhir", "Aksi Perbaikan", tombol
  "Catat Progres Hari Ini" -> "Progres hari ini sudah dicatat", empty & error state.
- Wiring: `business_doctor_screen.dart` `_actionScreen` `progress_tracker` ->
  `SupporterFeatureGate` + `ProgressTrackerScreen` (menggantikan `ReportScreen`);
  `supporter_service.dart` +`progress_tracker` di `premiumFeatures`/`featureLabels`;
  `owner_home_screen.dart` kartu "Laporan & Progres" (`Icons.insights_rounded`,
  `AppTheme.moduleAccentIndigo`) via `_pushGated`; label `doctor_blocks.dart`.
- Test: `test/progress_tracker_test.dart` PASS (isPaid, classify, dailySales,
  trendInfo, monthToDate, prescriptionProgress, scoreOf, build/verdict, label).
- E2E `e2e/progress_tracker_verify.mjs` PASS: kartu beranda -> layar terbuka
  (hero/skor/tren/kartu resep-target-chart-aksi), "Catat Progres Hari Ini" ->
  snackbar + tombol berubah, baris `doctor_action_logs` `progress_tracker`
  (skor 25, tren down, omzet 7 hari 35.000) tersimpan; cleanup 204, `ERRORS 0`.
- `flutter analyze lib` hanya info pre-existing; `flutter build web --release
  --base-href /kasirgo/` sukses.

### Radar Pembeli Hyper-Local: GPS Lintas Platform + Radius (25 Okt 2026) - SELESAI
- Akar masalah "hanya Toko Test muncul di radar": 8/10 outlet `latitude/longitude`
  NULL karena deteksi lokasi Lapak Live dulu web-only (`dart:html`) -> di APK
  tombol "Deteksi lokasi" tak pernah menyimpan koordinat.
- `lib/utils/geo.dart`: `detectDevicePosition({prompt})` -> web pakai Geolocation
  API (conditional import `geo_stub.dart`/`geo_web.dart`), native pakai
  `geolocator` 12 (`getCurrentPosition(desiredAccuracy: best, timeLimit: 15s)`).
  `prompt:false` untuk broadcast 60 dtk agar tidak memunculkan dialog izin OS.
- `AndroidManifest.xml` + `ACCESS_COARSE_LOCATION`/`ACCESS_FINE_LOCATION`;
  `lapak_live_screen.dart` & `buyer_location_service.dart` memakai helper baru.
- Radar pembeli: chip radius 3/5/10 km (default 10 sesuai
  `radius_default_km`), subtitle "Dalam radius X km dari lokasimu", empty state
  mengarahkan owner menayangkan lewat Lapak Live.
- Migrasi `docs/migrations/2026-10-24-kasirgo-18-tickets-radar.sql`
  (`support_tickets` + radius) sudah diterapkan live.
- E2E Playwright mode Pembeli (`qa.checkout@kasirgo.test`/`sabar2021`):
  `Toko Terdekat` + `Lokasi aktif -6.3950, 106.8410` (auto-detect), chip
  3/5/10 km, `Toko Test` + `Gerobak Test` (20 m) tampil; klik `3 km` ->
  "Dalam radius 3 km dari lokasimu"; `ERRORS 0`.
- Commit `ab24b4d`; deploy gh-pages `2c2e030` (md5 `f14a1fd5...` cocok).
- CATATAN: fix GPS native hanya aktif di APK 1.0.8+9 ke atas (perlu rebuild APK).
