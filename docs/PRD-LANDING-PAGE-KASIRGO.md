# PRD — Landing Page KasirGo

- **Status:** Draft (menunggu review)
- **Pemilik:** KasirGo
- **Tanggal:** 06 Nov 2026
- **Terkait:** Design System v2 "Centennial Modern Ocean White" (docs/KASIRGO-WORKFLOW-LENGKAP.md Bagian 1.6)

---

## 1. Ringkasan Eksekutif

KasirGo belum memiliki halaman pemasaran (marketing site) untuk calon pengguna. Saat ini
`https://dokterbisnis.web.id/` langsung menampilkan aplikasi Flutter, dan `/admin/`
menampilkan superadmin. Akibatnya, orang yang baru mendengar KasirGo tidak punya satu
tempat untuk memahami: apa itu KasirGo, fitur apa, berapa harganya, dan cara mulai.

Dokumen ini mendefinisikan **landing page KasirGo**: satu halaman pemasaran statis yang
menjelaskan produk, fitur, harga, dan ajakan bertindak (CTA) untuk **pemilik usaha UMKM
Indonesia**, sekaligus menyediakan jalur masuk ke aplikasi.

---

## 2. Latar Belakang & Masalah

- Tidak ada "pintu depan" yang menjual produk ke calon pengguna baru.
- Link aplikasi langsung tanpa konteks → calon pengguna bingung, konversi rendah.
- Informasi fitur & harga tersebar (APK, dokumen, chat) → sulit dibagikan (share link).
- Butuh aset yang siap dipakai untuk iklan / WA blast / QR poster / referensi afiliasi.

## 3. Tujuan (Goals)

| # | Tujuan | KPI |
|---|--------|-----|
| G1 | Meningkatkan pendaftaran akun KasirGo | Jumlah klik "Daftar/Unduh" → jumlah signup baru |
| G2 | Mengkomunikasikan proposisi nilai & harga secara jelas | Waktu baca + bounce rate + scroll depth |
| G3 | Menjadi titik rujukan resmi (shareable) | Jumlah share / backlink / kunjungan organik (SEO) |
| G4 | Mendukung konversi ke Program Pendukung | Klik "Beli/Rp50.000" → checkout supporter |

## 4. Target Audiens (Persona)

**Primer — Pemilik UMKM:**
- Warung Madura, warung sembako, kelontong, retail, cafe, restoran, kedai kopi,
  minimarket, toko baju, apotek, gerobak, jasa.
- Karakter: non-teknis, HP Android entry/mid, WhatsApp-centric, modal terbatas,
  butuh hasil cepat (naik omset, kontrol stok & kas, laporan sederhana).

**Sekunder:**
- Staf pemilik (admin/kasir) yang ikut memilih tools.
- Afiliasi & mitra (butuh link referral + materi promosi).
- Calon mitra PJ/agen (masuk via portal afiliasi/admin).

## 5. Ruang Lingkup

**In scope:**
- Halaman pemasaran satu halaman (dengan anchor nav) + halaman turunan opsional:
  `/harga`, `/faq`.
- Copy + visual sesuai Design System v2.
- CTA: Unduh APK, Buka Aplikasi, Daftar, Hubungi WA, Masuk Admin (opsional).
- **CMS ringan (seperti WordPress)** agar superadmin bisa mengubah tampilan/konten
  frontend + pengaturan email, Pixel Meta Ads/Google Ads, SEO, dan WhatsApp
  TANPA ubah kode (lihat Bab 12).

**Out of scope (untuk fase ini):**
- Blog/artikel, dashboard akun.
- Aplikasi web KasirGo itu sendiri (sudah ada).

---

## 6. Struktur Halaman & Konten

Urutan section dari atas ke bawah (mobile-first, semua bisa di-anchor dari nav):

### 6.1 Navbar (sticky, glass/white)
- Logo KasirGo + nama.
- Menu anchor: Fitur, Harga, Testimoni, FAQ.
- Tombol CTA kanan: **"Unduh / Coba Gratis"** (primary), opsional "Masuk".

### 6.2 Hero
- Headline (value prop utama) + subheadline 1 kalimat.
- CTA ganda: **"Mulai Gratis"** (primary) + **"Lihat Demo / Hubungi WA"** (secondary).
- Visual: mockup HP (POS + grafik AI) atau ilustrasi singkat.
- Badge kecil kepercayaan: "Gratis selamanya untuk fitur inti".

### 6.3 Trust Bar / Bukti Sosial
- Deretan angka/logo: "N UMKM", "N transaksi/hari", rating, atau quote pengguna.
- (Tahap awal boleh placeholder sampai ada data nyata.)

### 6.4 Masalah → Solusi (singkat)
- 3 kartu masalah umum (catat manual, stok kabur, omzet tidak naik) → solusi KasirGo.

### 6.5 Fitur Utama (grid kartu)
Kelompokkan per kategori dengan ikon + 1 baris deskripsi:
1. **POS & Kasir** — transaksi cepat, QRIS, struk, shift kasir, tip.
2. **Produk & Stok** — stok otomatis, varian, layanan/jasa tanpa stok, peringatan stok.
3. **AI Co-Pilot & Dokter Bisnis AI** — diagnosa usaha, resep, prediksi penjualan.
4. **Katalog Online & QR Meja** — pelanggan scan → pesan (dine-in & takeaway).
5. **WhatsApp Commerce** — broadcast promosi, struk ke WA, retensi pelanggan.
6. **Laporan** — laba rugi (SAK EMKM), laporan ke bos, export Excel/PDF.
7. **Pelanggan (CRM)** — data pelanggan, kasbon/piutang, telepon/hubungi.
8. **Lapak Live (Hyperlocal)** — toko tampil di radar pembeli sekitar.
9. **PPOB & B2B** — jual pulsa/token, kulakan modal usaha (per tipe usaha).

### 6.6 Cara Kerja (3 langkah)
1. Daftar & atur toko (KYC) → 2. Tambah produk → 3. Jual & pantau omzet.
- Visual simpel: ikon + langkah bernomor.

### 6.7 Harga
- **Fitur inti: GRATIS selamanya** (POS, produk, stok, pelanggan, laporan dasar,
  1 admin + 1 kasir, QRIS statis).
- **Program Pendukung: Rp50.000/bulan** (satu harga, tanpa tier). Tampilkan daftar
  manfaat premium (lihat 6.7b).
- CTA: **"Aktifkan Program Pendukung"** (mengarah ke aplikasi → checkout QRIS).

#### 6.7b Manfaat Program Pendukung (list lengkap, bisa ringkas di halaman)
WA Marketing, Katalog Online, QR Meja Dine-in, AI Co-Pilot Pro, Health Score Pro,
Laporan Lanjutan, Export Excel, Export PDF, Backup Cloud, Multi-Outlet, Extra Staf,
Struk Kustom, Laporan Otomatis ke Bos, Bebas Iklan Pelanggan, Dokter Bisnis AI,
Sidak Stok & Kas, Atur Harga & Diskon (Dynamic Pricing), Laporan & Progres, Lapak Live.

### 6.8 Testimoni / Bukti
- 3–6 testimoni singkat pemilik warung/cafe (nama + jenis usaha + kota).
- (Placeholder dilengkapi setelah ada data; awalnya bisa pakai studi kasus anonim.)

### 6.9 FAQ (akordeon)
Minimal 8 pertanyaan:
- Apakah benar gratis? — Apa bedanya Program Pendukung?
- Apakah butuh internet terus? (offline-first)
- HP apa yang didukung? (Android APK; web untuk akses apa saja)
- Bagaimana data aman? (Supabase + RLS)
- Bisa tambah karyawan berapa? (gratis 1 admin + 1 kasir; lebih via Pendukung)
- Apakah bisa jual online / QR meja? — Bagaimana cara bayar (QRIS)?
- Bisa pindah dari catatan manual/Excel? (import? sebutkan bila ada)
- Siapa yang bisa bantu? (tiket bantuan + WA)

### 6.10 CTA Akhir (footer CTA)
- Ulangi proposisi utama + tombol **"Mulai Gratis Sekarang"** + link unduh APK.

### 6.11 Footer
- Logo, tautan: Fitur, Harga, FAQ, Kontak/WA, Kebijakan Privasi, Ketentuan.
- Link admin/afiliasi (kecil): "Masuk Admin" (opsional).
- Copyright + versi aplikasi.

---

## 7. Pesan & Copywriting

- **Tagline final (dipilih):**
  - ~~"Kasir pintar untuk naikin omset warungmu."~~
  - **"KasirGo — kasir, stok, dan AI peningkat omset dalam satu aplikasi."** ← TERPILIH
  - ~~"Dari catatan kertas ke omzet naik, satu aplikasi."~~
- **Tone:** hangat, langsung, ramah UMKM, hindari istilah teknis berlebihan.
- **Bahasa:** Indonesia (semi-formal, sapaan "kamu/Anda" konsisten).
- **CTA primer:** "Mulai Gratis" / "Unduh Aplikasi".
- **CTA sekunder:** "Lihat Demo" / "Chat WhatsApp".

---

## 8. Design System & Visual (wajib ikut DS v2)

| Tokoh | Nilai |
|-------|-------|
| Background | `#F8FAFC` |
| Surface | `#FFFFFF` + border `#E2E8F0` |
| Primary | `#0284C7` |
| Gradient | `#06B6D4` → `#0284C7` (badge AI: `#06B6D4` → `#4F46E5`) |
| Teks utama | `#0F172A` / sekunder `#64748B` |
| Sukses / Warning / Error | `#10B981` / `#F59E0B` / `#EF4444` |
| Font | Inter |
| Radius | 16 (kartu besar) / 12 (kartu kecil) |
| Shadow | halus (soft) |

- Responsif: Mobile 360–599, Tablet 600–859, Desktop ≥860 (max container ~1100px).
- Dilarang hardcode warna/font — pakai token (sejajar `config/app_theme.dart`
  + `tailwind.config.js`).
- Ilustrasi/mockup: Flat & bersih, dominan biru ocean + putih, konsisten dengan
  mockup panduan (`docs/tools/guide_images/`).

---

## 9. Interaksi & Fungsional

- Navbar smooth-scroll ke anchor; sticky di mobile & desktop.
- CTA utama menyimpan perangkat tujuan:
  - Android → link APK (arm64/armeabi-v7a/x86_64 di `/updates/` atau GitHub Release).
  - Web/lainnya → buka `https://dokterbisnis.web.id/` (atau subpath aplikasi).
- Tombol "Chat WhatsApp": deep link `https://wa.me/<nomor>`.
- Form opsional (fase 2): "Minta ditelepon" / email → kirim ke WhatsApp/supabase.
- FAQ: akordeon (1 terbuka per waktu) + anchor dari nav.
- Semua link eksternal (admin/afiliasi) dibedakan visual agar tidak membingungkan.

---

## 10. SEO, Analytics & Tracking

- `<title>` & meta description, Open Graph (judul, deskripsi, thumbnail), favicon.
- Sitemap + struktur heading yang benar (H1 tunggal di hero).
- Tracking minimal (bila disetujui): jumlah klik per CTA (ID event), tidak memakai
  cookie pihak ketiga berlebih — hormati UU PDP (consent untuk analitik bila perlu).
- UTM: `?utm_source=wa|ig|affiliate|qr&utm_medium=...` untuk mengukur kanal.

---

## 11. Persyaratan Non-Fungsional

- **Performa:** Lighthouse ≥ 90 (mobile), gambar WebP/AVIF, lazy-load, bundle kecil.
- **Responsif & aksesibel:** kontras teks cukup, alt text gambar, tap target ≥ 48px.
- **Keamanan:** tidak ada kunci/secret di halaman; semua kredensial tetap di server.
- **Tautan benar:** unduh APK & masuk aplikasi tidak pernah "404".
- **Offline-friendly:** konten utama tetap terbaca (static).

---

## 12. CMS / Admin Pengelolaan Landing Page (Persyaratan)

Tujuan: superadmin (admin) dapat mengubah konten, tampilan,
email, pixel iklan, SEO, dan WhatsApp dari dashboard admin TANPA menyentuh kode — pola
yang sama dengan Control Plane KasirGo. Ibarat WordPress, tetapi terbatas (guardrail)
agar tetap konsisten dengan Design System v2.

### 12.1 Akses & Izin (RBAC)
- Berlokasi di `kasirgo-admin` (`/admin/`), menu baru **"Website / Landing Page"**.
- **Admin saja** (superadmin) yang memegang akses penuh: konten, media, email, pixel,
  SEO, WA, tema. Tidak ada role editor/pemasaran terpisah.
- Setiap perubahan tercatat di `log_admin_action` (audit: siapa, apa, kapan).
- Secret hanya dibaca service_role; editor tidak pernah menerima nilai aslinya
  (tampil mask `****xxxx`).

### 12.2 Editor Konten (per section)
Setiap section halaman dapat di-edit (text + toggle tampil + urutan):
- **Navbar:** logo (upload), label menu, teks tombol CTA.
- **Hero:** headline, subheadline, teks CTA primer/sekunder, link tujuan, gambar/badge.
- **Trust Bar:** deretan angka + label (mis. "N UMKM", "N transaksi/hari") — editable.
- **Fitur:** daftar item (ikon, judul, deskripsi); tambah/hapus/urutkan/sembunyikan.
- **Cara Kerja:** langkah bernomor (judul + deskripsi).
- **Harga:** teks harga + daftar manfaat Program Pendukung (toggle tampil/hide per item).
- **Testimoni:** CRUD (nama, jenis usaha, kota, kutipan, foto opsional).
- **FAQ:** CRUD + urutan (pertanyaan + jawaban).
- **CTA Akhir & Footer:** teks, tombol, daftar link footer, copyright, versi.
- Editor teks ringan (field + optional markdown), dibatasi agar tidak merusak DS v2.
- **Draft vs Publish:** simpan draft → **Preview** → **Terbitkan**. Ada histori/versi
  sederhana (rollback ke versi terbit sebelumnya, minimal 1–3 versi).

### 12.3 Media
- Upload gambar/logo/foto testimoni → **Cloudflare R2** (WebP, batasi ukuran ±512px
  untuk thumb; original tersimpan terpisah) sesuai kebijakan penyimpanan KasirGo
  (R2, bukan Supabase Storage).
- Galeri media (browse, ganti, hapus) + preview.

### 12.4 Pengaturan Email
- **SMTP:** host, port, user (api key), password (secret, tersimpan terenkripsi),
  sender name/email, TLS/STARTTLS.
- **Template:** konfirmasi lead, balasan form, "terima kasih", notifikasi admin.
- **Test kirim email** (tombol) ke alamat yang diisi.
- Catatan: ini untuk kebutuhan **landing page** (form lead/notifikasi), terpisah dari
  Auth email aplikasi (tetap Supabase). Bila memungkinkan, sinkron satu sumber konfigurasi.

### 12.5 Pixel & Tracking (Meta Ads + Google Ads)
- **Meta Pixel:** Pixel ID + (opsional) Conversions API token (secret).
- **Google Ads:** Conversion ID + Conversion Label; **GA4** measurement ID; **GTM** ID.
- Toggle aktif/nonaktif per pixel/tracker.
- **Consent UU PDP:** banner consent ditampilkan lebih dulu; pixel/analitik dimuat
  hanya setelah persetujuan (kecuali tracker yang dikecualikan).
- Nilai secret (CAPI token) hanya service_role; publik JS hanya menerima Pixel ID,
  bukan token secret.
- Indikator "pixel terpasang" pada halaman (cek debug).

### 12.6 SEO
- **Per halaman:** title, meta description, slug/URL, canonical, OG title/description/
  image, robots (index/noindex).
- **Global:** site title, meta default, favicon, verification tag Google Search Console,
  auto-generate `sitemap.xml`, `robots.txt`; halaman admin noindex.
- Auto-fallback: bila tidak diisi, title/meta diambil dari konten hero.

### 12.7 Setting WhatsApp
- Nomor WA pusat (format `628xxx`) → dipakai semua tombol "Chat WhatsApp" (`wa.me/...`).
- Template pesan default (pre-filled text) per CTA.
- Opsional (fase lanjut): jam operasional / auto-reply.
- Satu sumber: seluruh CTA WA di landing memakai nomor ini.

### 12.8 Data Model (usulan tabel)
Pola Control Plane: setting di DB + cache + fallback default.
- `cms_pages` (id, slug, title, meta_title, meta_desc, og_image, robots, status,
  published_at, updated_by).
- `cms_sections` (id, page_id, key, type, content JSONB, sort_order, is_visible).
- `cms_media` (id, name, r2_key, alt, mime, size_bytes, uploaded_by).
- `cms_settings` (key, value JSONB) → email/pixel/SEO/WA; secret ter-mask/terenkripsi.
- Alternatif: email/pixel/WA/SEO mengikuti pola `platform_configs` + `secret_config`
  (secret hanya service_role); `cms_*` dipakai khusus untuk konten & media.
- RLS: REVOKE anon/authenticated pada kolom secret; superadmin via `is_platform_admin`.

### 12.9 Keamanan & Anti-XSS
- WYSIWYG/markdown di-sanitasi (larang script/iframe berbahaya) sebelum render.
- Secret tidak pernah dikirim balik ke browser editor (hanya status "tersimpan" + hint).
- Semua perubahan membutuhkan JWT superadmin (atau role diizinkan); permintaan anon ditolak.

---

## 13. Platform & Deploy (rekomendasi)

- **Stack:** static/SSG ringan — Vite + React (konsisten dengan `kasirgo-admin`) ATAU
  HTML/Tailwind statis. Pilih **Vite + React + Tailwind** agar satu pola dengan admin.
- **Deploy:** gh-pages (sama repo) atau integrasi domain `dokterbisnis.web.id`.
- **Routing (DIPUTUSKAN):** landing page di subdomain **`brandbisnis.web.id`**,
  aplikasi Flutter tetap di `dokterbisnis.web.id/`, admin tetap di
  `dokterbisnis.web.id/admin/`.
- **Konten:** statis (tidak butuh DB) untuk fase 1; testimoni/data angka bisa di-seed
  manual.

---

## 14. Kriteria Sukses (Acceptance Criteria)

1. Landing dapat diakses via URL yang disepakati (root/subdomain) tanpa 404.
2. Semua CTA mengarah ke tujuan benar (APK / aplikasi / WA / admin).
3. Harga & manfaat Program Pendukung terbaca jelas (Rp50.000/bln, tanpa tier ganda).
4. Tampil baik di 360px–1200px; tidak ada teks terpotong / overflow.
5. Lighthouse mobile ≥ 90, gambar teroptimasi.
6. Warna/font/radius mengikuti DS v2 (tidak ada hardcode).
7. Ada meta SEO + Open Graph + favicon.
8. Semua link internal (anchor) berfungsi.
9. Superadmin dapat mengubah konten hero/fitur/harga/testimoni/FAQ dari admin tanpa
   menyentuh kode, dengan Draft → Preview → Terbitkan.
10. Pixel Meta Ads & Google Ads termuat hanya setelah consent (UU PDP), dan secret
    (CAPI token) tidak pernah bocor ke klien.
11. Pengaturan email (SMTP + template) dan WhatsApp (nomor + template) tersimpan aman,
    hanya service_role yang bisa membaca secret.
12. Perubahan konten/pengaturan tercatat di audit log.

---

## 15. Open Questions / Keputusan yang Dibutuhkan

### 15.1 Keputusan disepakati (06 Nov 2026)
1. **URL final:** landing page di subdomain **`brandbisnis.web.id`**; aplikasi tetap di
   `dokterbisnis.web.id/`, admin di `dokterbisnis.web.id/admin/` (Bab 13).
2. **Tagline final:** "KasirGo — kasir, stok, dan AI peningkat omset dalam satu aplikasi." (Bab 7).
3. **Pemilik akun (email / Pixel Meta Ads / Google Ads):** **admin** yang menyediakan dan
   mengelola kredensial (Bab 12.4 & 12.5).
4. **Role CMS:** **admin saja** (superadmin) — tidak ada role editor/pemasaran terpisah (Bab 12.1).

### 15.2 Masih terbuka
1. **Data bukti sosial:** apakah sudah ada jumlah UMKM/transaksi nyata untuk trust bar,
   atau pakai placeholder dulu?
2. **Testimoni:** sumber testimoni asli vs placeholder anonim.
3. **Form lead:** perlu form kontak (email/WA/telepon) di fase 1, atau CTA saja?
4. **Google Play/App Store:** link unduh final pakai APK langsung, atau rujukan Play
   (setelah rilis Play Store)?
5. **Analitik:** boleh pasang tracker (mis. GA4/Plausible)? butuh consent UU PDP? (jika
   dipasang, mode editor teks: WYSIWYG bebas vs field/markdown terbatas juga perlu
   dipastikan — default usulan field/markdown terbatas.)

---

## 16. Milestones (usulan)

- **M1:** Setup proyek + routing (subdomain `brandbisnis.web.id`) + navbar/hero
  (1 section terlihat).
- **M2:** Semua section (fitur, cara kerja, harga, FAQ, footer).
- **M3:** SEO + OG + favicon + visual (mockup/gambar) + responsif final.
- **M4:** Deploy + uji link/CTA + review copy → rilis.
- **M5 (CMS):** tabel `cms_*` + menu "Website / Landing Page" di admin + editor konten
  (hero/fitur/harga/testimoni/FAQ + Draft/Publish/rollback).
- **M6 (Pengaturan):** email (SMTP/template), Pixel Meta/Google Ads + consent, SEO,
  dan WhatsApp dari admin; secret hanya service_role + audit log.