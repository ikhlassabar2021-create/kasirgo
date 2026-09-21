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

## Program Pendukung (bukan langganan) + Kuota Staf
GRATIS SELAMANYA untuk fitur inti. Fitur kosmetik/bonus via Program Pendukung (Pendukung/Pro/Setia).
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
- **Web build:** `flutter build web --web-renderer html` (file statis, deploy ke Cloudflare Pages / shared hosting).
- **Ukuran APK ditekan:** hapus package tidak perlu, gambar WebP bukan PNG, font subset Inter, `proguard-rules.pro`, tree-shaking Dart otomatis.

## Repository & Env
- GITHUB_URL: https://github.com/sabar2023/kasirgo.git
- Remote sudah dikonfigurasi (origin). Branch lokal: master.
- STATUS PUSH: commit terakhir `439e845` (docs: final memori sebelum compact) BELUM ter-push.
  Penyebab: credential helper MonkeyCode mengembalikan status 500 (server-nya error), `gh` belum login, tidak ada SSH key, `ssh` tidak terinstall.
- CARA PUSH (pilih satu):
  A. Buat Personal Access Token (PAT) di https://github.com/settings/tokens (scope: repo untuk classic, atau Contents: Read+Write untuk fine-grained). Lalu:
     git remote set-url origin https://<TOKEN>@github.com/sabar2023/kasirgo.git
     git push -u origin master
  B. Atau: echo "<TOKEN>" | gh auth login --with-token && git push -u origin master
  C. Atau push manual dari terminal lokal sendiri: git push -u origin master (pakai PAT sebagai password).
  Setelah push sukses: HAPUS baris ini dari AGENTS.md (jaga-jaga token jangan tersisa). Status jadi: SUDAH TER-PUSH.
- SUPABASE_URL & ANON_KEY: placeholder di config/supabase_config.dart, isi manual (Phase 2).
- Deployment: React admin ke Cloudflare Pages (BUKAN Vercel). Flutter APK release via flutter build apk --release

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
- [ ] Phase 7.5: Zero-Friction Onboarding + Dual-Mode QRIS + Settlement + Superowner Financial Config  (BERIKUTNYA)
- [ ] Phase 7.6: UI Retrofit "Centennial Modern Ocean White" (semua role + semua fitur, UI-only)
- [ ] Phase 7.7: Control Plane + KYC Auto-Verify + Izin Produk/Staf + Owner Affiliate
- [ ] Phase 8: Modul outlet_type (BOM/Resep, KDS/QR Meja, Variant, Shift/Tip)
- [ ] Phase 9: PPOB + Closed-loop + Embedded B2B Restock
- [ ] Phase 10: Fintech Lead + Hyperlocal Data + Micro-insurance
- [ ] Phase 11: Superadmin Web (12 revenue engine)
- [ ] Phase 12: Polish + Security Audit + Release

Catatan: Phase 7.6 adalah redesign visual menyeluruh (semua dashboard + fitur Produk/Pelanggan/
Karyawan/Laporan/Pengaturan) tanpa mengubah fitur/logic. Spec: workflow Bagian 1.6 & 7C.
Phase 7.7 = Control Plane: semua setting integrasi/margin lewat superadmin tanpa ubah koding. Spec: Bagian 1.10 & 7D.
KYC owner wajib (email/nohp/nama toko/alamat/KTP/selfie) + auto-verify. Spec: Bagian 7D (ST7.7-2).
