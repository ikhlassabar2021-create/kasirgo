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

RLS: Owner full access outlet sendiri; Admin CRUD produk + read reports; Cashier read produk + insert transaksi.
Triggers: `handle_new_user` auto-create outlet on signup; `decrement_stock` auto-kurang stok on transaction item insert.
Schema SQL lengkap: docs/KASIRGO-WORKFLOW-LENGKAP.md Phase 1.

## Roles
| Role | Akses | Platform |
|------|-------|----------|
| Owner | Full access semua modul | Flutter Mobile |
| Admin | CRUD produk + laporan standar | Flutter Mobile |
| Cashier | Lihat/pilih produk + QRIS manual | Flutter Mobile |
| Customer | Scan QR meja -> order (cafe/resto) | Flutter Mobile |
| Superadmin | User mgmt, impersonate, backup/restore, affiliate, revenue | React Web |

## Subscription Tiers
- **free**: 500 transaksi, 500 produk, CRUD manual, absensi, QRIS manual, AI Co-Pilot, laporan standar, ADA IKLAN
- **basic_25** (Rp25rb): semua free + unlimited tx/produk, scan barcode, generate barcode, QRIS otomatis, notif stok/expired, laporan bank-ready, TANPA IKLAN
- **pro_50** (Rp50rb): semua basic + diskon/promo, flash sale auto, WhatsApp (struk/order/broadcast/CRM auto-retensi), social commerce sync, QR meja, toko online katalog, health score + cashflow, multi-outlet

## AI Co-Pilot (Semua Paket, local compute, Rp0)
Prediksi penjualan (moving average), deteksi anomali (z-score), rekomendasi produk serupa (association rule), ABC ranking (Pareto), margin alert, daily digest, flash sale auto-suggest, best time to sell. Implementasi: `utils/ai_engine.dart`.

## Design System
Lihat selengkapnya: `docs/superpowers/specs/2026-09-08-ui-ux-design.md`
Glassmorphism dark theme. Warna: primary #4F46E5, secondary #7C3AED, accent #06B6D4, bg #0F172A, surface #1E293B. Font: Google Fonts Inter. Min touch target 56dp (primary), 48dp (secondary). Responsive 360dp width.

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
- GITHUB_URL: [isi URL repo]
- SUPABASE_URL & ANON_KEY: placeholder di config/supabase_config.dart, isi manual
- Deployment: React admin ke Vercel. Flutter APK release via flutter build apk --release

## Dokumen Referensi
- Workflow 8 Phase: docs/KASIRGO-WORKFLOW-LENGKAP.md
- Design spec: docs/superpowers/specs/2026-09-08-pos-app-design.md
- PRD: docs/PRD-KasirGo.md
- Implementation plan: docs/superpowers/plans/2026-09-08-kasirgo-implementation.md

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

## Progress Tracker
- [x] Phase 0: Design docs + PRD + workflow
- [x] Phase 1: Supabase DB + Auth
- [ ] Phase 2: Flutter app shell + auth + offline engine  (SEDANG DIKERJAKAN)
- [ ] Phase 3: Produk + POS + QRIS + AI Co-Pilot
- [ ] Phase 4: Laporan + pelanggan + karyawan
- [ ] Phase 5: Premium features + subscription gate
- [ ] Phase 6: WhatsApp + social commerce + QR meja + health score
- [ ] Phase 7: Superadmin web (React + Vercel)
- [ ] Phase 8: Polish + testing + final deploy
