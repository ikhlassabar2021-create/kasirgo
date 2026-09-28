# Checklist Test KasirGo — Phase 1 s/d 7

App: **https://ikhlassabar2021-create.github.io/kasirgo/**
Superadmin: **https://ikhlassabar2021-create.github.io/kasirgo/admin/**

Legenda: `[ ]` belum · `[x]` PASS · `[!]` FAIL · `[/]` BLOKIR · `[-]` tak bisa dites di web

> Sumber definisi phase: `docs/KASIRGO-WORKFLOW-LENGKAP.md` BAGIAN 4 + BAGIAN 8-9.

---

## Prasyarat (WAJIB)

Supabase → Authentication → URL Configuration:
1. [ ] Site URL = `https://ikhlassabar2021-create.github.io/kasirgo/`
2. [ ] Redirect URLs = `https://ikhlassabar2021-create.github.io/kasirgo/`
3. [ ] Confirm email = OFF

Akun test yang harus dibuat lewat `/register`:
- [ ] Owner Warung
- [ ] Owner Gerobak
- [ ] Owner Cafe

---

## Kondisi nyata per phase (baca dulu)

| Phase | Nama | Status nyata untuk test web |
|---|---|---|
| 1 | Supabase DB + Auth | Bisa test penuh (daftar/login/RLS) |
| 2 | App shell + Auth + Offline | Bisa test shell/auth; offline engine terbatas di web |
| 3 | Produk + POS + QRIS manual + AI Co-Pilot | Bisa test penuh |
| 4 | Laporan + Pelanggan + Karyawan | Bisa test penuh |
| 5 | Premium + Subscription gate | **OBSOLETE** — subscription dihapus, hanya cek tidak ada gate |
| 5.5A/B/C | Retrofit 3.0 (module, kasbon, sync) | Module & kasbon bisa; SQLCipher/secure storage `[-]` di web |
| 6 | Kasbon + WA + Sponsored Receipt | Kasbon & WA intent bisa; **banner sponsor tidak ada di kode** |
| 7 | Dynamic QRIS Gateway + webhook | **Tidak berfungsi** — butuh Edge Function + kolom DB yang belum ada. Yang bisa: QRIS manual/statis |

Catatan web (`BAGIAN 9`): kamera/scan barcode, SQLite SQLCipher, image_picker **tidak jalan di web**.

---

# PHASE 1 — Supabase DB + Auth

- [ ] 1.1 Registrasi owner (email+password) berhasil, langsung masuk dashboard
- [ ] 1.2 Logout → login ulang berhasil
- [ ] 1.3 Login pakai password salah → muncul error (tidak crash)
- [ ] 1.4 Register email yang sudah dipakai → error jelas
- [ ] 1.5 Login Google berhasil
- [ ] 1.6 Data tersimpan: outlet dibuat otomatis saat daftar (cek dashboard ada nama toko)
- [ ] 1.7 RLS: user A tidak bisa lihat data outlet user B (login 2 akun owner, pastikan produk beda)

# PHASE 2 — App Shell + Auth + Offline Engine

- [ ] 2.1 Halaman login tampil benar (rapi, tidak blank)
- [ ] 2.2 Navigasi antar halaman lancar (tidak ada layar putih)
- [ ] 2.3 Setelah login, diarahkan ke dashboard sesuai role (owner→/owner, kasir→/cashier, admin→/admin)
- [ ] 2.4 Refresh browser saat sudah login → tetap login (sesi tersimpan)
- [ ] 2.5 Buka app saat belum login → diarahkan ke `/login`
- [-] 2.6 Offline engine (SQLite/SQLCipher) — tidak bisa dites di web

# PHASE 3 — Produk + POS + QRIS Manual + AI Co-Pilot

- [ ] 3.1 Tambah produk (nama + harga) → muncul di daftar
- [ ] 3.2 Edit produk → perubahan tersimpan
- [ ] 3.3 Hapus produk (icon trash/tombol) → hilang
- [ ] 3.4 POS: pilih produk → masuk keranjang
- [ ] 3.5 POS: ubah qty → subtotal benar
- [ ] 3.6 POS: hapus item dari keranjang
- [ ] 3.7 Checkout bayar **Cash** → transaksi tersimpan
- [ ] 3.8 QRIS manual: owner isi QRIS di Pengaturan, checkout QRIS → **QRIS toko muncul**
- [ ] 3.9 QrisConfig tersimpan per-outlet (logout/login tetap ada)
- [ ] 3.10 AI Co-Pilot: insight/digest tampil di dashboard (atau cek pesan jika kosong)
- [-] 3.11 Scan barcode kamera — tidak bisa dites di web

# PHASE 4 — Laporan + Pelanggan + Karyawan

- [ ] 4.1 Laporan: transaksi muncul dengan nominal benar
- [ ] 4.2 Laporan: total pendapatan cocok dengan transaksi
- [ ] 4.3 Filter/periode laporan (jika ada) berjalan
- [ ] 4.4 Tambah pelanggan → muncul di daftar
- [ ] 4.5 Edit/hapus pelanggan
- [ ] 4.6 Tambah karyawan role **Kasir** dengan email+password → berhasil
- [ ] 4.7 Tambah karyawan role **Admin** dengan email+password → berhasil
- [ ] 4.8 Login akun Kasir → masuk POS, tidak blank
- [ ] 4.9 Login akun Admin → masuk dashboard admin, tidak blank

# PHASE 5 — Premium / Subscription (OBSOLETE)

- [ ] 5.1 Tidak ada gate "upgrade premium" yang menghalangi fitur
- [ ] 5.2 Tidak ada batas 500 produk / batas transaksi
- [ ] 5.3 Tidak ada banner iklan tier free

# PHASE 5.5 — Retrofit 3.0 (DB + UI + Security)

- [ ] 5.5.1 Modul dashboard menyesuaikan tipe outlet (Warung vs Cafe vs Gerobak)
- [ ] 5.5.2 Badge tipe benar (KELONTONG / GEROBAK / CAFE & RESTO)
- [ ] 5.5.3 Kasbon/Piutang: buat kasbon → muncul daftar hutang
- [ ] 5.5.4 Kasbon: tandai lunas
- [-] 5.5.5 SQLCipher + secure storage + event sync — terbatas di web

# PHASE 6 — Kasbon + WhatsApp + Sponsored Receipt

- [ ] 6.1 Kasbon: catat piutang pelanggan
- [ ] 6.2 Kasbon: riwayat pembayaran cicilan
- [ ] 6.3 Kirim struk via WhatsApp (checkout → tombol WA → buka wa.me)
- [ ] 6.4 teks struk terisi benar (nama toko, item, total)
- [ ] 6.5 Broadcast promo ke pelanggan (buka WhatsApp)
- [!] 6.6 Banner sponsor di struk — **fitur tidak ada di kode (cek & laporkan)**

# PHASE 7 — Dynamic QRIS Payment Gateway

- [ ] 7.1 QRIS **statis/manual** tetap berfungsi (owner QRIS muncul di checkout)
- [!] 7.2 QRIS **dinamis** (charge ke gateway Midtrans) — **butuh Edge Function + kolom DB, kemungkinan gagal**
- [-] 7.3 Webhook QRIS HMAC → set transaksi LUNAS — butuh backend
- [-] 7.4 Settlement / split-payment — butuh backend

# PHASE 7.6 — UI Retrofit (light theme "Ocean White")

- [ ] 7.6.1 Tema terang konsisten di semua layar utama
- [ ] 7.6.2 Tidak ada layar yang masih tema gelap lama
- [ ] 7.6.3 Layout rapi di ukuran HP (mobile viewport)

# PHASE 7.7 — Control Plane + KYC + Izin + Superadmin Setting

- [ ] 7.7.1 Superadmin panel terbuka (`/admin/`)
- [ ] 7.7.2 Login superadmin (fallback `admin@kasirgo.com` / `password123`)
- [ ] 7.7.3 Navigasi menu superadmin berjalan
- [!] 7.7.4 Setting integrasi/margin superadmin → data **mock**, tidak tersambung DB asli
- [!] 7.7.5 KYC auto-verify — cek apakah ada alurnya di app

---

## Format laporan hasil

| Phase | Item | Hasil | Catatan | Screenshot |
|---|---|---|---|---|
| 1 | 1.1 Registrasi owner | PASS | | — |
| 3 | 3.8 QRIS manual muncul | | | |
| 7 | 7.2 QRIS dinamis | | | |

Kirim hasil item FAIL/BLOKIR + nomor + screenshot ke saya untuk diperbaiki.
