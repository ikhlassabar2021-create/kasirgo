# Checklist Test KasirGo — Phase 1 s/d 7 (v2, setelah perbaikan)

App: **https://ikhlassabar2021-create.github.io/kasirgo/**
Superadmin: **https://ikhlassabar2021-create.github.io/kasirgo/admin/**

Legenda: `[ ]` belum · `[x]` PASS · `[!]` FAIL · `[/]` BLOKIR · `[-]` tak bisa dites di web

---

## A. LANGKAH WAJIB DI SUPABASE (sebelum test)

### A1. URL Configuration
Authentication → URL Configuration:
1. [ ] Site URL = `https://ikhlassabar2021-create.github.io/kasirgo/`
2. [ ] Redirect URLs = `https://ikhlassabar2021-create.github.io/kasirgo/`

### A2. Email konfirmasi (PILIH SALAH SATU)
- **Opsi A — Ada email konfirmasi** (yang Anda minta): Authentication → Providers → Email → **Confirm email = ON**.
  Konsekuensi: setelah daftar, owner/staf **harus klik tautan di email** dulu sebelum bisa login.
- **Opsi B — Langsung login**: Confirm email = **OFF**. (tidak ada email)

> PENTING: email konfirmasi dikirim oleh Supabase, bukan oleh app. App sudah siap di dua mode:
> jika ada session → langsung masuk; jika tidak → muncul pesan "Cek email untuk konfirmasi".
> Google login TIDAK mengirim email konfirmasi (email Google sudah terverifikasi).

### A3. Jalankan migrasi SQL (WAJIB untuk perbaikan staf)
Supabase → SQL Editor → tempel isi file:
`docs/migrations/2026-09-28-fix-staff-auth-trigger.sql` → Run.

Ini memperbaiki:
- CHECK role `user_roles` agar mencakup `owner` (kalau tidak, daftar owner bisa gagal).
- Trigger `handle_new_user` agar **tidak** membuat outlet sampah untuk akun staf.

### A4. SMTP (opsional, jika Opsi A)
Supabase default email terbatas (~3-4 email/jam). Untuk testing lebih, set Custom SMTP
(Authentication → Settings → SMTP) atau test secukupnya saja.

---

## B. Ringkasan fitur per tipe outlet (sudah diperbaiki)

| Fitur | Warung (kelontong) | Gerobak | Cafe/Resto | Retail |
|---|---|---|---|---|
| POS | ✅ | ✅ | ✅ | ✅ |
| Inventori | ✅ | ✅ | ✅ | ✅ |
| Kasbon | ✅ | ✅ | ✅ | ✅ |
| **PPOB** | ✅ | ❌ | ❌ | ✅ |
| **QR Meja Dine-in** | ❌ | ❌ | ✅ | ❌ |
| KDS/Dapur | ✅ | ✅ | ✅ | ❌ |
| Varian | ✅ | ✅ | ✅ | ✅ |
| Resep/Bahan | ✅ | ✅ | ✅ | ✅ |
| Split Bill | ✅ | ✅ | ✅ | ✅ |
| Kulakan B2B | ✅ | ✅ | ✅ | ✅ |
| Harga Grosir | ✅ | ✅ | ✅ | ✅ |

Verifikasi: saat daftar, pilih **Warung Sembako / Gerobak / Cafe** — cek menu yang muncul
sesuai tabel di atas (terutama **PPOB hilang di Cafe & Gerobak**, **QR Meja hilang di Warung & Gerobak**).

---

## C. Prasyarat akun test
Buat 3 owner lewat `/register`:
- [ ] Owner **Warung**
- [ ] Owner **Gerobak**
- [ ] Owner **Cafe**

---

# PHASE 1 — Supabase DB + Auth

- [ ] 1.1 Registrasi owner (email+password) berhasil
  - Jika Confirm email ON → muncul pesan "Cek email...", lalu klik tautan email → login
  - Jika OFF → langsung masuk dashboard
- [ ] 1.2 Logout → login ulang berhasil
- [ ] 1.3 Login password salah → error jelas, tidak crash
- [ ] 1.4 Register email yang sudah dipakai → error jelas
- [ ] 1.5 Login Google berhasil (tidak butuh konfirmasi email)
- [ ] 1.6 Outlet otomatis dibuat saat daftar
- [ ] 1.7 RLS: 2 owner tidak saling lihat data

# PHASE 2 — App Shell + Auth + Offline

- [ ] 2.1 Halaman login rapi
- [ ] 2.2 Navigasi tidak ada layar putih
- [ ] 2.3 Redirect sesuai role (owner/ kasir/ admin)
- [ ] 2.4 Refresh saat login → tetap login
- [ ] 2.5 Belum login → ke `/login`
- [-] 2.6 Offline engine (SQLite/SQLCipher) — tak bisa di web

# PHASE 3 — Produk + POS + QRIS Manual + AI Co-Pilot

- [ ] 3.1 Tambah produk → muncul
- [ ] 3.2 Edit produk → tersimpan
- [ ] 3.3 Hapus produk → hilang
- [ ] 3.4 POS: pilih produk → masuk keranjang
- [ ] 3.5 Ubah qty → subtotal benar
- [ ] 3.6 Hapus item dari keranjang
- [ ] 3.7 Checkout Cash → transaksi tersimpan
- [ ] 3.8 **QRIS: upload gambar QRIS di Pengaturan → QRIS Toko**
- [ ] 3.9 **Checkout QRIS → gambar QRIS toko muncul otomatis** (tanpa ketik ulang)
- [ ] 3.10 Ganti/hapus gambar QRIS berfungsi
- [ ] 3.11 AI Co-Pilot: insight di dashboard (atau pesan kosong)
- [-] 3.12 Scan barcode kamera — tak bisa di web

# PHASE 4 — Laporan + Pelanggan + Karyawan

- [ ] 4.1 Laporan: transaksi muncul nominal benar
- [ ] 4.2 Total pendapatan cocok
- [ ] 4.3 Tambah pelanggan → muncul
- [ ] 4.4 Edit/hapus pelanggan
- [ ] 4.5 **Tambah Karyawan role Kasir + email&password → berhasil**
- [ ] 4.6 **Tambah Karyawan role Admin + email&password → berhasil**
- [ ] 4.7 **Login akun Kasir → masuk POS, tidak blank**
- [ ] 4.8 **Login akun Admin → masuk dashboard admin, tidak blank**

# PHASE 5 — Premium / Subscription (OBSOLETE)

- [ ] 5.1 Tidak ada gate upgrade premium
- [ ] 5.2 Tidak ada batas 500 produk/transaksi

# PHASE 5.5 — Retrofit 3.0

- [ ] 5.5.1 Modul dashboard sesuai tipe outlet (lihat tabel B)
- [ ] 5.5.2 Badge tipe benar (KELONTONG / GEROBAK / CAFE & RESTO)
- [ ] 5.5.3 Kasbon: buat → muncul di daftar
- [ ] 5.5.4 Kasbon: tandai lunas
- [-] 5.5.5 SQLCipher + event sync — terbatas web

# PHASE 6 — Kasbon + WhatsApp + Sponsored Receipt

- [ ] 6.1 Kasbon: catat piutang
- [ ] 6.2 Kasbon: cicilan
- [ ] 6.3 Kirim struk via WhatsApp (buka wa.me)
- [ ] 6.4 teks struk benar
- [ ] 6.5 Broadcast promo
- [!] 6.6 Banner sponsor struk — **tidak ada di kode** (laporkan)

# PHASE 7 — Dynamic QRIS Payment Gateway

- [ ] 7.1 QRIS **statis/manual** (gambar upload) berfungsi — ini yang utama
- [!] 7.2 QRIS **dinamis** gateway — **backend belum ada** (Edge Function `create_midtrans_charge`
      + webhook belum dibangun). Aplikasi tidak crash (sudah di-guard), tapi fitur belum jalan.
- [-] 7.3 Webhook HMAC → butuh backend
- [-] 7.4 Settlement/split-payment → butuh backend

# PHASE 7.6 — UI Retrofit (light "Ocean White")

- [ ] 7.6.1 Tema terang konsisten
- [ ] 7.6.2 Tidak ada layar tema gelap lama
- [ ] 7.6.3 Layout rapi di mobile

# PHASE 7.7 — Control Plane + KYC + Superadmin

- [ ] 7.7.1 Panel superadmin terbuka
- [ ] 7.7.2 Login superadmin (fallback `admin@kasirgo.com` / `password123`)
- [ ] 7.7.3 Navigasi menu berjalan
- [!] 7.7.4 Setting superadmin → **data mock**, tidak tersambung DB asli
- [ ] 7.7.5 KYC: cek halaman upload KYC di app (`#/register` ada field NIK)

---

## D. Berkas pendukung
- Migrasi SQL: `docs/migrations/2026-09-28-fix-staff-auth-trigger.sql`
- Reset data: `docs/reset-data-test.sql`

## E. Format laporan hasil
| Phase | Item | Hasil | Catatan |
|---|---|---|---|
| 3 | 3.9 QRIS muncul | | |
| 4 | 4.5 akun kesir | | |
