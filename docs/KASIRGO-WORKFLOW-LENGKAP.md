# KASIRGO 3.0 - WORKFLOW LENGKAP (MASTER SINGLE FILE)

> Versi: 3.0 (selaras dengan STRATEGI INDUK KASIRGO 3.0, 18 September 2026)
> File ini menggantikan dokumen workflow versi sebelumnya. Semua konteks proyek, schema,
> roadmap, prompt siap pakai, aturan hemat token, dan test checklist ada di sini.
> Satu session = satu sub-task. Copy prompt, tempel, kerjakan, commit, push, Compact.

---

## BAGIAN 1 - RINGKASAN PRODUK (SUMBER KEBENARAN)

### 1.1 Doktrin Bisnis
KasirGo adalah Operating System UMKM Indonesia yang 100% GRATIS SELAMANYA untuk pengguna.
Tidak ada langganan bulanan. Pihak ketiga (Bank, Distributor FMCG, Brand, Platform Finansial)
yang mendanai ekosistem di belakang layar. KasirGo = Software Orchestrator, bukan pemegang uang.

Doktrin: KasirGo tidak menjual software; KasirGo menjual akses & ekosistem. Warung gratis
selamanya, pihak ketiga membayar, arus kas mengalir otomatis.

Prinsip Hukum & Finansial (WAJIB) - ZERO-TOUCH MONEY:
- Patuh PBI No. 23/6/PBI/2021. KasirGo TIDAK PERNAH menampung/menyimpan uang warung di rekening internal.
- Direct settlement via Escrow Account milik Payment Gateway (PG) resmi berizin PJP Bank Indonesia.
- Komisi platform dipotong otomatis oleh PG lewat Split-Payment API (KasirGo tidak menagih/menampung).
- Semua callback webhook transaksi diverifikasi Digital Signature HMAC SHA-256 di Supabase Edge Functions.
- Model: Master Account / Payment Facilitator ke PG (Tripay/Xendit/Duitku/Midtrans).

### 1.2 Segmentasi & Arsitektur Modular (`outlet_type`)
Satu APK dengan modul dinamis berdasarkan `outlets.outlet_type`:
- `kelontong` (warung): Grosir Mode, Catat Kasbon, Barcode Quick
- `warteg` (warteg/warkop): Mode Porsi/Menu, Kitchen Display, Shift Kasir
- `cafe` (cafe/resto): BOM & Resep HPP, QR Meja Order, Split Bill/Tip
- `retail` (retail/fashion): Barcode Scan, Multi-Variant, Clienteling CRM

### 1.3 12 Revenue Engine (pihak ketiga yang bayar)
1. Dynamic QRIS Take-Rate (0.1-0.3% nilai transaksi) - Payment Gateway/Bank
2. Brand-Sponsored Receipts (kupon FMCG di struk WA)
3. Embedded B2B Restock Engine (komisi 1-3% belanja stok via WebView anti-bypass)
4. Fintech & Credit Lead-Gen (1-2% nilai pinjaman cair)
5. Margin PPOB API (pulsa/PLN/BPJS via Digiflazz/IAK/RCB)
6. Micro-Insurance Toko (komisi 15-30% premi)
7. B2B Clearance Marketplace (obral near-expiry, komisi 3-5%)
8. DOOH Screen Display Ads
9. Hyperlocal Data Intelligence (laporan tren agregat anonim)
10. Hardware Bundling (margin 20-40%)
11. WhatsApp Credit Margin (Rp100/pesan)
12. Program Pendukung (kosmetik opsional)

### 1.4 Program Pendukung (BUKAN langganan)
Semua fitur inti gratis. Hanya fitur kosmetik/bonus yang bisa didukung:
- Pendukung Rp10.000: badge + Hall of Fame + hapus iklan kecil di struk
- Pendukung Pro Rp25.000: + tema eksklusif + logo toko di struk + prioritas support
- Pendukung Setia Rp50.000: + laporan lanjutan (cashflow/tren) + export Excel/PDF + backup harian
- Kuota akun staf GRATIS per outlet: **1 Admin + 1 Kasir**. Owner bisa create & hapus sendiri.
  Butuh lebih banyak akun staf -> buka Program Pendukung (bukan langganan, sekali dukung).

### 1.5 Roles
| Role | Akses | Platform |
|------|-------|----------|
| Owner | Full akses semua modul outlet + kelola staf + affiliate | Flutter Mobile |
| Admin | Tambah/edit produk + laporan (TIDAK bisa hapus produk) | Flutter Mobile |
| Cashier | POS + shift + tip | Flutter Mobile |
| Kitchen | Kitchen Display (KDS) | Flutter Mobile |
| Customer | Scan QR meja -> order | Flutter Mobile |
| Superadmin | 12 revenue engine, user mgmt, data | React Web |

Aturan izin kunci (ditegakkan di RLS + UI, keduanya wajib):
- **Produk**: Owner tambah/edit/HAPUS. Admin tambah/edit saja -- tombol hapus disembunyikan + RLS menolak DELETE.
- **User staf**: hanya Owner yang create/delete Admin & Kasir (kuota gratis 1 Admin + 1 Kasir; lebih -> Program Pendukung).
- **Affiliate**: hanya Owner melihat link affiliate, rekening bank pencairan, dan laporan closing komisi.
- **Pembayaran**: Owner boleh pasang QRIS statis (upload gambar) atau aktifkan gateway dinamis (via superadmin).

### 1.6 Design System v2 - "Centennial Modern Ocean White" (WAJIB, GANTI TOTAL)
Menggantikan dark Glassmorphism. Referensi layout: pola dashboard kasirmurah.com
(hero gradient, kartu stat, grid modul, drawer berkelompok, filter waktu), warna diganti
ke palet Ocean White KasirGo. Semua role (Owner/Admin/Cashier/Kitchen/Customer + Superadmin
Web) memakai sistem yang sama. Berlaku juga untuk produk, pelanggan, karyawan, laporan,
pengaturan. UI-only: DILARANG mengubah fitur/logic/schema/provider/route.

Gaya: Centennial Modern Ocean White + Clean Light Glassmorphism. Tujuan: bersih, terang,
tidak melelahkan mata, proporsional di tablet & desktop (tidak melar/stretched).

Token warna (satu sumber: `config/app_theme.dart` + `tailwind.config.js` admin):
| Token | Nilai |
|-------|-------|
| background | `#F8FAFC` (Slate 50 / Centennial White) |
| surface / card | `#FFFFFF` + border `#E2E8F0` |
| primary | `#0284C7` s/d `#0369A1` (Ocean Sky / Deep Cyan) |
| gradient sekunder | `#06B6D4` -> `#0284C7` |
| text primer | `#0F172A` |
| text sekunder | `#64748B` |
| sukses / aman / untung | `#10B981` |
| peringatan / kasbon / menipis | `#F59E0B` |
| error / habis / void | `#EF4444` |
| badge AI & Insight | gradient `#06B6D4` -> `#4F46E5` |
Font Google Fonts Inter. Radius kartu 16, radius tombol 12, shadow halus elegan (bukan glow).
Min touch target 56dp (primary), 48dp (secondary).

Breakpoint responsif: Mobile 360-599dp, Tablet 600-859dp, Desktop >= 860dp.
- Desktop (>=860dp): sidebar kiri tetap 240dp putih + border kanan `#E2E8F0` (Brand Header
  icon-box gradient + label "KasirGo POS"; nav Dashboard, Produk, POS, Laporan, Pelanggan,
  Karyawan, Pengaturan; footer profil user). Header bar atas 60dp (judul modul aktif + lonceng
  notifikasi + badge counter AI/stok merah). Konten `Center(ConstrainedBox(maxWidth: 1100))`.
  Form sub-screen (Tambah/Edit Produk dll) `maxWidth: 760` dan tetap di dalam shell
  `OwnerHomeScreen` supaya sidebar tidak hilang. Bottom navigation = null.
- Mobile (<860dp): Top bar glassmorphism translucent (tombol drawer + aksi cepat) + Drawer
  dengan header profil, search "Mau cari menu apa?", seksi UTAMA / OPERASIONAL, tombol Keluar
  (merah), footer versi. Bottom nav frosted glass (`BackdropFilter blur 20`) 7 item.

Pola dashboard utama (semua role): hero card gradient (judul periode + nilai omzet besar +
jumlah produk terjual), deret filter waktu chip (Hari Ini, Kemarin, Minggu Ini, Minggu lalu,
Bulan Ini, Bulan lalu, 3 Bulan Terakhir), grid kartu statistik (Potensi Untung, Belum Bayar,
Produk Terjual, Perlu Cek Stok), lalu grid kartu shortcut modul. Fitur yang belum aktif diberi
badge "Segera" (tampil tapi disabled), bukan dihapus.

Kartu katalog & POS: grid 4 kolom (`crossAxisCount: 4`), `childAspectRatio: 0.95`, thumbnail
1:1, nama maks 2 baris (12-13px semi-bold), harga tebal format rupiah, badge stok di pojok
(Hijau >10, Kuning 1-10, Merah 0). Tablet 3 kolom, Mobile 2 kolom.

Pola layar kunci (mengikuti referensi):
- Produk: baris chip pintasan (Kategori, Stok, Harga, Supplier, Penerimaan Stok), header
  "N Jenis Produk" + tombol Urutkan, field cari, chip filter kategori (mis. "Semua"), lalu
  daftar kartu produk (thumbnail, nama, badge status, harga tebal, barcode, info stok).
- POS / Keranjang: pemilih outlet (kartu gradient), toggle Offline/Toko, baris Pelanggan +
  tombol tambah, item (checkbox, thumbnail, nama, stok, harga + ikon edit, stepper qty),
  "Total Tagihan", dan dua aksi: "Atur Belum Bayar" (outlined) + "Lanjut Pembayaran" (filled).
- Warna hijau pada referensi diganti ke palet Ocean White (primary #0284C7 / gradient
  #06B6D4->#0284C7); item bottom nav aktif memakai primary + label tebal.

Elemen pendukung lain (semua dari 11 referensi):
- Header sub-screen: panah kembali + judul tebal, permukaan putih.
- Layar Kasir: kartu outlet + kartu toggle Offline/Toko, header "Pilih Produk/Paket" +
  tombol Urutkan (mis. "Harga"), field cari, chip filter, baris produk dengan radio pilih;
  bar aksi bawah tetap: "Scan Produk" (outlined) + "Keranjang" (filled, ada badge qty).
- Layar Pembayaran: banner status penuh lebar (merah "BELUM LUNAS" / hijau "LUNAS"), daftar
  baris info (Kasir, Tanggal Penjualan, Metode Pembayaran) masing-masing dengan tautan "Ubah",
  blok "Informasi Pelanggan", lalu grid aksi 2x2 (Cetak Struk, Beranda, Kembali, Konfirmasi;
  Konfirmasi = primary filled).
- Modal struk: bottom sheet/modal (Cetak Struk, Convert PDF, Simpan Gambar), pilihan ukuran
  kertas radio 58mm/80mm, tombol Kembali, plus preview struk.
- Form Produk (Tambah/Edit, maxWidth 760): seksi berjudul tebal, OutlinedTextField, dropdown
  kategori, input barcode dengan ikon scan, Harga Modal / Harga Jual Toko (Offline), deskripsi
  multiline, kotak unggah "Gambar Produk" bergaris putus-putus, seksi "Opsi Lanjutan" yang bisa
  dibuka (Harga Jual Online, toggle Produk Dijual), tombol primary penuh lebar (Tambah/Simpan)
  menempel di bawah.
- Scan Kasir: info Outlet, segmented toggle "Kamera" / "Alat Scanner", viewport kamera gelap
  dengan hint, bar Total (N item) + nominal, tombol penuh lebar "Lanjut ke Keranjang".

10 modul bisnis di grid dashboard utama: Buku Kasbon (`DebtScreen`), PPOB & Pulsa (`PpobScreen`),
Kulakan B2B (`RestockScreen`), Kitchen Display (`KitchenDisplayScreen`), WA Marketing
(`WhatsappBroadcastScreen`), Social Commerce (`SocialCommerceScreen`), QR Meja Dine-in
(`QrTableScreen`), Katalog Online (`OnlineCatalogScreen`), Health Score Bisnis
(`HealthScoreScreen`), Pendukung KasirGo (`SupporterScreen`).

Aturan implementasi (feature-preserving retrofit - lihat Phase 7.6):
- Utamakan komponen bersama di `widgets/common/` (`app_shell.dart`, `stat_card.dart`,
  `hero_card.dart`, `module_tile.dart`, `section_header.dart`, `status_badge.dart`,
  `empty_state.dart`, `price_text.dart`). Screen tidak boleh menyalin styling sendiri.
- Ubah hanya lapisan visual (warna, layout, spacing, komponen). Jangan sentuh provider,
  service, model, schema, query, route, atau alur bisnis.

### 1.7 Tech Stack & Kebijakan Data
- Flutter (Dart) single APK multi-role, offline-first
- React.js + Vite + Tailwind superadmin (deploy Cloudflare Pages, BUKAN Vercel)
- Supabase PostgreSQL + Auth (email + Anonymous) + RLS + Edge Functions + Realtime
- Payment Gateway: Master Account / Payment Facilitator ke PG resmi berizin PJP BI
  (Tripay/Xendit/Duitku/Midtrans); direct settlement via escrow + split-payment API
- Arsitektur data 3 lapis: HOT (SQLite SQLCipher di HP) -> WARM (Supabase 30-90 hari) -> COLD (Cloudflare R2)
- Foto produk LOKAL saja (`image_local_path`). Thumbnail online opt-in ke R2 (`thumb_key`) hanya untuk katalog/QR menu. R2, bukan Supabase Storage.
- AI Co-Pilot 95% local compute (Edge AI, Rp0)
- Sync pakai background Isolate + delta log (event-sourcing) untuk multi-kasir
- Security: SQLCipher, flutter_secure_storage, obfuscation, `service_role` HANYA di Edge Function

### 1.8 Dependencies (pubspec.yaml)
Saat ini: supabase_flutter, drift, sqlite3_flutter_libs, path_provider, go_router,
flutter_riverpod, shared_preferences, intl, mobile_scanner, qr_flutter, barcode, pdf,
printing, excel, url_launcher, connectivity_plus, google_fonts, flutter_animate,
flutter_slidable, fl_chart, cached_network_image, image_picker.

Tambahan 3.0: `sqlcipher_flutter_libs` (enkripsi DB), `flutter_secure_storage` (token),
`webview_flutter` (Embedded B2B Restock).

### 1.9 File Structure
```
kasirgo/lib/
  main.dart, app.dart
  config/ (supabase_config, app_theme, constants)
  models/
  services/
  providers/
  screens/auth|owner|admin|cashier|kitchen|customer/
  widgets/common/pos/
  utils/
kasirgo/supabase/functions/
  stock_alert/  webhook_qris/
kasirgo-admin/src/
```

### 1.10 Control Plane (SEMUA setting lewat Superadmin, TANPA ubah kodingan)
Prinsip: nilai integrasi & margin disimpan di DB (`platform_integrations` + `platform_financial_configs`),
di-cache app, ada fallback default. Ganti nilai = cukup edit di web superadmin.

Yang wajib bisa diset dari superadmin:
| Grup | Isi setting |
|------|-------------|
| Payment Gateway | link/api key PG (Duitku dll), nomor biaya yang dikenakan, margin KasirGo, setting transfer pencairan |
| PPOB | api key (Digiflazz/IAK/RCB), modal, **margin persentase** -> harga jual semua produk PPOB auto ikut harga terbaru |
| B2B Kulakan | link affiliate distributor -> dipakai `RestockScreen` di dashboard owner; ubah link cukup edit di sini |
| Affiliate | komisi dari pembayaran Program Pendukung (upgrade) + sistem pencairan komisi otomatis |
| Fintech | link akun partner fintech/insurtech |
| Storage/Hosting | koneksi Cloudflare R2 (bucket + key) |
| Database | url, user, password, api key koneksi (mis. Supabase) |
| WA Marketing | api key WA Business (Cloud API) |
| Verifikasi | auto-verify pendaftar yang datanya lengkap (email, nohp, nama toko, alamat, KTP, selfie) |

---

## BAGIAN 2 - ATURAN UMUM & HEMAT TOKEN

### 2.1 Aturan Umum
1. Satu session = satu sub-task. Jangan gabung.
2. Push tiap 1-2 file: `git add . && git commit -m "progress: [file]" && git push`.
3. Baca `AGENTS.md` + `PROGRESS-PHASE*.md` saja sebagai konteks. Jangan baca semua file.
4. Update Progress Tracker di `AGENTS.md` tiap phase selesai.
5. Testing cepat: `flutter run -d web-server --web-renderer html --web-hostname 0.0.0.0 --web-port 8080`.
6. APK target <10MB per ABI: `--split-per-abi --obfuscate --split-debug-info=build/debug-info`.
7. Foto produk LOKAL (`image_local_path`), tidak upload Supabase.

### 2.2 Hemat Token (WAJIB)
- Flutter sudah terinstall. Jangan install ulang / flutter doctor / pub get / build APK.
- Perintah panjang redirect ke file. Analyze per file: `dart analyze <file> 2>&1 | tail -20`.
- JANGAN baca file/dokumen yang tidak relevan.
- Output kode saja, tanpa penjelasan/komentar/echo isi file.
- Edit targeted, jangan rewrite file penuh.
- Jangan bolak-balik revisi file yang sama.
- Ganti phase: push -> Compact. Pakai Reset hanya kalau Compact ngawur atau context penuh.
- Di dalam phase: Compact tiap sub-task selesai (bukan reset).
- Jangan paste output panjang (log build, dump file) ke chat.

### 2.2b Budget Token Global (target: Phase 7.5 s/d 12 selesai < 10 juta token)
- 1 sub-task = 1 session; Compact tiap sub-task, Reset saat ganti phase.
- Baca HANYA file yang diedit + `PROGRESS-PHASE*.md`; jangan scan seluruh repo.
- Wajib pakai komponen bersama (`widgets/common/`); retrofit tidak boleh styling ulang per screen.
- Sub-task menyentuh >3 screen -> pecah; <1 file -> gabung dengan sub-task sebelah.
- Transkrip 1 session > ~150k token -> STOP, push, Compact, lanjut.
- Jangan ulang grep/analisa yang sama; catat temuan ke PROGRESS agar tidak dibaca berulang.
- Output hanya diff/kode; screenshot & log disimpan ke file, bukan ditempel ke chat.
- Realistis: retrofit 7.6 (8 sub-task) + sisa phase 8-12 harus tetap hemat; bila melebihi
  budget, kurangi cakupan per session (bukan menaikkan budget).

### 2.3 Error Playbook
Tidak tahu lokasi error:
```
1. dart analyze lib 2>&1 | grep -i error | head -20          # compile: langsung file:baris
2. grep -nE "Error|Exception|Failed" /tmp/run.log | head -15  # runtime
3. Layar blank -> console browser F12, kirim 1 baris pertama saja
4. Persempit: buka 1 screen langsung, isolasi per tab
```
Template perbaikan:
```
=== PERBAIKAN ===
File: [path]
Error: [1-3 baris saja]
Perbaiki HANYA baris/fungsi ini. Jangan baca file lain, jangan refactor, jangan rewrite.
Output hanya diff. dart analyze file itu. STOP.
```
Stop-loss: error sama >2x -> STOP, push, tulis `BLOCKER:` di PROGRESS, Compact/Reset.

### 2.4 PROMPT PEMBUKA UNIVERSAL (tempel di awal SETIAP sub-task)
```
=== KONTEKS KASIRGO 3.0 ===
KasirGo: OS UMKM Indonesia, GRATIS SELAMANYA (tanpa langganan). Flutter + Supabase + offline SQLite.
Role: Owner(full)/Admin(produk+laporan)/Cashier(POS+shift+tip)/Kitchen(KDS)/Customer(QR meja)/Superadmin(web).
Modular per outlet_type: kelontong/warteg/cafe/retail. Foto produk LOKAL (image_local_path).
Design v2 "Centennial Modern Ocean White" (Bagian 1.6): bg #F8FAFC, surface #FFFFFF + border
#E2E8F0, primary #0284C7, gradient #06B6D4->#0284C7, teks #0F172A/#64748B, font Inter.
Pakai komponen bersama `widgets/common/`; DILARANG hardcode warna. UI-only: jangan ubah fitur/logic.
Monetisasi dari pihak ketiga (QRIS gateway, sponsored receipt, B2B restock, PPOB, fintech), bukan user.

=== ATURAN HEMAT TOKEN ===
Flutter terinstall; jangan install/pub get/build APK. Baca HANYA PROGRESS file phase ini.
Output hanya kode, tanpa komentar/penjelasan/echo file. Edit targeted, jangan rewrite.
Perintah panjang redirect ke file. Analyze per file: dart analyze <f> 2>&1|tail -20.
Selesai: git add . && git commit -m "progress: [f]" && git push, lalu STOP.

=== ERROR ===
analyze dulu; kirim HANYA file:baris:pesan (bukan stack trace/log penuh); 1 error/percobaan;
error sama >2x -> STOP, push, tulis BLOCKER, laporkan.
```
Cara pakai: tempel PROMPT PEMBUKA UNIVERSAL, lalu blok `=== SUB-TASK ... ===` di bawahnya, jadi satu pesan.
Prompt siap-tempel per sub-task (7.5 -> 7.7 -> 7.6 -> 8-12): `docs/PROMPT-GILIRAN.md`.

---

## BAGIAN 3 - DATABASE SCHEMA 3.0

### 3.1 Perubahan tabel existing
- `outlets`: rename `type` -> `outlet_type` (enum kelontong/warteg/cafe/retail); HAPUS `subscription_tier`, `subscription_expiry`; tambah `merchant_id UUID REFERENCES merchants(id)`, `device_uuid TEXT`.
- `user_roles`: role CHECK tambah `kitchen`.
- `products`: tetap. Tambah `has_variants BOOLEAN DEFAULT false`.
- `transactions`: tambah `merchant_id UUID`, `pg_reference_id TEXT` (kanonik; `gateway_ref` alias lama), `qris_type TEXT` (STATIC/DYNAMIC), `payment_status TEXT DEFAULT 'PENDING'` (PENDING/PAID/EXPIRED/CANCELLED), `gross_amount DECIMAL(12,2)`, `mdr_fee_deducted DECIMAL(12,2) DEFAULT 0`, `kasirgo_margin_deducted DECIMAL(12,2) DEFAULT 0`, `net_amount_to_merchant DECIMAL(12,2) DEFAULT 0`, `settlement_status TEXT DEFAULT 'n/a'` (UNSETTLED/SETTLED/PPOB_USED), `tip_amount DECIMAL(12,2) DEFAULT 0`, `shift_id UUID`, `debt_id UUID`, `sync_status TEXT DEFAULT 'synced'`, `event_id TEXT`, `device_id TEXT`.
- `transaction_items`: tambah `variant_id UUID`, `note TEXT`.
- `employees`: tetap untuk absensi; shift pindah ke `shifts`.
- `subscriptions`: OBSOLETE -> ganti `supporters` + `supporter_benefits`.
- `affiliates` / `affiliate_referrals`: repurpose jadi referral Program Pendukung.
- `customers`, `product_prices`, `product_discounts`, `ai_insights`: tetap.

### 3.2 Tabel baru
```
CREATE TABLE supporters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  tier TEXT NOT NULL CHECK (tier IN ('pendukung','pro','setia')),
  start_date TIMESTAMPTZ DEFAULT NOW(),
  end_date TIMESTAMPTZ,
  amount DECIMAL(12,2) DEFAULT 0,
  status TEXT DEFAULT 'active'
);

CREATE TABLE supporter_benefits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  benefit_key TEXT NOT NULL,
  enabled BOOLEAN DEFAULT true,
  UNIQUE(outlet_id, benefit_key)
);

CREATE TABLE product_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  sku TEXT,
  price_delta DECIMAL(12,2) DEFAULT 0,
  stock DECIMAL(12,2) DEFAULT 0
);

CREATE TABLE stock_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id),
  variant_id UUID,
  delta DECIMAL(12,2) NOT NULL,
  reason TEXT NOT NULL,
  ref_id UUID,
  device_id TEXT,
  event_id TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE debts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES customers(id),
  transaction_id UUID REFERENCES transactions(id),
  amount DECIMAL(12,2) NOT NULL,
  paid_amount DECIMAL(12,2) DEFAULT 0,
  status TEXT DEFAULT 'unpaid' CHECK (status IN ('unpaid','partial','paid')),
  due_date DATE,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE debt_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  debt_id UUID REFERENCES debts(id) ON DELETE CASCADE,
  amount DECIMAL(12,2) NOT NULL,
  paid_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  shift TEXT DEFAULT 'pagi',
  opened_at TIMESTAMPTZ DEFAULT NOW(),
  closed_at TIMESTAMPTZ,
  opening_cash DECIMAL(12,2) DEFAULT 0,
  closing_cash DECIMAL(12,2)
);

CREATE TABLE tips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  transaction_id UUID REFERENCES transactions(id),
  user_id UUID REFERENCES auth.users(id),
  amount DECIMAL(12,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  yield_qty DECIMAL(12,2) DEFAULT 1
);

CREATE TABLE recipe_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id UUID REFERENCES recipes(id) ON DELETE CASCADE,
  ingredient_product_id UUID REFERENCES products(id),
  qty DECIMAL(12,2) NOT NULL
);

CREATE TABLE ppob_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sku TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  category TEXT,
  cost_price DECIMAL(12,2),
  sell_price DECIMAL(12,2)
);

CREATE TABLE ppob_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  ppob_product_id UUID REFERENCES ppob_products(id),
  customer_ref TEXT,
  amount DECIMAL(12,2) NOT NULL,
  status TEXT DEFAULT 'pending',
  provider_ref TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE restock_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  distributor TEXT,
  tracking_id TEXT,
  amount DECIMAL(12,2) DEFAULT 0,
  status TEXT DEFAULT 'draft',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE fintech_leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  partner TEXT,
  amount_requested DECIMAL(12,2),
  status TEXT DEFAULT 'lead',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE receipt_sponsors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand TEXT NOT NULL,
  image_key TEXT,
  target_url TEXT,
  region TEXT,
  active_from TIMESTAMPTZ,
  active_to TIMESTAMPTZ,
  impression_count INTEGER DEFAULT 0
);

CREATE TABLE merchants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_uuid VARCHAR(100) UNIQUE NOT NULL,
  store_name VARCHAR(150) NOT NULL DEFAULT 'Warung Saya',
  owner_name VARCHAR(100),
  owner_ktp VARCHAR(20),
  payout_bank_code VARCHAR(20),
  payout_account_number VARCHAR(50),
  payout_account_name VARCHAR(100),
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE platform_financial_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  min_qris_amount NUMERIC DEFAULT 1000,
  max_qris_amount NUMERIC DEFAULT 10000000,
  qris_free_threshold NUMERIC DEFAULT 500000,
  qris_base_mdr_percent NUMERIC DEFAULT 0.3,
  kasirgo_margin_percent NUMERIC DEFAULT 0.1,
  kasirgo_margin_flat NUMERIC DEFAULT 0,
  fee_bearer VARCHAR(20) DEFAULT 'MERCHANT',
  min_disbursement_amount NUMERIC DEFAULT 50000,
  disbursement_fee_standard NUMERIC DEFAULT 2500,
  disbursement_fee_instant NUMERIC DEFAULT 3500,
  auto_settlement_schedules TEXT[] DEFAULT ARRAY['12:00','19:00'],
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id)
);

CREATE TABLE settlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  batch_ref TEXT,
  total_net NUMERIC DEFAULT 0,
  status TEXT DEFAULT 'pending',
  scheduled_at TIMESTAMPTZ,
  settled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE disbursements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  mode TEXT DEFAULT 'standard' CHECK (mode IN ('standard','instant')),
  fee NUMERIC DEFAULT 0,
  status TEXT DEFAULT 'pending',
  provider_ref TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Control Plane: satu tempat semua konfigurasi integrasi (ganti di superadmin, tanpa kodingan)
CREATE TABLE platform_integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,          -- pg_duitku | ppob_digiflazz | b2b_distributor | fintech_partner
                                     -- | cloudflare_r2 | db_connection | wa_business | affiliate
  label TEXT,
  base_url TEXT,
  public_config JSONB DEFAULT '{}',  -- aman ke client (mis. link affiliate distributor B2B)
  secret_config JSONB DEFAULT '{}',  -- api key/password; client TIDAK boleh baca
  is_active BOOLEAN DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id)
);

CREATE TABLE outlet_kyc (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  full_name TEXT, phone TEXT, email TEXT, store_name TEXT, store_address TEXT,
  ktp_image_path TEXT,          -- LOKAL di HP (kebijakan foto lokal)
  selfie_ktp_image_path TEXT,   -- LOKAL di HP
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','verified','rejected')),
  auto_verified BOOLEAN DEFAULT false,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE outlet_staff_quota (
  outlet_id UUID PRIMARY KEY REFERENCES outlets(id) ON DELETE CASCADE,
  max_admin INT DEFAULT 1,
  max_cashier INT DEFAULT 1,
  extra_from_supporter BOOLEAN DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE affiliate_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  amount NUMERIC DEFAULT 0,
  bank_name TEXT, bank_account_no TEXT, bank_account_name TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','processing','paid')),
  provider_ref TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 3.3 Trigger/Function
- `handle_new_user`: UBAH, isi `outlet_type` dari `user_metadata`.
- Onboarding owner: Anonymous Auth + `device_uuid` -> auto-create `merchants` + default `outlets`
  (<1 detik). **Wajib lengkapi KYC** sebelum transaksi: email, nohp, nama toko, alamat toko, upload KTP,
  foto selfie memegang KTP (semua LOKAL di HP, hanya nilai verifikasi) -> `outlet_kyc`.
- Auto-verify: jika 6 data KYC lengkap + format valid -> set `status='verified'`, `auto_verified=true`
  (Edge Function). Tidak perlu review manual; admin hanya menangani kasus rejected.
- `decrement_stock`: UBAH, tulis juga ke `stock_logs` (event-sourcing).
- Edge Function `webhook_qris`: verifikasi HMAC SHA-256, update status transaksi LUNAS.
- Edge Function `stock_alert`: cek stok menipis + expired, insert `ai_insights`.
- Cron `auto_settlement`: batch settlement PG sesuai `auto_settlement_schedules` (default 12:00 & 19:00 WIB).

### 3.4 RLS
Pola tetap: Owner full akses outlet sendiri; Admin tambah/edit produk + laporan (DELETE produk DITOLAK);
Cashier POS + insert; Kitchen read order; Superadmin via service key (Edge Function). Terapkan pola yang sama ke
semua tabel baru berbasis `outlet_id`.
- `platform_financial_configs`: superowner full access (`auth.jwt()->>'role'='superowner'`); app client SELECT-only.
- `merchants` / `settlements` / `disbursements`: merchant hanya akses baris miliknya; superowner full access.
- `platform_integrations`: superowner full access; app client hanya boleh SELECT `public_config` (kolom
  `secret_config` TIDAK diekspos ke client -- akses via Edge Function/service key saja).
- `outlet_kyc`: Owner hanya outlet sendiri (read/insert/update); Superadmin full.
- `outlet_staff_quota` / `affiliate_payouts`: Owner read outlet sendiri; Superadmin full; tulis payout via Edge Function.
- Produk DELETE policy: izinkan hanya jika `auth.jwt()->>'role' IN ('owner','superowner')`.
- Kolom margin/fee (`mdr_fee_deducted`, `kasirgo_margin_deducted`, `net_amount_to_merchant`) hanya ditulis server (Edge Function), tidak dari client.

---

## BAGIAN 4 - ROADMAP PHASE

| Phase | Nama | Status |
|-------|------|--------|
| 1 | Supabase DB + Auth | SELESAI |
| 2 | Flutter App Shell + Auth + Offline Engine | SELESAI |
| 3 | Produk + POS + QRIS manual + AI Co-Pilot | SELESAI |
| 4 | Laporan + Pelanggan + Karyawan | SELESAI |
| 5 | Premium Features + Subscription Gate | SELESAI (sebagian OBSOLETE) |
| 5.5A | Retrofit 3.0: DB migration + models/services | SELESAI |
| 5.5B | Retrofit 3.0: UI (hapus subscription, dynamic module, kasbon dasar) | SELESAI |
| 5.5C | Retrofit 3.0: Security (SQLCipher + secure storage) + sync event-sourcing | SELESAI |
| 6 | Kasbon/Piutang + WA + Sponsored Receipt | SELESAI |
| 7 | Dynamic QRIS Payment Gateway + webhook HMAC | SELESAI |
| **7.5** | **Zero-Friction Onboarding + Dual-Mode QRIS + Settlement/Disbursement + Superowner Financial Config** | **MULAI DI SINI** |
| 7.6 | UI Retrofit "Centennial Modern Ocean White" (semua role + semua fitur) | |
| 7.7 | Control Plane (setting superadmin tanpa kodingan) + KYC Auto-Verify + Izin Produk/Staf + Owner Affiliate | |
| 8 | Modul outlet_type: BOM/Resep, KDS/QR Meja, Variant, Shift/Tip | |
| 9 | PPOB + Closed-loop + Embedded B2B Restock | |
| 10 | Fintech Lead + Hyperlocal Data + Micro-insurance | |
| 11 | Superadmin Web (12 revenue engine) | |
| 12 | Polish + Security Audit + Release | |

Catatan: porsi yang OBSOLETE dari Phase 5 dan harus dibuang di 5.5B: subscription gate
(free/basic_25/pro_50), iklan banner free tier, limit 500 produk/transaksi.

---

## BAGIAN 5 - PHASE 5.5A (DB MIGRATION + MODELS/SERVICES)

PROGRESS-PHASE5.5.md:
```
# PROGRESS PHASE 5.5
SELESAI: -
BERIKUTNYA: ST5.5A-1 migration SQL
BLOCKER: -
```

Sub-task:

ST5.5A-1 (migration SQL)
```
=== SUB-TASK ST5.5A-1 ===
Buat docs/migrations/2026-09-18-kasirgo-3.0.sql berisi:
- ALTER outlets: rename type -> outlet_type, drop subscription_tier & subscription_expiry
- ALTER user_roles: tambah role 'kitchen'
- ALTER products: tambah has_variants
- ALTER transactions: tambah gateway_ref, settlement_status, tip_amount, shift_id, debt_id, sync_status, event_id, device_id
- ALTER transaction_items: tambah variant_id, note
- CREATE TABLE: supporters, supporter_benefits, product_variants, stock_logs, debts, debt_payments,
  shifts, tips, recipes, recipe_items, ppob_products, ppob_transactions, restock_orders,
  fintech_leads, receipt_sponsors (lihat BAGIAN 3 dokumen ini)
- CREATE INDEX pada outlet_id tiap tabel baru
File ini tidak perlu flutter analyze. commit+push, STOP.
```

ST5.5A-2 (models)
```
=== SUB-TASK ST5.5A-2 ===
Buat/ubah model Dart (fromJson/toJson, fromMap/toMap):
- ubah models/outlet.dart -> tambah outletType, hapus subscriptionTier/Expiry
- ubah models/transaction.dart -> tambah field gateway/settlement/tip/shift/debt/sync/event/device
- ganti models/subscription.dart jadi models/supporter.dart (tier pendukung/pro/setia)
- BARU: models/debt.dart, models/shift.dart, models/tip.dart, models/recipe.dart,
  models/variant.dart, models/ppob.dart, models/restock.dart
commit+push, analysis per file, STOP.
```

ST5.5A-3 (services)
```
=== SUB-TASK ST5.5A-3 ===
- ubah services/supabase_service.dart: tambah CRUD tabel baru; subscriptions -> supporters
- ubah services/local_db_service.dart: tambah tabel lokal debts, stock_logs, ppob_transactions; gate sync_status
- ubah services/sync_service.dart: siapkan struktur delta log/event_id (implementasi penuh di 5.5C)
commit+push, analysis per file, STOP.
```

ST5.5A-4 (providers)
```
=== SUB-TASK ST5.5A-4 ===
- ganti providers/subscription_provider.dart -> supporter_provider.dart
- ubah providers/outlet_provider.dart -> expose outletType untuk module switcher
- BARU: providers/module_provider.dart (module aktif berdasarkan outletType)
commit+push, analysis per file, STOP.
```

---

## BAGIAN 6 - PHASE 5.5B (UI RETROFIT)

ST5.5B-1 (buang subscription/iklan/limit)
```
=== SUB-TASK ST5.5B-1 ===
- ubah screens/owner/settings_screen.dart: hapus subscription gate -> tampilkan Program Pendukung (Pendukung/Pro/Setia) + status
- hapus banner iklan free tier dari owner_home dan screen lain (grep "iklan"/"banner")
- hapus limit 500 produk (product_list) dan limit 500 transaksi (pos)
- hapus utils/subscription_gate.dart atau repurpose ke supporter_gate
commit+push, analysis per file, STOP.
```

ST5.5B-2 (dynamic module switcher)
```
=== SUB-TASK ST5.5B-2 ===
- ubah screens/owner/owner_home_screen.dart: tampilkan modul sesuai outletType
  (kelontong: Grosir+Kasbon+Barcode; warteg: Porsi+Kitchen+Shift; cafe: BOM+QR Meja+Split Bill/Tip; retail: Barcode+Multi-variant+CRM)
- buat kerangka screen placeholder untuk modul baru (debt, kitchen_display, ppob, restock, supporter)
commit+push, analysis per file, STOP.
```

ST5.5B-3 (kasbon dasar)
```
=== SUB-TASK ST5.5B-3 ===
- buat screens/owner/debt_screen.dart: list piutang/kasbon, status (unpaid/partial/paid), tombol bayar
- integrasi ke customer detail (riwayat piutang)
- tombol "Tagih via WA" pakai url_launcher (pesan singkat)
commit+push, analysis per file, STOP.
```

---

## BAGIAN 7 - PHASE 5.5C (SECURITY + SYNC)

ST5.5C-1 (SQLCipher + secure storage)
```
=== SUB-TASK ST5.5C-1 ===
- tambah dependency sqlcipher_flutter_libs + flutter_secure_storage di pubspec
- ubah services/local_db_service.dart: buka drift dengan enkripsi SQLCipher, key dari flutter_secure_storage (generate simpan di secure storage)
- pindahkan simpanan token/session ke flutter_secure_storage
CATATAN: perubahan pubspec memerlukan pub get - jalankan sekali, redirect ke file.
commit+push, analysis per file, STOP.
```

ST5.5C-2 (event-sourcing sync)
```
=== SUB-TASK ST5.5C-2 ===
- ubah services/sync_service.dart: sync berbasis event_id/delta log, idempotent (event_id UNIQUE)
- jalankan sync di background Isolate terpisah agar POS tidak loading
- tangani konflik stok multi-kasir lewat agregasi event berdasarkan atomic counter/timestamp
commit+push, analysis per file, STOP.
```

---

## BAGIAN 7B - PHASE 7.5 (ZERO-FRICTION ONBOARDING + DUAL-MODE QRIS + SETTLEMENT + FINANCIAL CONFIG)

Buat PROGRESS-PHASE7.5.md. Prasyarat eksternal: akun PG resmi berizin PJP BI
(Tripay/Xendit/Duitku/Midtrans) + webhook secret HMAC. Sebelum tersedia, pakai mode sandbox/mock.

ST7.5-1 (migration SQL)
```
=== SUB-TASK ST7.5-1 ===
Buat docs/migrations/2026-09-21-kasirgo-7.5.sql berisi:
- CREATE TABLE merchants, platform_financial_configs, settlements, disbursements (lihat BAGIAN 3)
- ALTER outlets: tambah merchant_id, device_uuid
- ALTER transactions: tambah merchant_id, pg_reference_id, qris_type, payment_status,
  gross_amount, mdr_fee_deducted, kasirgo_margin_deducted, net_amount_to_merchant
- RLS: platform_financial_configs (superowner full, client SELECT-only);
  merchants/settlements/disbursements (merchant baris sendiri, superowner full)
- Seed 1 baris platform_financial_configs dengan nilai default (lihat BAGIAN 3)
- INDEX pada merchant_id/outlet_id + kolom status
File .sql tidak perlu flutter analyze. commit+push, STOP.
```

ST7.5-2 (zero-friction onboarding)
```
=== SUB-TASK ST7.5-2 ===
- services/auth_service.dart: onboarding Anonymous Auth + device_uuid (device_info/path),
  auto-create merchants + default outlet TANPA form, target <1 detik
- simpan device_uuid aman via flutter_secure_storage
- first-run lewati login; menu Pengaturan sediakan "Tautkan Akun" (Google/No. HP) voluntary untuk backup cloud
- KYC wajib owner (email/nohp/nama toko/alamat/KTP/selfie) TIDAK di sini -- dikerjakan Phase 7.7 (ST7.7-2)
- pembuatan merchant+outlet via Edge Function (jangan service_role di client)
Update PROGRESS-PHASE7.5.md: SELESAI ST7.5-2 + BERIKUTNYA ST7.5-3. commit+push, analysis per file, STOP.
```

ST7.5-3 (dual-mode QRIS)
```
=== SUB-TASK ST7.5-3 ===
- POS: pilih mode QRIS -> STATIC atau DYNAMIC; simpan qris_type & payment_status di transaksi
- STATIC: input nominal -> instruksi scan stiker bank warung -> tombol "LUNAS (Statis)" -> set PAID
- DYNAMIC: panggil payment_service create charge -> tampil QR ber-nominal pas -> webhook set PAID
- Validasi nominal dari platform_financial_configs (min/max/free threshold), baca + cache
Update PROGRESS-PHASE7.5.md: SELESAI ST7.5-3 + BERIKUTNYA ST7.5-4. commit+push, analysis per file, STOP.
```

ST7.5-4 (settlement & disbursement + BI-FAST)
```
=== SUB-TASK ST7.5-4 ===
- services/settlement_service.dart: hitung net (gross - mdr - margin) dari config; catat settlements
- UI saldo dipisah: "QRIS Diproses (Cair Nanti Malam)" vs "Total Ditransfer"
- Tarik Kilat (BI-FAST): buat disbursements mode 'instant' + fee dari config
- Edge Function cron auto_settlement: batch sesuai auto_settlement_schedules (12:00 & 19:00 WIB)
- Hook closed-loop: settlement_status='PPOB_USED' saat saldo dipakai beli PPOB (dipakai Phase 9)
Update PROGRESS-PHASE7.5.md: SELESAI ST7.5-4 + BERIKUTNYA ST7.5-5. commit+push, analysis per file, STOP.
```

ST7.5-5 (superowner financial config)
```
=== SUB-TASK ST7.5-5 ===
- Superadmin web: form kelola platform_financial_configs (threshold, MDR, margin, fee_bearer,
  jadwal settlement, biaya disbursement); simpan + catat updated_by
- App mobile: baca config untuk validasi nominal + tampilkan rincian biaya transparan
Update PROGRESS-PHASE7.5.md: SELESAI Phase 7.5 + BERIKUTNYA Phase 7.6. commit+push, analysis per file, STOP.
```

---

## BAGIAN 7C - PHASE 7.6 (UI RETROFIT CENTENNIAL MODERN OCEAN WHITE)

Tujuan: menyamakan SELURUH tampilan (Superadmin web, Owner, Admin, Cashier, Kitchen,
Customer, serta fitur Produk/Pelanggan/Karyawan/Laporan/Pengaturan) ke Design System v2
(Bagian 1.6). Referensi layout kasirmurah.com, palet Ocean White. Aturan mutlak:
UI-ONLY, feature-preserving. DILARANG mengubah logic, provider, service, model, schema,
query, route, atau alur bisnis. Hanya lapisan visual.

PROGRESS-PHASE7.6.md:
```
# PROGRESS PHASE 7.6
SELESAI: -
BERIKUTNYA: ST7.6-1 token & tema dasar
BLOCKER: -
```

ST7.6-1 (token & tema dasar)
```
=== SUB-TASK ST7.6-1 ===
- config/app_theme.dart: ganti total ke palet Ocean White (Bagian 1.6) - ColorScheme light,
  scaffold #F8FAFC, card #FFFFFF + border #E2E8F0, primary #0284C7, gradient #06B6D4->#0284C7,
  text #0F172A/#64748B, status #10B981/#F59E0B/#EF4444, font Inter, radius/shadow, breakpoint.
- themes AppBar/Card/Input/ElevatedButton/BottomNav/Chip/TabBar ikut token.
- kasirgo-admin: tailwind.config.js + index.css tema light Ocean (warna & radius sama).
- grep dan hapus hardcode warna lama (#4F46E5,#0F172A bg,#1E293B) di seluruh lib/ dan src/;
  arahkan ke token. TIDAK menyentuh widget logic.
Update PROGRESS-PHASE7.6.md: SELESAI ST7.6-1 + BERIKUTNYA ST7.6-2. commit+push, analysis per file, STOP.
```

ST7.6-2 (shared widget kit)
```
=== SUB-TASK ST7.6-2 ===
Buat widgets/common/ (komponen bersama, dipakai semua role):
- app_shell.dart: OwnerHomeScreen shell adaptif - Desktop sidebar 240dp + header 60dp +
  Center(ConstrainedBox(maxWidth:1100)); Mobile app bar glass + drawer (profil, search,
  seksi UTAMA/OPERASIONAL, Keluar, versi) + bottom nav frosted blur 20 (7 item).
  Ekspos param `child`, `title`, `activeIndex`, `bottomNav`.
- hero_card.dart, stat_card.dart, module_tile.dart (ikon+label, dukung badge "Segera"),
  section_header.dart, status_badge.dart (aman/menipis/habis, kasbon, AI), empty_state.dart,
  price_text.dart, filter_chips.dart (periode 7 pilihan).
- Terapkan di 1 screen pilot (owner_home) untuk validasi; sisanya di sub-task berikut.
Update PROGRESS-PHASE7.6.md: SELESAI ST7.6-2 + BERIKUTNYA ST7.6-3. commit+push, analysis per file, STOP.
```

ST7.6-3 (dashboard Owner + grid 10 modul)
```
=== SUB-TASK ST7.6-3 ===
- screens/owner/owner_home.dart: pakai AppShell + HeroCard (omzet periode + produk terjual) +
  FilterChips + 4 StatCard (Potensi Untung, Belum Bayar, Produk Terjual, Perlu Cek Stok) +
  grid kartu shortcut 10 modul bisnis (Bagian 1.6) dengan badge "Segera" untuk yang belum ada.
- Data tetap dari provider/state yang sudah ada; jangan ubah query/logic.
Update PROGRESS-PHASE7.6.md: SELESAI ST7.6-3 + BERIKUTNYA ST7.6-4. commit+push, analysis per file, STOP.
```

ST7.6-4 (Produk, POS, Pelanggan, Karyawan)
```
=== SUB-TASK ST7.6-4 ===
- product_list: chip pintasan (Kategori/Stok/Harga/Supplier/Penerimaan Stok) + header
  "N Jenis Produk" + Urutkan + cari + chip "Semua" + kartu produk (thumbnail, nama, badge
  status, harga tebal, barcode, info stok). Grid 4 kolom / rasio 0.95 / badge stok
  (Hijau>10, Kuning1-10, Merah0). Tablet 3 kolom, mobile 2 kolom.
- product_form (di dalam shell, `maxWidth: 760`): seksi berjudul, OutlinedTextField, dropdown
  kategori, barcode + ikon scan, Harga Modal/Harga Jual, deskripsi multiline, kotak unggah
  "Gambar Produk" dashed, "Opsi Lanjutan" expandable, tombol primary penuh lebar di bawah.
- pos: grid katalog 4 kolom + cart panel tetap fungsional (tidak ubah logika cart/checkout).
- customer_list + employee: list/kartu + status_badge + empty_state v2.
Update PROGRESS-PHASE7.6.md: SELESAI ST7.6-4 + BERIKUTNYA ST7.6-5. commit+push, analysis per file, STOP.
```

ST7.6-5 (Laporan, Pengaturan, Health Score, modul bisnis)
```
=== SUB-TASK ST7.6-5 ===
- report: kartu ringkas + chart fl_chart palet Ocean (tanpa ubah kalkulasi laporan).
- settings: seksi bertoken v2 (Program Pendukung, outlet, printer, dsb tetap utuh).
- health_score + screens modul: debt, ppob, restock, kitchen_display, whatsapp_broadcast,
  social_commerce, qr_table, online_catalog, supporter -> seragamkan via AppShell + kit.
- Belum ada screen-nya: tampilkan kartu "Segera" (jangan buat logic baru di fase ini).
Update PROGRESS-PHASE7.6.md: SELESAI ST7.6-5 + BERIKUTNYA ST7.6-6. commit+push, analysis per file, STOP.
```

ST7.6-6 (Cashier, Admin, Kitchen, Customer)
```
=== SUB-TASK ST7.6-6 ===
- cashier_home: kartu outlet + toggle Offline/Toko, header "Pilih Produk/Paket" + Urutkan +
  cari + chip, baris produk radio; bar aksi "Scan Produk" (outlined) + "Keranjang" (filled).
  Alur bayar/QRIS tidak berubah.
- checkout/pembayaran: banner status lebar (merah BELUM LUNAS / hijau LUNAS), baris info
  (Kasir/Tanggal/Metode) + "Ubah", Informasi Pelanggan, grid aksi 2x2 (Cetak Struk, Beranda,
  Kembali, Konfirmasi).
- modal struk: Cetak Struk / Convert PDF / Simpan Gambar + radio 58mm/80mm + Kembali + preview.
- scan: segmented "Kamera"/"Alat Scanner" + viewport + bar Total (N item) + "Lanjut ke Keranjang".
- admin_home, kitchen KDS, customer_menu: shell + kit yang sama; status order pakai status_badge.
Update PROGRESS-PHASE7.6.md: SELESAI ST7.6-6 + BERIKUTNYA ST7.6-7. commit+push, analysis per file, STOP.
```

ST7.6-7 (Superadmin Web React)
```
=== SUB-TASK ST7.6-7 ===
- kasirgo-admin/src: Layout.jsx sidebar putih 240dp + header, semua pages (Login, Dashboard,
  Users, UserDetail, Affiliates, Backup, Revenue) pakai token Tailwind Ocean; tabel/kartu/
  badge/button seragam. Tidak ubah API call, auth, atau logic data.
Update PROGRESS-PHASE7.6.md: SELESAI ST7.6-7 + BERIKUTNYA ST7.6-8. commit+push, analysis per file, STOP.
```

ST7.6-8 (QA regresi + progress)
```
=== SUB-TASK ST7.6-8 ===
- flutter analyze bersih; build web html + npm run build admin sukses.
- Checklist fitur utuh: auth, CRUD produk, POS+QRIS, laporan, pelanggan, karyawan, pengaturan,
  kasbon, WA, modul lain - pastikan tidak ada yang hilang/berubah fungsi akibat retrofit.
- Uji tampilan 3 breakpoint (360/768/1280): tidak stretched, sidebar muncul di >=860dp,
  bottom nav hanya mobile, kartu stat & grid rapi.
- Simpan screenshot; update PROGRESS-PHASE7.6.md SELESAI + BERIKUTNYA Phase 8.
- Update tracker AGENTS.md (Design System v2 + Phase 7.6 SELESAI). commit+push, STOP.
```

Catatan: bila screen modul bisnis baru dibuat di Phase 8/9, WAJIB langsung memakai
AppShell + kit v2 (tidak boleh mulai dari tema lama).

---

## BAGIAN 7D - PHASE 7.7 (CONTROL PLANE + KYC + IZIN + SETTING SUPERADMIN)

Buat PROGRESS-PHASE7.7.md. Tujuan: semua integrasi/margin/limit bisa diubah dari superadmin
TANPA menyentuh kodingan (lihat Bagian 1.10). Satu sub-task = satu session.

ST7.7-1 (migration + models)
```
=== SUB-TASK ST7.7-1 ===
Buat docs/migrations/2026-09-21-kasirgo-7.7.sql berisi:
- CREATE TABLE platform_integrations, outlet_kyc, outlet_staff_quota, affiliate_payouts (BAGIAN 3)
- RLS sesuai BAGIAN 3.4 (secret_config TIDAK ke client; DELETE produk owner-only)
- Seed platform_integrations baris kosong (is_active=false) untuk: pg_duitku, ppob_digiflazz,
  b2b_distributor, fintech_partner, cloudflare_r2, db_connection, wa_business, affiliate
- models/platform_config.dart + services/config_service.dart: fetch semua config aktif,
  cache di shared_preferences/sqlite, fallback ke nilai default bila offline
File .sql tidak perlu flutter analyze. commit+push, STOP.
```

ST7.7-2 (KYC owner + auto-verify)
```
=== SUB-TASK ST7.7-2 ===
- screens/auth/onboarding_kyc_screen.dart: form email, nohp, nama toko, alamat toko,
  upload KTP + selfie memegang KTP (image_picker, simpan LOKAL -> image path saja)
- gate: sebelum KYC verified, blokir POS/transaksi; tampilkan banner "Lengkapi verifikasi"
- Edge Function verify_kyc: validasi 6 field + format -> set status verified + auto_verified
- Owner lihat status verifikasi di Pengaturan
Update PROGRESS-PHASE7.7.md: SELESAI ST7.7-2 + BERIKUTNYA ST7.7-3. commit+push, analysis per file, STOP.
```

ST7.7-3 (izin + kelola staf)
```
=== SUB-TASK ST7.7-3 ===
- produk: sembunyikan tombol hapus untuk Admin (UI) + andalkan RLS menolak DELETE (server)
- screens/owner/staff_management_screen.dart: Owner create/delete Admin & Kasir;
  enforce outlet_staff_quota (default 1 Admin + 1 Kasir); kelebihan -> ajakan Program Pendukung
Update PROGRESS-PHASE7.7.md: SELESAI ST7.7-3 + BERIKUTNYA ST7.7-4. commit+push, analysis per file, STOP.
```

ST7.7-4 (owner affiliate + pembayaran statis)
```
=== SUB-TASK ST7.7-4 ===
- screens/owner/affiliate_screen.dart: tampilkan link affiliate, setting rekening bank pencairan,
  laporan closing komisi (total, pending, cair)
- Pengaturan > Pembayaran: opsi QRIS STATIS (upload gambar QRIS yang sudah ada) atau DINAMIS
  (aktif via superadmin); simpan pilihan + gambar lokal
Update PROGRESS-PHASE7.7.md: SELESAI ST7.7-4 + BERIKUTNYA ST7.7-5. commit+push, analysis per file, STOP.
```

ST7.7-5 (superadmin control plane web)
```
=== SUB-TASK ST7.7-5 ===
kasirgo-admin: halaman Settings (tab) mengelola platform_integrations + financial config:
- Payment Gateway: link, api key, nominal biaya, margin KasirGo, setting pencairan
- PPOB: api key Digiflazz/IAK/RCB, modal, margin persen -> harga jual semua produk auto
- B2B Kulakan: link affiliate distributor (public_config) dipakai RestockScreen owner
- Affiliate: komisi upgrade Program Pendukung + pencairan otomatis
- Fintech: link akun partner fintech/insurtech
- Storage: koneksi Cloudflare R2 (bucket+key)
- Database: url/user/password/apikey koneksi (mis. Supabase)
- WA Bisnis: api key WA Cloud API
Pakai token Tailwind v2; secret di-mask. commit+push, STOP.
```

ST7.7-6 (app baca config dinamis + QA)
```
=== SUB-TASK ST7.7-6 ===
- pastikan PPOB/Restock/WA/upload thumbnail membaca config dari config_service (cache+fallback),
  tidak ada nilai integrasi yang di-hardcode
- QA: ubah link distributor & margin persen di superadmin -> app ikut berubah tanpa rebuild backend
- Update tracker AGENTS.md (Phase 7.7 SELESAI). commit+push, STOP.
```

Catatan: Phase 7.8/9 lanjut memakai config yang sama; jangan hardcode ulang nilai integrasi.

---

## BAGIAN 8 - PHASE 6-12 (MODUL 3.0)

Gunakan pola yang sama: tempel PROMPT PEMBUKA UNIVERSAL + SUB-TASK, satu per sesi, commit+push, Compact.

### PHASE 6 - Kasbon/Piutang + WA + Sponsored Receipt  [SELESAI]
- ST6-1: `utils/wa_helper.dart` (sendReceipt, sendBroadcast, openChat) + tombol kirim struk WA di checkout
- ST6-2: struk WhatsApp tampilkan banner kupon sponsor dari `receipt_sponsors` + increment impression
- ST6-3: CRM auto-retensi (deteksi pelanggan tidak aktif >30 hari) + broadcast
- Test: kirim struk, banner sponsor muncul, broadcast terkirim.

### PHASE 7 - Dynamic QRIS Payment Gateway  [SELESAI]
- ST7-1: `services/payment_service.dart` (create QRIS charge via REST API gateway) + tampil QR dinamis di POS
- ST7-2: Edge Function `webhook_qris` verifikasi HMAC SHA-256 -> update transaksi LUNAS
- ST7-3: direct settlement + split-payment logic (komisi platform dipotong gateway, bukan ditampung KasirGo)
- Test: QR dinamis tampil, webhook set LUNAS, settlement tercatat.

### PHASE 7.6 - UI Retrofit "Centennial Modern Ocean White"
Lihat BAGIAN 7C (ST7.6-1 s/d ST7.6-8). UI-only, semua role + semua fitur.

### PHASE 7.7 - Control Plane + KYC + Izin + Setting Superadmin
Lihat BAGIAN 7D (ST7.7-1 s/d ST7.7-6). Semua setting integrasi/margin lewat superadmin, tanpa kodingan.

### PHASE 8 - Modul per outlet_type
- ST8-1: Variant produk (product_form + product_list + POS pilih varian) - retail
- ST8-2: BOM/Resep HPP (recipe + recipe_items) + kalkulasi HPP otomatis - cafe
- ST8-3: Kitchen Display (KDS): daftar order masuk, status, tandai selesai - cafe/warteg
- ST8-4: Shift kasir (open/close + opening/closing cash) + Tip + split bill
- Test: sesuai outlet_type.

### PHASE 9 - PPOB + Embedded B2B Restock
- ST9-1: `services/ppob_service.dart` + `screens/owner/ppob_screen.dart` (pulsa/PLN/BPJS/game);
  api key + **margin persen dari `platform_integrations`/config** -> harga jual semua produk PPOB auto
- ST9-2: Closed-loop settlement (saldo QRIS -> beli PPOB real-time)
- ST9-3: Embedded B2B Restock via WebView anti-bypass + tracking_id + komisi;
  **link distributor diambil dari config superadmin** (ganti link = tanpa ubah koding)
- Test: transaksi PPOB, restock order tercatat.

### PHASE 10 - Fintech + Data + Insurance
- ST10-1: Fintech lead-gen (ajukan modal berdasarkan data arus kas)
- ST10-2: Hyperlocal data report (agregat anonim)
- ST10-3: Micro-insurance toko
- Test: lead tercatat.

### PHASE 11 - Superadmin Web (React + Cloudflare Pages)
- ST11-1: Dashboard 12 revenue engine + supporters + user mgmt
- ST11-2: Impersonate, backup/restore, data intelligence
- ST11-3: Control Plane lengkap (PG, PPOB, B2B, Affiliate, Fintech, R2, DB, WA) -- lihat BAGIAN 7D/1.10
- Test: login superadmin, statistik tampil.

### PHASE 12 - Polish + Security Audit + Release
- ST12-1: Obfuscation + hardening + audit `service_role` tidak ada di APK
- ST12-2: Stress test offline-online sync Isolate
- ST12-3: Build APK release split-per-abi <10MB + deploy superadmin
- Test: full flow end-to-end semua role + offline + Program Pendukung.

---

## BAGIAN 9 - TEST LIVE PER PHASE

Setelah phase selesai: jalankan dev server, minta URL preview, uji pakai klik, laporkan
(URL + yang diklik + hasil + error). Jangan hanya bilang "build sukses".

Flutter:
```
flutter run -d web-server --web-renderer html --web-hostname 0.0.0.0 --web-port 8080
```
React admin:
```
npm run dev
```
Catatan: fitur native (kamera/scan barcode, SQLite SQLCipher, image_picker) TIDAK jalan di web.
Fitur ini diuji via APK debug di HP. Yang bisa diuji di web: UI, navigasi, auth, CRUD Supabase,
chart, POS, PPOB mock, WA intent, Program Pendukung.

---

## BAGIAN 10 - HANDOFF & GANTI PHASE

Setelah phase selesai:
1. `git add . && git commit -m "docs: phase X selesai" && git push`
2. Update Progress Tracker di `AGENTS.md`.
3. Tulis status di `PROGRESS-PHASE[X].md` (SELESAI / BERIKUTNYA / CATATAN / BLOCKER).
4. Ganti phase: push -> Compact (atau Reset jika context penuh / Compact ngawur).
5. Buat `PROGRESS-PHASE[X+1].md` untuk phase berikutnya.

Reset vs Compact (pilih satu):
- Compact = ringkas, tetap ingat -> antar sub-task dalam phase.
- Reset = kosong total, paling hemat -> saat ganti phase atau setelah Compact ngawur.
- Jangan keduanya.

---

## BAGIAN 11 - DELTA vs VERSI LAMA (RINGKAS)

| Aspek | Versi lama | 3.0 |
|-------|-----------|-----|
| Model | Langganan free/basic_25/pro_50 | Gratis selamanya + 12 revenue engine |
| Monetisasi user | Subscription gate + iklan | Program Pendukung (kosmetik opsional) |
| QRIS | Manual | Dynamic QRIS + webhook HMAC + split settlement |
| QRIS mode | 1 mode (manual) | Dual-Mode: Statis (MDR 0%) + Dinamis (auto LUNAS) |
| Onboarding | Form/email/OTP + login | Zero-friction: Anonymous Auth + Device UUID, lalu **KYC wajib** (email/nohp/toko/alamat/KTP/selfie) auto-verify |
| Dana | Tidak diatur eksplisit | Zero-touch money: escrow PG PJP BI + direct settlement + BI-FAST |
| Biaya/margin | Hardcode | Dinamis via `platform_financial_configs` (superowner real-time) |
| Integrasi | Hardcode di koding | Control Plane `platform_integrations` (PG/PPOB/B2B/Fintech/R2/DB/WA) -- edit superadmin tanpa koding |
| Izin | Sama rata | Owner hapus produk + kelola staf (kuota 1 Admin + 1 Kasir); Admin tanpa hapus |
| Arsitektur | POS generik | Modular `outlet_type` |
| Modul | Produk/POS/AI/laporan/pelanggan/karyawan | + Kasbon, BOM/Resep, KDS/QR meja, Variant, Shift/Tip, PPOB, B2B Restock, Fintech |
| Keamanan | SQLite biasa | SQLCipher + flutter_secure_storage |
| Sync | Last-write-wins | Event-sourcing / delta log + background Isolate |
| Superadmin | Subscription/revenue/affiliate | 12 revenue engine + supporters + data + Control Plane (setting semua integrasi) |
| UI/Theme | Dark Glassmorphism (indigo) | Centennial Modern Ocean White (light) - Phase 7.6 |

OBSOLETE (buang di 5.5B): subscription tier, iklan banner free, limit 500.

---

## BAGIAN 12 - PRASYARAT EKSTERNAL (belum ada)
- Akun Payment Gateway resmi berizin PJP BI (Tripay/Xendit/Duitku/Midtrans) + kredensial sandbox + webhook secret HMAC -> Phase 7.5
- Persetujuan Master Account / Payment Facilitator (split-payment + escrow) -> Phase 7.5
- API key PPOB (Digiflazz/IAK/RCB) -> Phase 9
- Akun partner fintech/insurtech -> Phase 10
- Cloudflare R2 bucket -> thumbnail opt-in (koneksi diset di superadmin, Phase 7.7)
- Link affiliate distributor B2B (kulakan) -> Phase 7.7 (set di superadmin)
- Kredensial koneksi database (url/user/password/apikey, mis. Supabase) -> Phase 7.7 (set di superadmin)
- API key WA Business (Cloud API) untuk WA Marketing -> Phase 7.7 (set di superadmin)
- Isi `config/supabase_config.dart` + kredensial Edge Function (service_role hanya di server)
- Aktifkan Supabase Anonymous Auth (untuk onboarding zero-friction) -> Phase 7.5
