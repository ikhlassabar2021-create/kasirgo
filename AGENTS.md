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
- TEMUAN BELUM DIPERBAIKI (butuh akses service_role/DB, tidak tersedia):
  `GET /rest/v1/outlet_staff_quota` -> 404 `PGRST205` (tabel
  `outlet_staff_quota` TIDAK ADA di DB live, padahal `settings_screen.dart`
  ~107 membacanya untuk kartu "Kuota Staff" dan workflow Bagian 3
  mendefinisikannya). Query di dalam try/catch -> gagal senyap, kartu selalu
  0/5. Perlu migrasi `CREATE TABLE outlet_staff_quota` + RLS + backfill.
- Deploy: main 295a15d, gh-pages 0fd1f35 (live md5 main.dart.js MATCH
  eae0b83289debbeece0f8cdf5ec20497; smoke test live: login + nav 0 error).
