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
2. Brand-Sponsored Receipts + Iklan Halaman Pelanggan (kupon FMCG di struk WA + banner sponsor lokal / Adsterra di halaman web pelanggan: katalog online & QR meja; owner TIDAK melihat iklan; Pendukung = bebas iklan)
3. Embedded B2B Restock Engine (komisi 1-3% belanja stok via WebView anti-bypass)
4. Fintech & Credit Lead-Gen (1-2% nilai pinjaman cair)
5. Margin PPOB API (pulsa/PLN/BPJS via Digiflazz/IAK/RCB)
6. Micro-Insurance Toko (komisi 15-30% premi)
7. B2B Clearance Marketplace (obral near-expiry, komisi 3-5%)
8. DOOH Screen Display Ads
9. Hyperlocal Data Intelligence (laporan tren agregat anonim)
10. Hardware Bundling (margin 20-40%)
11. WhatsApp Credit Margin (Rp100/pesan)
12. Program Pendukung (satu paket sukarela Rp50.000/bulan - fitur pertumbuhan, lihat 1.4)

### 1.4 Program Pendukung (satu paket, Rp50.000/bulan)
Semua fitur inti (POS, produk & transaksi tanpa batas, stok, kasbon, laporan dasar, struk WA manual,
QRIS statis+dinamis, AI Co-Pilot dasar, 1 outlet, 1 Admin + 1 Kasir) GRATIS SELAMANYA.
Program Pendukung = fitur pertumbuhan, sukarela, SATU harga.

Harga & durasi disimpan di Control Plane (`platform_financial_configs`), BUKAN hardcode.
- **Pendukung KasirGo - Rp50.000/bulan** (satu paket, akses semua fitur Pendukung).
- **Reverse trial 14 hari** otomatis sejak onboarding; setelah habis fitur terkunci.
  DATA TIDAK DIHAPUS - terbuka kembali saat berlangganan.
- Isi paket:
  - Katalog pelanggan **bebas iklan** (ad-free) + branding sendiri
  - **Laporan otomatis ke bos** (harian/mingguan/bulanan, bisa diset)
  - Multi-outlet (outlet ke-2 dst)
  - Slot staf tambahan di atas kuota gratis (1 Admin + 1 Kasir)
  - Laporan lanjutan + export Excel/PDF + analitik cashflow/tren
  - AI Co-Pilot Pro + Health Score pro
  - WA Marketing broadcast massal + auto-retensi pelanggan
  - Social Commerce Sync + Katalog Online publik + QR Meja dine-in
  - Backup cloud harian + restore + riwayat >30 hari
  - Custom struk (logo toko + footer)
  - Prioritas support + badge Pendukung + Hall of Fame
- Prinsip: **"gratis untuk bertahan, Pendukung untuk bertumbuh"**.
  DILARANG mengunci POS/produk/transaksi/stok, iklan paksa di app, atau menghapus data user.

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
- **KYC wajib**: user baru TIDAK BISA memakai aplikasi (POS/transaksi/modul diblokir total) sebelum
  KYC `verified`. Tidak ada tombol lewati. Detail alur & kemudahan di Bagian 1.11.

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

10 modul bisnis di grid shortcut dashboard utama (badge "Segera" bila belum aktif):
1. Buku Kasbon (`DebtScreen`) - catat piutang pelanggan + pengingat via WhatsApp.
2. PPOB & Pulsa (`PpobScreen`) - transaksi produk digital/token.
3. Kulakan B2B (`RestockScreen`) - order grosir stok (link distributor dari Control Plane).
4. Kitchen Display (`KitchenDisplayScreen`) - monitor pesanan dapur cafe/resto.
5. WA Marketing (`WhatsappBroadcastScreen`) - broadcast promo + auto-retensi pelanggan.
6. Social Commerce (`SocialCommerceScreen`) - sinkron pesanan marketplace (Shopee, Tokped,
   GrabFood, GoFood) dengan potongan fee otomatis.
7. QR Meja Dine-in (`QrTableScreen`) - generator stiker QR per nomor meja untuk self-order.
8. Katalog Online (`OnlineCatalogScreen`) - katalog publik + tombol langsung order ke WhatsApp warung.
9. Health Score Bisnis (`HealthScoreScreen`) - diagnosa performa otomatis (turnover stok, margin, retensi).
10. Pendukung KasirGo (`SupporterScreen`) - program donasi sukarela penjaga aplikasi Rp0 selamanya.

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
  screens/auth|owner|admin|cashier|customer/   (mis. cashier/incoming_orders_screen, customer/customer_order_screen)
  screens/modules/                             (kitchen_display = KDS owner)
  widgets/common/pos/
  utils/
kasirgo/supabase/functions/
  stock_alert/  webhook_qris/  create_staff/
kasirgo-admin/src/
```

### 1.10 Control Plane (SEMUA setting lewat Superadmin, TANPA ubah kodingan)
Prinsip: nilai integrasi & margin disimpan di DB (`platform_integrations` + `platform_financial_configs`),
di-cache app, ada fallback default. Ganti nilai = cukup edit di web superadmin.

Yang wajib bisa diset dari superadmin:
| Grup | Isi setting |
|------|-------------|
| Payment Gateway | link/api key PG (Duitku dll), nomor biaya yang dikenakan, margin KasirGo, setting transfer pencairan |
| Financial | threshold gratis biaya, jadwal auto-settlement, biaya BI-FAST, **harga & durasi Program Pendukung**, pajak |
| PPOB | api key (Digiflazz/IAK/RCB), modal, **margin persentase** -> harga jual semua produk PPOB auto ikut harga terbaru |
| B2B Kulakan | link affiliate distributor -> dipakai `RestockScreen` di dashboard owner; ubah link cukup edit di sini |
| Affiliate | komisi dari pembayaran Program Pendukung (upgrade) + sistem pencairan komisi otomatis |
| Fintech | link akun partner fintech/insurtech |
| Storage/Hosting | koneksi Cloudflare R2 (bucket + key) |
| Database | url, user, password, api key koneksi (mis. Supabase) |
| WA | mode WA (Pribadi via `wa.me` nomor KYC default / Cloud API opsional), template pesan, kanal laporan |
| Verifikasi | auto-verify pendaftar yang datanya lengkap (email, nohp, nama toko, alamat, KTP, selfie) |
| Iklan/Ads | `ads_enabled`, provider (`adsterra`/`sponsor_lokal`/`none`), script/zona Adsterra (secret), daftar sponsor lokal, kategori diblokir (judi/dewasa/pinjol), placement (katalog_online/qr_meja), frequency cap, ad-free untuk Pendukung, consent |
| Panduan | daftar item panduan (judul, jenis PDF/video, kategori, role, URL/`file_key`, thumbnail, urutan, aktif) |
| Laporan | template laporan ke bos, jadwal default, kanal (WA pribadi/email/PDF), isi default |
| Kuota & Limit | kuota staf (1 Admin + 1 Kasir), multi-outlet, batas broadcast/export, riwayat data |
| Feature Flags | nyala/mati fitur, rollout persen, per `outlet_type`/segmen |
| Trial & Billing | durasi trial (14 hari), grace period, dunning/retry, auto-renew |

Prinsip skala: **"set sekali, jalan otomatis"**. Konfigurasi berjenjang (Global -> Segmen/Region -> Outlet),
punya versi + jadwal berlaku + rollback. Detail superadmin skala puluhan ribu di Bagian 1.11.

---

### 1.11 Superadmin Skala Besar + Onboarding KYC Wajib + Panduan

#### A. Onboarding KYC wajib (aplikasi terkunci sampai verified)
- Alur: daftar (Anonymous Auth + device UUID, <1 detik) -> **wizard KYC** -> auto-verify -> baru bisa pakai.
- 6 field wajib: email, no HP (WA), nama toko, alamat toko, **foto KTP**, **selfie memegang KTP**.
- Dibuat semudah mungkin: auto-isi (email/HP/nama toko), OCR KTP on-device, kamera berpanduan,
  kompres otomatis (WebP), validasi realtime, draf otomatis, boleh isi offline + kirim saat online,
  tombol bantuan + contoh foto benar/salah.
- Sebelum `verified`: hanya layar KYC, bantuan/support, dan logout yang bisa diakses. POS, produk,
  transaksi, dan semua modul **diblokir total**. Tidak ada tombol lewati. Banner "Selesaikan verifikasi untuk mulai berjualan".
- Status: `unsubmitted` / `draft` / `pending_review` / `verified` / `rejected` (reject -> alasan + kirim ulang).
- Foto KTP/selfie disimpan LOKAL (`image_local_path`); server hanya menyimpan status + data field.
  Anti-duplikat via hash NIK/HP (tanpa menyimpan NIK mentah). Ada persetujuan data (UU PDP).
- Gate ditegakkan di UI + server (RLS/Edge): tanpa `verified`, operasi transaksi ditolak.

#### B. Panduan penggunaan aplikasi (PDF + video, dikelola superadmin)
- Menu "Panduan" di Pengaturan + tombol bantuan/deep-link per modul.
- Konten: **PDF** (dapat disimpan di R2) dan **video** (link YouTube).
- Kategori per modul/role (Mulai, Produk, POS, Laporan, Kasbon, WA, Program Pendukung, dll).
- Fitur: pencarian, thumbnail, urutan, tandai penting; PDF di-cache (offline), video butuh internet.
- Dikelola dari Control Plane (tab Panduan): CRUD judul, jenis, kategori, role, URL/`file_key`,
  thumbnail, urutan, aktif/nonaktif.

#### C. Superadmin Control Plane & manajemen skala puluhan ribu
Pewarisan konfigurasi: **Global -> Segmen/Region -> Outlet** (versi + jadwal berlaku + rollback).
- **Manajemen**: server-side search/filter (nama, no HP, KYC, tier, outlet_type, region, status bayar,
  tanggal daftar, kesehatan sync) + saved views; **bulk action** (suspend/aktifkan, kirim notifikasi,
  beri trial, ubah kuota, tag segmen, reset device); segmentasi otomatis (baru/aktif/tidak aktif/pendukung/bermasalah);
  impersonate + audit + expiry; user detail 360 (outlet, transaksi, langganan, KYC, perangkat, log sync, riwayat support).
- **Otomatisasi (set sekali)**: auto-provision merchant+outlet; auto-KYC; auto-settlement + auto-disbursement;
  auto-trial lalu auto-lock; auto-billing Pendukung (reminder H-3, retry, grace, auto-expire);
  auto-report ke bos; auto-thumbnail R2; auto-arsip data HOT->WARM->COLD; auto-suspend abuse.
- **Rules engine (if-then)**: tidak aktif 30 hari -> retensi; bayar gagal -> retry+dunning;
  trial H-2 -> tawaran upgrade; sync error berulang -> alert ops; KYC ditolak 2x -> review manual;
  stok kritis (AI) -> notif owner.
- **Alat skala**: feature flags + staged rollout (persen/segmen/outlet_type); announcement/in-app message;
  config versioning + rollback; audit log; RBAC tim admin (Superadmin/Finance/Support/Ops); rate limit & quota global.
- **Monitoring**: revenue 12 engine, aktivitas outlet, konversi trial->Pendukung, churn; kesehatan sistem
  (error sync, webhook gagal, pembayaran gagal); alert otomatis ke tim.
- **Keamanan**: secret di-mask; `service_role` hanya di server/Edge Function; audit log wajib saat tim besar.

---

## BAGIAN 2 - ATURAN UMUM & HEMAT TOKEN

### 2.1 Aturan Umum
1. Satu session = satu sub-task. Jangan gabung.
2. Push tiap 1-2 file: `git add . && git commit -m "progress: [file]" && git push`.
3. Baca `AGENTS.md` + `PROGRESS-PHASE*.md` saja sebagai konteks. Jangan baca semua file.
4. Update Progress Tracker di `AGENTS.md` tiap phase selesai.
5. Testing cepat web (JANGAN `flutter run -d web-server` -> memicu "VM offline"/disk penuh):
   `flutter build web --release --base-href /kasirgo/` lalu serve `build/web` (static server) atau deploy ke
   GitHub Pages/Cloudflare Pages. Native (kamera/scan/SQLCipher) diuji via APK debug.
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
Fitur inti GRATIS SELAMANYA; fitur pertumbuhan via Program Pendukung (satu harga Rp50.000/bulan + trial 14 hari).
Onboarding KYC WAJIB: app terkunci sampai verified. Iklan hanya di web pelanggan (owner tidak lihat); tidak ada iklan tersembunyi.

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
Prompt siap-tempel per sub-task (7.5 -> 7.7 -> 7.6 -> 7.8 -> 8-12): `docs/PROMPT-GILIRAN.md`.

---

## BAGIAN 3 - DATABASE SCHEMA 3.0

### 3.1 Perubahan tabel existing
- `outlets`: rename `type` -> `outlet_type` (enum kelontong/warteg/cafe/retail); HAPUS `subscription_tier`, `subscription_expiry`; tambah `merchant_id UUID REFERENCES merchants(id)`, `device_uuid TEXT`.
- `user_roles`: role CHECK tambah `kitchen`.
- `products`: tetap. Tambah `has_variants BOOLEAN DEFAULT false`.
- `transactions`: tambah `merchant_id UUID`, `pg_reference_id TEXT` (kanonik; `gateway_ref` alias lama), `qris_type TEXT` (STATIC/DYNAMIC), `payment_status TEXT DEFAULT 'PENDING'` (PENDING/PAID/EXPIRED/CANCELLED), `gross_amount DECIMAL(12,2)`, `mdr_fee_deducted DECIMAL(12,2) DEFAULT 0`, `kasirgo_margin_deducted DECIMAL(12,2) DEFAULT 0`, `net_amount_to_merchant DECIMAL(12,2) DEFAULT 0`, `settlement_status TEXT DEFAULT 'n/a'` (UNSETTLED/SETTLED/PPOB_USED), `tip_amount DECIMAL(12,2) DEFAULT 0`, `shift_id UUID`, `debt_id UUID`, `sync_status TEXT DEFAULT 'synced'`, `event_id TEXT`, `device_id TEXT`; + dine-in: `notes TEXT` (menyimpan "Meja <no>"), `order_status TEXT DEFAULT 'baru'` (baru/diproses/siap/selesai), `REPLICA IDENTITY FULL`, masuk publication `supabase_realtime`.
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
  tier TEXT DEFAULT 'pendukung',
  amount DECIMAL(12,2) DEFAULT 50000,
  status TEXT DEFAULT 'trial' CHECK (status IN ('trial','active','expired','cancelled')),
  trial_started_at TIMESTAMPTZ,
  start_date TIMESTAMPTZ DEFAULT NOW(),
  end_date TIMESTAMPTZ,
  auto_renew BOOLEAN DEFAULT true,
  pg_reference_id TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
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

-- Program Pendukung (satu paket, Rp50.000/bulan) + entitlement + trial
CREATE TABLE entitlements (
  outlet_id UUID PRIMARY KEY REFERENCES outlets(id) ON DELETE CASCADE,
  is_supporter BOOLEAN DEFAULT false,
  ad_free BOOLEAN DEFAULT false,
  features JSONB DEFAULT '{}',
  trial_ends_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE billing_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  event TEXT, amount NUMERIC DEFAULT 0, status TEXT, ref TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Laporan otomatis ke bos
CREATE TABLE report_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  period TEXT CHECK (period IN ('daily','weekly','monthly')),
  send_time TIME DEFAULT '21:00',
  day_of_week INT, day_of_month INT,
  recipients JSONB DEFAULT '[]',
  channels JSONB DEFAULT '["email"]',
  content_flags JSONB DEFAULT '{}',
  enabled BOOLEAN DEFAULT true,
  last_sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Iklan sisi pelanggan (owner tidak melihat)
CREATE TABLE outlet_ad_state (
  outlet_id UUID PRIMARY KEY REFERENCES outlets(id) ON DELETE CASCADE,
  ad_enabled BOOLEAN DEFAULT true,
  ad_free BOOLEAN DEFAULT false,
  impressions INT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Panduan penggunaan (PDF + video), dikelola superadmin
CREATE TABLE guide_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  kind TEXT CHECK (kind IN ('pdf','video')),
  category TEXT, role TEXT,
  url TEXT, file_key TEXT, thumbnail_key TEXT,
  sort_order INT DEFAULT 0, is_active BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Fondasi Control Plane skala besar
CREATE TABLE platform_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL,
  scope TEXT DEFAULT 'global' CHECK (scope IN ('global','segment','outlet')),
  scope_ref TEXT,
  value JSONB DEFAULT '{}',
  version INT DEFAULT 1,
  effective_from TIMESTAMPTZ,
  updated_by UUID,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(key, scope, scope_ref)
);

CREATE TABLE feature_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  enabled BOOLEAN DEFAULT false,
  rollout_pct INT DEFAULT 100,
  segments JSONB DEFAULT '[]',
  outlet_types JSONB DEFAULT '[]',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE automation_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT, trigger TEXT,
  condition JSONB DEFAULT '{}', action JSONB DEFAULT '{}',
  enabled BOOLEAN DEFAULT true, created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE segments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL, rules JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE outlet_segments (
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  segment_id UUID REFERENCES segments(id) ON DELETE CASCADE,
  PRIMARY KEY (outlet_id, segment_id)
);

CREATE TABLE announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT, body TEXT, audience TEXT DEFAULT 'all',
  starts_at TIMESTAMPTZ, ends_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true, created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID, actor_role TEXT, action TEXT, target TEXT,
  meta JSONB DEFAULT '{}', created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID, role TEXT CHECK (role IN ('superadmin','finance','support','ops')),
  is_active BOOLEAN DEFAULT true, created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 3.2b Tabel & RPC Pesanan Dine-in Pelanggan (QR Meja)

Alur: pelanggan scan QR meja (anon) -> pilih menu -> **bayar di meja** (QRIS/transfer/tunai,
tanpa antre kasir) -> kirim pesanan -> kasir/dapur menerima via Realtime.

Tabel tambahan:
```sql
-- Info pembayaran outlet (teks saja, TANPA gambar sesuai kebijakan foto)
CREATE TABLE outlet_payment_configs (
  outlet_id UUID PRIMARY KEY REFERENCES outlets(id) ON DELETE CASCADE,
  merchant_name TEXT, bank_wallet TEXT, account_number TEXT,
  nmid TEXT, instruction TEXT, is_active BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```
- `transactions` tambah: `notes TEXT` (menyimpan "Meja <no>"), `order_status TEXT DEFAULT 'baru'`
  (baru/diproses/siap/selesai), `REPLICA IDENTITY FULL`, dan masuk publication `supabase_realtime`.

RPC (SECURITY DEFINER; customer = anon):
- `get_public_outlet(p_code)` -> outlet publik berdasarkan kode.
- `get_public_menu(p_outlet)` -> katalog produk publik.
- `get_public_outlet_payment(p_outlet)` -> info bayar (merchant/bank/no rekening/nmid/instruksi).
- `place_dine_in_order(p_outlet, p_table, p_items, p_payment_method)` -> buat transaksi `dine_in`
  + item; harga dihitung server-side (anti manipulasi); `p_payment_method` in (cash/qris/bank_transfer).
  Ada shim 3-arg (fallback `'cash'`) untuk kompatibilitas app lama.
- `set_order_status(p_tx, p_status)` -> kasir/owner ubah progres (baru/diproses/siap/selesai).

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
- `supporters` / `entitlements` / `billing_events` / `report_schedules` / `outlet_ad_state`: Owner akses outlet sendiri
  (read; update terbatas); tulis status pembayaran/trial via Edge Function; Superadmin full.
- `guide_items` / `announcements`: Superadmin full (CRUD); app client SELECT-only yang `is_active`.
- `platform_configs` / `feature_flags` / `automation_rules` / `segments` / `outlet_segments` / `audit_logs` / `admin_users`:
  Superadmin/Edge only; app client hanya SELECT `public_config` yang relevan (secret tidak diekspos).
- Gate KYC: operasi transaksi hanya diizinkan bila `outlet_kyc.status='verified'` (ditegakkan RLS + Edge).
- RPC dine-in pelanggan: `get_public_outlet`, `get_public_menu`, `get_public_outlet_payment`,
  `place_dine_in_order`, `set_order_status` -- lihat 3.2b. Grant ke `anon`/`authenticated` sesuai role.

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
| 7.5 | Zero-Friction Onboarding + Dual-Mode QRIS + Settlement/Disbursement + Superowner Financial Config | SELESAI |
| 7.6 | UI Retrofit "Centennial Modern Ocean White" (semua role + semua fitur) | SELESAI |
| 7.7 | Control Plane (setting superadmin tanpa kodingan) + KYC Auto-Verify + Izin Produk/Staf + Owner Affiliate | SELESAI |
| **7.8** | **Monetisasi & Program Pendukung (1 harga Rp50k) + Iklan Pelanggan + Laporan ke Bos + KYC Wajib + Panduan + Skala Superadmin** | **MULAI DI SINI** |
| 8 | Modul outlet_type: BOM/Resep, KDS/QR Meja, Variant, Shift/Tip | |
| 9 | PPOB + Closed-loop + Embedded B2B Restock | |
| 10 | Fintech Lead + Hyperlocal Data + Micro-insurance | |
| 11 | Superadmin Web (12 revenue engine, RBAC, rules engine, monitoring) | |
| 12 | Polish + Security Audit + Release | |

Catatan: porsi yang OBSOLETE dari Phase 5 dan harus dibuang di 5.5B: subscription gate
(free/basic_25/pro_50), iklan banner free tier, limit 500 produk/transaksi.
Catatan: Phase 7.8 menggantikan konsep "3 tier Program Pendukung" menjadi satu harga Rp50.000/bulan.
Iklan hanya di sisi pelanggan (web), TIDAK di APK; tidak boleh ada iklan tersembunyi (ad fraud).

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

## BAGIAN 7E - PHASE 7.8 (MONETISASI & PROGRAM PENDUKUNG + IKLAN PELANGGAN + LAPORAN KE BOS + KYC WAJIB + PANDUAN + SKALA SUPERADMIN)

Buat PROGRESS-PHASE7.8.md. Tujuan: ganti 3 tier Program Pendukung menjadi SATU harga Rp50.000/bulan
(+ reverse trial 14 hari), pindahkan sebagian fitur gratis ke Pendukung, tambah iklan sisi pelanggan
(config Control Plane), laporan otomatis ke bos, onboarding KYC wajib yang mudah, panduan PDF/video,
dan fondasi superadmin siap skala puluhan ribu. Satu sub-task = satu sesi, commit+push, Compact.
Prasyarat: WA pribadi (nomor KYC) via `wa.me` untuk manual; email/PDF untuk laporan otomatis.

ST7.8-1 (migration SQL + seed)
```
=== SUB-TASK ST7.8-1 ===
Buat docs/migrations/2026-09-28-kasirgo-7.8.sql berisi:
- CREATE TABLE supporters (tier 'pendukung', amount 50000, status trial/active/expired/cancelled,
  trial_started_at, period_start/end, auto_renew, pg_reference_id)
- CREATE TABLE entitlements (is_supporter, ad_free, features jsonb, trial_ends_at)
- CREATE TABLE billing_events, report_schedules, outlet_ad_state, guide_items
- CREATE TABLE platform_configs (scope global/segment/outlet + version + effective_from + updated_by)
- CREATE TABLE feature_flags, automation_rules, segments, outlet_segments, announcements,
  audit_logs, admin_users
- ALTER outlets: kolom nomor WA owner (dari KYC) bila belum ada
- Seed grup Control Plane: ads, guide, report, kyc, quota, flags, billing
- RLS sesuai Bagian 3.4 (tabel baru)
File .sql tidak perlu flutter analyze. commit+push, STOP.
```

ST7.8-2 (supporter service + entitlement + trial)
```
=== SUB-TASK ST7.8-2 ===
- services/supporter_service.dart: baca harga/durasi dari platform_financial_configs (cache+fallback),
  status trial/active/expired, auto-renew, checkout via QRIS existing
- entitlements: is_supporter, ad_free, hasFeature(key)
- reverse trial 14 hari otomatis saat onboarding KYC verified (set entitlements.trial_ends_at)
- simpan nomor WA owner dari KYC untuk dipakai wa.me
Update PROGRESS-PHASE7.8.md: SELESAI ST7.8-2 + BERIKUTNYA ST7.8-3. commit+push, STOP.
```

ST7.8-3 (UI Program Pendukung)
```
=== SUB-TASK ST7.8-3 ===
- settings_screen.dart: ganti 3 tier jadi SATU kartu "Pendukung KasirGo Rp50.000/bulan" + status trial/aktif
- _showUpgradeModal -> checkout QRIS; tampilkan sisa hari trial
- badge terkunci pada fitur Pendukung
Update PROGRESS-PHASE7.8.md: SELESAI ST7.8-3 + BERIKUTNYA ST7.8-4. commit+push, STOP.
```

ST7.8-4 (gate fitur pindahan)
```
=== SUB-TASK ST7.8-4 ===
Gate via hasFeature() untuk fitur yang dipindah dari gratis ke Pendukung:
WA Marketing broadcast + auto-retensi, Social Commerce Sync, Katalog Online/QR Meja, AI Pro +
Health Score pro, laporan lanjutan + export Excel/PDF, backup cloud + restore, multi-outlet,
slot staf ke-3 dst, custom struk/logo. Data lama tidak dihapus, hanya akses dikunci.
Update PROGRESS-PHASE7.8.md: SELESAI ST7.8-4 + BERIKUTNYA ST7.8-5. commit+push, STOP.
```

ST7.8-5 (laporan otomatis ke bos)
```
=== SUB-TASK ST7.8-5 ===
- screens/owner/report_schedule_screen.dart: set periode (harian/mingguan/bulanan), jam/hari/tanggal,
  sampai 3 penerima, isi laporan (toggle), kanal (WA pribadi one-tap / email-PDF)
- notifikasi lokal (flutter_local_notifications) -> tap buka WhatsApp dengan teks laporan siap kirim
- Edge Function cron: bangun laporan + kirim email/PDF otomatis
Update PROGRESS-PHASE7.8.md: SELESAI ST7.8-5 + BERIKUTNYA ST7.8-6. commit+push, STOP.
```

ST7.8-6 (iklan pelanggan)
```
=== SUB-TASK ST7.8-6 ===
- halaman web katalog online + QR meja baca config `ads` dari platform_configs (cache+fallback)
- tampilkan iklan WAJAR non-intrusif (bukan popunder, tidak menutupi tombol); owner tidak melihat
- ad_free untuk Pendukung; blokir kategori judi/dewasa/pinjol; consent (UU PDP)
- mode: sponsor_lokal diutamakan, adsterra fallback; TIDAK ada iklan tersembunyi
Update PROGRESS-PHASE7.8.md: SELESAI ST7.8-6 + BERIKUTNYA ST7.8-7. commit+push, STOP.
```

ST7.8-7 (onboarding KYC wajib)
```
=== SUB-TASK ST7.8-7 ===
- screens/auth/onboarding_kyc_screen.dart: wizard 6 field (email, nohp, nama toko, alamat toko,
  foto KTP, selfie pegang KTP) + persetujuan data
- kemudahan: auto-isi, OCR KTP on-device (opsional), kamera berpanduan, kompres otomatis, validasi
  realtime, draf otomatis, boleh offline + kirim saat online, tombol bantuan + contoh foto
- GATE: sebelum verified -> hanya layar KYC/bantuan/logout; POS, produk, transaksi, semua modul DIBLOKIR.
  Tidak ada tombol lewati; banner "Selesaikan verifikasi untuk mulai berjualan"
- status unsubmitted/draft/pending_review/verified/rejected; reject -> alasan + kirim ulang
- foto simpan LOKAL; anti-duplikat hash NIK/HP; Edge Function verify_kyc auto-verify 6 field + format
Update PROGRESS-PHASE7.8.md: SELESAI ST7.8-7 + BERIKUTNYA ST7.8-8. commit+push, STOP.
```

ST7.8-8 (panduan penggunaan PDF + video)
```
=== SUB-TASK ST7.8-8 ===
- screens/owner/guide_screen.dart: daftar panduan dari guide_items (config), filter kategori/role,
  pencarian, thumbnail; PDF di-cache (offline), video buka link YouTube
- tombol/deep-link bantuan per modul; menu "Panduan" di Pengaturan
- konten dikelola superadmin (Bagian 7E ST7.8-9)
Update PROGRESS-PHASE7.8.md: SELESAI ST7.8-8 + BERIKUTNYA ST7.8-9. commit+push, STOP.
```

ST7.8-9 (Control Plane superadmin + QA + dokumen)
```
=== SUB-TASK ST7.8-9 ===
kasirgo-admin: tab Settings Control Plane lengkap:
- Iklan (provider, script/zona secret, sponsor lokal, kategori diblokir, placement, ad-free, consent)
- Panduan (CRUD guide_items: judul, jenis PDF/video, kategori, role, URL/file, thumbnail, urutan, aktif)
- Financial (harga & durasi Pendukung), Laporan (template/jadwal/kanal), KYC, Kuota & Limit, Feature Flags
- Otomatisasi dasar: auto-trial/auto-lock, auto-report, auto-KYC; secret di-mask; audit_logs
- Update dokumen (KASIRGO-WORKFLOW-LENGKAP, AGENTS) + tracker; QA ubah config -> app ikut berubah
Update PROGRESS-PHASE7.8.md: SELESAI Phase 7.8 + BERIKUTNYA Phase 8. commit+push, STOP.
```

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

### PHASE 7.8 - Monetisasi & Program Pendukung (1 harga Rp50k) + Iklan Pelanggan + Laporan ke Bos + KYC Wajib + Panduan + Skala Superadmin
Lihat BAGIAN 7E (ST7.8-1 s/d ST7.8-9). Ganti 3 tier jadi 1 harga Rp50.000/bulan + trial 14 hari;
pindah sebagian fitur ke Pendukung; iklan hanya sisi pelanggan (web); laporan otomatis ke bos;
onboarding KYC wajib (app terkunci sampai verified); panduan PDF/video via Control Plane.

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

### PHASE 13A - QRIS Dinamis Midtrans (zero-custody, server-side)  [SELESAI KODE]
Tujuan: QRIS dinamis yang otomatis LUNAS lewat webhook, tanpa server key menyentuh APK.
Prinsip: **zero-custody** -- Server Key hanya di server (Supabase Edge Function + Vault),
terenkripsi at-rest; tidak pernah dikirim ke klien/APK.
- ST13A-1 (skema DB): tabel `outlet_pg_configs` (kredensial PG per outlet; server key
  disimpan sebagai `server_key_secret_id` = uuid `vault.secrets`). RLS owner-read +
  column-level grant: `authenticated` tidak bisa membaca `server_key_secret_id`; `anon`
  tanpa akses. `transactions` + kolom `provider_ref`, `paid_at`. RPC
  `get_outlet_payment_config(outlet)` mengembalikan config ter-mask. `platform_integrations`
  key `payment_gateway` -> provider `midtrans` (base_url sandbox + production); `pg_duitku` dihapus.
- ST13A-2 (EF `save_payment_config`): verifikasi JWT = owner outlet; simpan server key ke
  Vault via RPC `vault_put_secret` (EXECUTE hanya service_role); upsert `outlet_pg_configs`;
  kembalikan config ter-mask. `payment_orders.provider_order_id` untuk id order Midtrans.
- ST13A-3 (EF `test_payment_connection`): validasi kredensial tanpa efek samping (probe
  status order dummy; 401 = invalid, 404/200 = valid); update status verified/pending.
- ST13A-4 (EF `create_payment`): ambil kredensial outlet + server key dari Vault; Midtrans
  Core API `POST /v2/charge` `payment_type=qris` (Basic auth `Base64(ServerKey:)`); simpan
  `payment_orders` (provider midtrans, qris_string, qris_url, transaction_id, expiry) dan
  kembalikan `qr_string` + `provider_ref`.
- ST13A-5 (EF `midtrans_webhook`): verifikasi signature
  `SHA512(order_id + status_code + gross_amount + ServerKey)`; map
  `transaction_status`/`fraud_status` -> PAID/PENDING/EXPIRED/FAILED/REFUND; **idempotent**;
  aktivasi langganan bila `purpose='subscription'`; tandai `transactions.payment_status='paid'`
  + `paid_at` + `provider_ref`. Signature salah -> 401.
- Migrasi: `docs/migrations/2026-10-12-kasirgo-13a-midtrans-schema.sql`,
  `2026-10-12-kasirgo-13a-midtrans-2.sql`.
- Catatan deploy: `midtrans_webhook` harus `verify_jwt=false`; `create_payment` /
  `save_payment_config` / `test_payment_connection` `verify_jwt=true`.
- Kredensial per outlet diisi owner via UI (merchant_id + client_key + server_key);
  server key hanya dikirim sekali ke EF lalu disimpan terenkripsi.

### PHASE 13B - Retrofit App ke Midtrans (zero-custody)  [SELESAI]
Tujuan: aplikasi memakai Midtrans untuk QRIS dinamis (LUNAS otomatis via webhook),
menggantikan RCB. Server Key tetap hanya di server/Vault.
- ST13B-1 (`payment_service.dart`): lapisan `PgProviderClient` + `MidtransProvider`
  (facade `PaymentService`). `createQris` memanggil EF `create_payment`;
  `checkStatus` membaca tabel `payment_orders` (di-update webhook); `confirmPaid`
  no-op (webhook = sumber kebenaran). `PgPaymentOrder.providerOrderId` (dulu
  `rcbOrderId`); `fromApi` toleran terhadap variasi field. `getFinancialConfig`
  async dari RPC `get_financial_config` (min/max/free nyata) + cache SharedPreferences;
  `loadProviderConfig` dari RPC `get_outlet_payment_config` (ter-mask). Hapus
  dependensi RCB/`get_pg_client_config`/`sandbox_direct`. Hapus cabang auto-pay
  "Pembayaran Gratis" (`free_threshold` = ambang biaya platform, bukan pembayaran gratis).
- ST13B-2 (`checkout_dialog.dart`): render QR asli dari `qr_string` (QrImageView),
  panel status menunggu + polling 5 detik auto-update saat PAID/EXPIRED, batas
  nominal dari `_finCfg`. `supporter_service.dart`/`supporter_screen.dart` ikut
  memakai `providerOrderId`.
- ST13B-3 (wizard `screens/owner/midtrans_connect_screen.dart`): status koneksi,
  panduan 3 langkah + deep link Access Keys, form Merchant ID/Client Key/Server Key
  (obscure, tidak pernah ditampilkan kembali), toggle Produksi/Sandbox, Tes Koneksi
  (simpan via EF `save_payment_config` + probe via EF `test_payment_connection`).
  Entry: Pengaturan > "Hubungkan Midtrans (QRIS Dinamis)".
- Gating: QRIS dinamis hanya untuk peserta Pendukung/trial
  (`hasFeature('payment_gateway')`), else dialog Pendukung; QRIS statis tetap
  gratis sebagai fallback.
- Commit: ST13B-1 `3b6765a`, ST13B-3 `6cddb0a`.
- BLOCKER EKSTERNAL: channel QRIS akun Midtrans production belum diaktifkan
  (`402 Payment channel is not activated`) -> charge nyata belum menghasilkan
  `qr_string`. Alur webhook -> PAID sudah terbukti lulus (Phase 13A).

### PHASE 13C - Superadmin kelola Payment Gateway + uji sandbox + go-live  [SELESAI]
Tujuan: superadmin mengelola status Payment Gateway tiap outlet dari Control Plane
(tanpa melihat Server Key), lalu uji sandbox end-to-end, go-live, dan audit keamanan.
- ST13C-1 (SELESAI): migrasi `docs/migrations/2026-10-13-kasirgo-13c-superadmin-pg.sql`:
  - `admin_list_outlet_pg_configs()` -> JSONB daftar outlet + status PG ter-mask
    (provider, merchant_id, client_key, has_server_key, is_production, status,
    last_tested_at, last_test_result). SECURITY DEFINER + cek `is_platform_admin()`;
    tidak pernah mengembalikan `server_key_secret_id`.
  - `admin_set_outlet_pg_status(p_outlet, p_status)` -> `verified|disabled|pending`,
    menulis `log_admin_action('outlet_pg.set_status', ...)`.
  - UI superadmin tab "Payment Gateway" (`ControlPlane.tsx`): tabel "Status Payment
    Gateway per Outlet" (badge Aktif/Nonaktif/Menunggu/Belum diatur, mode
    Produksi/Sandbox, hasil tes terakhir, tombol Tes + Aktifkan/Nonaktifkan).
    Helper `src/lib/controlPlane.ts`: `listOutletPgConfigs`/`setOutletPgStatus`.
  - EF `test_payment_connection` kini juga mengizinkan superadmin (selain owner);
    EF `create_payment` menolak outlet ber-status `disabled` (403).
- ST13C-2 (SELESAI): uji E2E sandbox outlet percontohan **Warung Test**
  (`5dda8727-...`, owner `ikhlassabar2021+warung@gmail.com`), mode `is_production=false`.
  Kredensial sandbox disimpan via EF `save_payment_config` (Server Key -> Vault).
  Hasil (semua lulus):
  1. `test_payment_connection` -> `valid:true, http_status:200` ("Kredensial valid"),
     status config -> `verified`.
  2. `create_payment` QRIS sandbox (Rp 11.008) -> `success:true`, `status:PENDING`,
     `qris_string` dinamis terbit + `qris_url` (PNG 200) + `expired_at`.
  3. Webhook `settlement` (signature SHA512 valid) -> `status:PAID`;
     panggil ulang -> `idempotent:true`.
  4. Signature salah -> **401** "Invalid signature" (ditolak).
  5. Alur POS penuh: transaksi `unpaid` dibuat -> charge QRIS dengan
     `transaction_id` -> webhook settlement -> `payment_orders.status=PAID` +
     `transactions.payment_status='paid'`, `paid_at` terisi, `provider_ref`=order id.
- ST13C-3 (SELESAI):
  - **Audit keamanan** (detail di `docs/GO-LIVE-PAYMENT-GATEWAY.md`): tidak ada kunci
    di repo/history/bundle; hanya anon key; RLS + kolom grant + Vault benar; webhook
    signature + idempotent benar. REMEDIASI: `create_payment` kini memvalidasi
    `transaction_id` (milik outlet, belum dibayar, nominal = `final_amount`) —
    terverifikasi 400/403/409. Regression E2E POS lulus setelah deploy.
  - **Dokumen go-live**: `docs/GO-LIVE-PAYMENT-GATEWAY.md` — checklist go-live per
    outlet (aktifkan channel QRIS, Notification URL webhook, uji nominal kecil),
    rekomendasi rotate Server Key, dan perbandingan provider QRIS dinamis alternatif
    berizin PJP (Xendit/iPaymu/Tripay/Duitku) — rekomendasi Xendit atau iPaymu;
    arsitektur `PgProviderClient` siap tambah provider tanpa ubah UI.
  - Catatan QRIS statis vs dinamis: QRIS statis (GoPay/QR tetap toko) tidak bisa
    otomatis (tanpa webhook); tetap tersedia sebagai fallback gratis. QRIS otomatis
    memerlukan channel QRIS API (dinamis) di provider PJP.

### PAYMENT GATEWAY RCB - Provider-aware + zero-custody  [SELESAI]
Tujuan: aplikasi memilih provider Payment Gateway otomatis dari config superadmin
(TANPA ubah kode); semua charge/poll lewat Edge Function (zero-custody).
- Provider dibaca dari RPC `get_pg_client_config` (cache prefs):
  `RcbProvider` (default) atau `MidtransProvider`, dari
  `platform_integrations.payment_gateway.provider`.
- Superadmin dapat mengganti provider (RCB/Midtrans) + mode (sandbox/production)
  via Control Plane tab Payment Gateway tanpa ubah kode.
- Zero-custody: `api_key` TIDAK lagi dikembalikan `get_pg_client_config`;
  semua charge/poll RCB lewat Edge Function.
- FIX EF `rcb_create_charge`: `expired_time` epoch (int) dikonversi ke ISO -> kolom
  `expired_at` timestamptz (sebelumnya insert gagal senyap -> webhook "Order tidak
  ditemukan"); ditambah cek error insert.
- Migrasi `2026-10-08-kasirgo-rcb-provider-normalize.sql` (config -> provider rcb +
  mode sandbox_server).
- E2E LULUS: `create_supporter_checkout` -> `rcb_create_charge` (subscription) ->
  webhook SHA256 PAID -> `supporters` active +30 hari; `confirm_pg_order` (polling
  fallback) OK. Default = RCB sandbox.
- Catatan mode `sandbox_direct` (API key di klien) = HANYA untuk tes; wajib pindah ke
  Edge Function (`sandbox_server`/`live_server`) sebelum produksi.

### PHASE 13C (tambahan) - QR Meja food-only + Laporan kasir + backup bulanan + afiliasi mandiri  [SELESAI]
Bukan phase baru; penyempurnaan pasca-13C. Migrasi
`2026-10-06-kasirgo-13c-fixes.sql`.
- QR Meja (pelanggan) hanya untuk outlet food (cafe/resto/warteg); non-food pakai
  katalog biasa.
- Laporan kasir (rekap shift) + backup bulanan.
- Hapus UI asuransi (micro-insurance) dari app.
- Pendaftaran afiliasi mandiri (owner daftar sendiri dari app).

### PHASE 14 - Dokter Bisnis AI  [SELESAI]
Tujuan: asisten AI "Dokter Bisnis" (diagnosa -> resep -> evaluasi) untuk owner
gaptek. Provider LLM dikonfigurasi superadmin (Control Plane); `api_key_enc` hanya
service_role. Skema doctor + EF LLM + tab superadmin + chat owner.
- ST14-1 `f2c618b`: migrasi `docs/migrations/2026-10-06-kasirgo-14-dokter-bisnis.sql`:
  7 tabel (`outlet_ai_configs`, `doctor_conversations`, `doctor_messages`,
  `doctor_memory`, `doctor_intake`, `doctor_action_logs`, `doctor_outlet_profile`)
  + index + seed `platform_configs.business_doctor` + RLS (`is_outlet_owner`/
  `is_platform_admin`) + view `outlet_ai_configs_public` (tanpa `api_key_enc`,
  kolom `has_api_key`) + helper `outlet_supporter_active()`.
- ST14-2 `b1cd1b8`: EF `business_doctor_chat`: konteks bisnis via tools
  (snapshot/trend/stok/kas/memori), tool-loop maks 2 putaran, output
  `{reply,blocks,phase,memory}` (block types text/card/gauge/checklist/choices/
  action), gating `outlet_supporter_active`, provider override outlet else
  `platform_configs.business_doctor.provider_default`, fallback "Otak penuh belum
  aktif", regex FORBIDDEN, simpan messages/memory.
- ST14-3 `32992a5`: Control Plane admin tab "Dokter Bisnis AI" (`DoctorTab`):
  config global (aktif/bahasa/prompt/guardrails/internet_tool/provider_default),
  tombol Tes Koneksi Provider + Chat Uji pilih outlet. EF mode `test_provider`
  (superadmin-only) + superadmin bypass membership/gating.
- ST14-4 `a6e6457`: app owner: `business_doctor_service.dart` (klien EF),
  `business_doctor_screen.dart` (welcome 4 tombol besar: Diagnosa Usaha / Kenapa
  Omzet Turun / Saran Promosi / Cek Stok & Kas + kotak chat + renderer blocks +
  indikator loading + disclaimer), `widgets/common/business_doctor/doctor_blocks.dart`,
  kartu "Dokter Bisnis AI" di beranda owner.
- ST14-5 `e30dde5`: intake wizard "Cek Fisik Toko" (3 langkah bergambar:
  fisik/tampilan/perilaku, progress bar, catatan opsional) ->
  `doctor_intake_screen.dart`; ringkasan dikirim sebagai pesan diagnosa. EF
  `business_doctor_chat` (redeploy): definisi ALUR FASE A/B/C di system prompt
  (A diagnosa -> B resep -> C evaluasi).
- ST14-6: Peta Resep + Vonis + tool `save_prescription`. EF (redeploy): tool
  `save_prescription(verdict, steps[<=8])` simpan ke `doctor_memory` kind
  `prescription`; app `_handleAction`/`_actionScreen` memetakan `action_key` ->
  layar existing. Lanjutan: layar HASIL Diagnosa `doctor_result_screen.dart`
  (header+tanggal, gauge skor animasi, kartu vonis, peta resep checklist bernomor,
  target/timeline, footer).
- ST14-7: Catat Hasil Promosi + ROI + web tool. App
  `doctor_promotion_log_screen.dart` (chips jenis promosi/kanal/hasil + biaya &
  omzet tambahan + kartu ROI live) -> `BusinessDoctorService.logPromotion()`
  insert `doctor_action_logs`. EF: tool `get_action_history` + `fetch_url`
  (web tool, gated `internet_tool.aktif`, guard SSRF host privat), aturan fase C
  (hitung ROI).
- ST14-8: Escalation Ladder. EF: tool `escalate_case(level 1-3, root_cause,
  reason)` -> update `doctor_conversations` (`status`: level>=3 `kasus_bandel`
  else `evaluasi_ulang`, `escalation_level`) + `doctor_memory` kind `lesson`.
  App: banner Evaluasi Ulang / Lini Kedua / Kasus Bandel.
- ST14-9: Memori jangka panjang + "Riwayat Kasus". App: `listConversations`/
  `listMemories`/`listMessages`; layar `doctor_cases_screen.dart` (2 seksi: Kasus
  Konsultasi + Catatan Memori). Memori jangka panjang
  (`doctor_outlet_profile.memory_digest`). CATATAN: cron `doctor_observe` DITUNDA
  (pg_cron/pg_net tidak terpasang) -> jalankan manual via admin.
- ST14-10: Override provider AI per outlet (superadmin) + rate limit/kuota harian.
  Migrasi `docs/migrations/2026-10-14-kasirgo-14d-ai-override-ratelimit.sql`:
  RPC `admin_list_outlet_ai_configs()`, `admin_set_outlet_ai_config(outlet,config)`,
  `admin_delete_outlet_ai_config(outlet)`, `doctor_daily_usage(outlet)`. EF
  `business_doctor_chat`: rate limit non-superadmin (config
  `business_doctor.rate_limit {messages_per_day=60, tokens_per_day=200000}`).
  Admin DoctorTab: field Batas Pemakaian Harian + kartu "Override Provider per
  Outlet".
- ST14-11: migrasi `2026-10-17-kasirgo-14e-observe-reprimand.sql`:
  `doctor_action_logs` + status/due_date/reminder_count/last_reminded_at;
  `doctor_memory` + data/resolved_at + kind reprimand/market/scaling. EF chat tool
  `observe_progress` (omzet 7d vs 7d -> improving/flat/declining). EF BARU
  `doctor_observe`: evaluasi resep overdue -> achieved/failed + memori kind result;
  teguran bertingkat level 1/2/3 (anti-spam 1/hari/outlet). App: banner teguran +
  chip alasan. Admin: tombol Jalankan Observasi.
- Penutup celah: migrasi `2026-10-16-kasirgo-14d-unlimited-token-quota.sql`
  (`outlet_ai_configs.unlimited_tokens` + `token_quota`); EF kuota per outlet.
- Perbaikan pasca-test `2dbc202`: `max_tokens` default 4000 + guard; CTA "Cek
  Fisik Toko" permanen; tombol "Evaluasi Resep"; EF push assistant tool_call
  sebagai objek bersih + `extractJson` brace-matching.
- Detail: `PROGRESS-PHASE14.md`.

### PHASE 15 - Master Prompt Karakter & Skill + 12 Fitur Bos Virtual  [SELESAI]
Tujuan: karakter "Bos Virtual" dengan master prompt + daftar skill, plus fitur
analitik & growth (bundling, referral, cross-sell, laporan mingguan, observasi
otomatis, benchmark hyperlocal, persetujuan aksi). Detail: `PROGRESS-PHASE15.md`.
- 15A ST15-1 (Master Prompt + Daftar Skill): migrasi
  `docs/migrations/2026-10-15-kasirgo-15a-master-prompt-skills.sql` merge
  `platform_configs.business_doctor`: `prompt_utama` (master prompt + addendum
  A-O), `prompt_utama_default` (tombol Reset ke Default), `skills[]` (16 skill).
  EF `business_doctor_chat`: `SKILL_TOOLS` peta skill->tool, `toolAllowed()`,
  `toolsFor()`, system context "SKILL AKTIF: ...", tool loop 2->3 putaran. Admin
  `DoctorTab`: field "Master Prompt Karakter & Skill" + Preview + Reset + toggle
  "Daftar Skill" (chip 16 skill).
- 15B ST15-2 (Bos Virtual Analitik): analitik lanjutan (trend, anomali, ABC,
  margin alert) di EF + block baru di app.
- 15C ST15-3 (Bos Virtual Growth): migrasi
  `docs/migrations/2026-10-19-kasirgo-15c-bos-virtual-growth.sql`:
  `product_bundles` + `product_bundle_items`; `referral_codes` +
  `customer_referrals`; RLS owner/superadmin; RPC `increment_referral_redeemed`;
  RPC publik `get_public_bundles(TEXT)`.
  EF: tool BARU `get_cross_sell` (association rule 200 transaksi terakhir:
  support/confidence/lift), `save_bundle`, `save_referral`; `SKILL_TOOLS`
  +`cross_sell`,`bundling`,`referral`.
  App: `utils/ai_engine.dart` `crossSellRules()`; `services/growth_service.dart`;
  `screens/owner/bundle_manager_screen.dart` + `referral_screen.dart`; POS strip
  bundling + chip cross-sell; owner home kartu Peluang Cross-Sell; katalog
  pelanggan strip "Paket Hemat".
- 15D ST15-4 (Addendum L-O + Hardening): migrasi
  `docs/migrations/2026-10-20-kasirgo-15d-addendum-hardening.sql`:
  `doctor_memory` kind +`weekly_report`; `doctor_outlet_profile`
  +`health_score`/`active_disease`/`active_disease_since`/`last_weekly_report_at`;
  tabel BARU `doctor_pending_actions` + RLS.
  EF chat: tool BARU `propose_action` (guardrail M: tulis pending, JANGAN eksekusi
  langsung) + `benchmark_hyperlocal` (N: agregat anonim `hyperlocal_reports`,
  `need_verification` bila <3 outlet); `SKILL_TOOLS` +`market_intel`/
  `weekly_report`; output +`identity` (O).
  EF `doctor_observe`: laporan mingguan maks 1/pekan/outlet (gate
  `last_weekly_report_at`) isi `doctor_memory` kind `weekly_report` + update profil.
  App: kartu Identitas Bisnis (O), kartu Laporan Mingguan (L), kartu Persetujuan
  Aksi Setujui/Tolak (M).
- BLOCKER tetap: pg_cron/pg_net tidak terpasang -> jadwal via admin/Dashboard;
  Midtrans production QRIS belum aktif.

### DELTA TERBARU (2026-09-29) - Pesanan Dine-in QR Meja (Pelanggan -> Kasir/Dapur)
Bukan phase baru; menyempurnakan alur QR Meja pelanggan yang sudah live.
- Pelanggan: katalog + keranjang gaya POS (`CartContent`), checkout **bayar di meja**
  (QRIS/transfer bank-e-wallet/tunai) di `customer_order_screen.dart`.
- Owner: dialog "QRIS & Pembayaran Toko" di Pengaturan menyimpan info bayar ke DB
  (`outlet_payment_configs`) -- teks saja, tanpa gambar.
- Kasir: menu **"Pesanan Masuk"** (`screens/cashier/incoming_orders_screen.dart`) + badge jumlah
  pesanan aktif di POS; Realtime (`transactions`), rincian item, nomor meja, metode bayar,
  tombol Proses -> Siap Saji -> Selesai.
- Dapur (KDS owner): `kitchen_display_screen.dart` kini pakai data nyata `getDineInOrders` +
  status tersinkron ke DB + auto-refresh Realtime.
- Migrations: `docs/migrations/2026-09-29-customer-dinein-payment-method.sql` (opsional, tercakup),
  `2026-09-29-outlet-payment-at-table.sql`, `2026-09-29-dinein-orders-realtime.sql`.
- Catatan platform: di WEB, SQLite = no-op stub, jadi data (termasuk `customers`) langsung ke Supabase
  (teks/angka, biaya sangat kecil). Di APK, produk/transaksi/`customers` ada di SQLite lokal + sync;
  `customers` tidak ikut antrean sync. Foto produk selalu LOKAL (tidak pernah diunggah).

### DELTA PASCA-PHASE - BATCH Perbaikan Owner & Superadmin (#1 - #5)  [SELESAI]
Bukan phase baru; batch bugfix hasil testing user. Detail: `AGENTS.md` + `TESTING-CHECKLIST.md`.
- BATCH #1 (FIX #1-#17, commit `7629155`..`d420c83`): login email belum dikonfirmasi;
  KYC NIK tahun lahir 2 digit + marker KTP; dialog sukses checkout baru +
  Struk PDF; field Nama Pelanggan + auto-create pelanggan dari nomor WA; dialog
  tambah/hapus pelanggan diperindah; FK `transaction_items` ON DELETE SET NULL
  (fix hapus produk); PPOB/Kulakan/Modal Usaha disembunyikan; checkout QRIS
  statis-only; QR Meja tambah via keyboard; Riwayat Kasus filter + hapus;
  hardening balasan AI; laporan Excel/PDF SAK EMKM; affiliate owner + superadmin
  (`outlet_affiliate_profiles`/`outlet_affiliate_closings`); sembunyikan laporan
  PPOB/PG dari superadmin.
- BATCH #2 `7d57a00`: resep 2 tombol (Jalankan + Tandai Selesai); kirim struk
  Text/PDF ke WA; KYC hardening (NIK 16 digit, magic bytes gambar); gating Dokter
  Bisnis AI; trial/upgrade jalur dua (Trial + QRIS Dinamis Pendukung).
- BATCH #3 `672286b`: fix `submit_kyc` kolom salah (`phone`/`auto_verified`/
  `verified_at`) + auto-verify -> migrasi
  `2026-10-22-kasirgo-fix-submit-kyc-columns.sql`; wording login; tombol X dialog
  hapus produk; sinkron kartu resep saat Tandai Selesai; `cross_sell` buka POS.
- BATCH #4 `731fb3b`: CORS di 5 EF (`rcb_create_charge`, `rcb_check_status`,
  `create_payment`, `save_payment_config`, `test_payment_connection`) -> fix QRIS
  dinamis gagal diam-diam di browser; hapus menu "Hubungkan Midtrans" + kartu
  Konfigurasi Platform dari Pengaturan owner; hapus outlet via RPC
  `delete_owner_outlet` (migrasi
  `2026-10-23-kasirgo-fix-delete-owner-outlet.sql`).
- BATCH #5 `ff04bb3`: fix QRIS Dinamis tak muncul saat "Dukung KasirGo" dari
  Pengaturan. Root cause: `settings_screen.dart` `_handleSupport` hanya SnackBar,
  hasil QR dibuang. Fix: widget bersama BARU
  `kasirgo/lib/widgets/common/dynamic_qris_sheet.dart` (`DynamicQrisSheet`, QR +
  polling `rcb_check_status`), dipakai `SupporterScreen` DAN `settings_screen.dart`.
- KEBIJAKAN QRIS: pembayaran PRODUK di POS = QRIS Statis manual
  (`checkout_dialog.dart` static-only); QRIS Dinamis otomatis HANYA di alur
  upgrade Program Pendukung.

---

## BAGIAN 9 - TEST LIVE PER PHASE

Setelah phase selesai: jalankan dev server, minta URL preview, uji pakai klik, laporkan
(URL + yang diklik + hasil + error). Jangan hanya bilang "build sukses".

Flutter (JANGAN `flutter run -d web-server` -> "VM offline"/disk penuh; pakai build statis):
```
cd kasirgo
flutter build web --release --base-href /kasirgo/
python3 -m http.server 8080 --directory build/web
```
Alternatif tanpa relay: deploy `build/web` ke GitHub Pages / Cloudflare Pages.
React admin:
```
npm run dev
```
Catatan: fitur native (kamera/scan barcode, SQLite SQLCipher, image_picker) TIDAK jalan di web.
Fitur ini diuji via APK debug di HP. Yang bisa diuji di web: UI, navigasi, auth, CRUD Supabase,
chart, POS, PPOB mock, WA intent, Program Pendukung, KYC (tanpa kamera), panduan, iklan pelanggan.

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
| Monetisasi user | Subscription gate + iklan | Program Pendukung SATU harga Rp50.000/bulan + reverse trial 14 hari (fitur pertumbuhan) |
| Iklan | Banner di app free tier | Iklan hanya di halaman pelanggan (web katalog/QR); owner tidak lihat; Pendukung ad-free; tanpa iklan tersembunyi |
| QRIS | Manual | Dynamic QRIS + webhook HMAC + split settlement |
| QRIS mode | 1 mode (manual) | Dual-Mode: Statis (MDR 0%) + Dinamis (auto LUNAS) |
| Onboarding | Form/email/OTP + login | Zero-friction: Anonymous Auth + Device UUID -> **KYC WAJIB** (6 field + KTP + selfie) auto-verify; **app terkunci sampai verified** |
| Laporan | Manual | Laporan otomatis ke bos (harian/mingguan/bulanan, bisa diset) via WA pribadi one-tap + email/PDF |
| Panduan | Tidak ada | Panduan penggunaan PDF + video, link/content diatur superadmin (Control Plane) |
| Dana | Tidak diatur eksplisit | Zero-touch money: escrow PG PJP BI + direct settlement + BI-FAST |
| Biaya/margin | Hardcode | Dinamis via `platform_financial_configs` (superowner real-time) |
| Integrasi | Hardcode di koding | Control Plane `platform_integrations` (PG/PPOB/B2B/Fintech/R2/DB/WA/Iklan/Panduan) -- edit superadmin tanpa koding |
| Izin | Sama rata | Owner hapus produk + kelola staf (kuota 1 Admin + 1 Kasir); Admin tanpa hapus |
| Arsitektur | POS generik | Modular `outlet_type` |
| Modul | Produk/POS/AI/laporan/pelanggan/karyawan | + Kasbon, BOM/Resep, KDS/QR meja, Variant, Shift/Tip, PPOB, B2B Restock, Fintech |
| Keamanan | SQLite biasa | SQLCipher + flutter_secure_storage |
| Sync | Last-write-wins | Event-sourcing / delta log + background Isolate |
| Superadmin | Subscription/revenue/affiliate | 12 revenue engine + supporters + data + Control Plane + skala (config inheritance, feature flags, RBAC, rules engine, audit, monitoring) |
| UI/Theme | Dark Glassmorphism (indigo) | Centennial Modern Ocean White (light) - Phase 7.6 |

OBSOLETE (buang di 5.5B): subscription tier, iklan banner free, limit 500.
OBSOLETE (diganti Phase 7.8): 3 tier Program Pendukung (Pendukung/Pro/Setia) -> satu harga Rp50.000/bulan.

---

## BAGIAN 12 - PRASYARAT EKSTERNAL (belum ada)
- Akun Payment Gateway resmi berizin PJP BI (Tripay/Xendit/Duitku/Midtrans) + kredensial sandbox + webhook secret HMAC -> Phase 7.5
- Persetujuan Master Account / Payment Facilitator (split-payment + escrow) -> Phase 7.5
- API key PPOB (Digiflazz/IAK/RCB) -> Phase 9
- Akun partner fintech/insurtech -> Phase 10
- Cloudflare R2 bucket -> thumbnail opt-in (koneksi diset di superadmin, Phase 7.7)
- Link affiliate distributor B2B (kulakan) -> Phase 7.7/7.8 (set di superadmin)
- Kredensial koneksi database (url/user/password/apikey, mis. Supabase) -> Phase 7.7/7.8 (set di superadmin)
- WA mode Pribadi (default, nomor KYC via `wa.me`) TIDAK butuh API key; WA Cloud API opsional -> Phase 7.8/11
- Akun Adsterra (opsional, fallback) + daftar sponsor lokal FMCG -> Phase 7.8 (Control Plane tab Iklan)
- Isi `config/supabase_config.dart` + kredensial Edge Function (service_role hanya di server)
- Aktifkan Supabase Anonymous Auth (untuk onboarding zero-friction) -> Phase 7.5
