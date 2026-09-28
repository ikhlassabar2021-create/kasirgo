# Checklist Test KasirGo

App: **https://ikhlassabar2021-create.github.io/kasirgo/**
Superadmin: **https://ikhlassabar2021-create.github.io/kasirgo/admin/**
Semua route via hash (contoh `#/login`).

Legend: `[ ]` belum · `[x]` PASS · `[!]` FAIL · `[/]` BLOKIR

---

## Prasyarat (WAJIB sebelum test)

Di **Supabase → Authentication → URL Configuration**:

1. [ ] **Site URL** = `https://ikhlassabar2021-create.github.io/kasirgo/`
2. [ ] **Redirect URLs** = `https://ikhlassabar2021-create.github.io/kasirgo/`
3. [ ] **Confirm email** = OFF (Authentication → Providers → Email)

> Tanpa ini, login owner/staff gagal dengan pesan "email belum dikonfirmasi".

---

## Kenyataan penting

- Role login **hanya 3**: `owner`, `admin`, `cashier`.
- **Dapur / Kitchen BUKAN role login** — hanya layar di dashboard owner (tipe Cafe).
- **Pelanggan tidak login** — masuk via `#/customer` + kode outlet.
- **Superadmin** = web terpisah (`/admin/`), data mock. Login fallback: `admin@kasirgo.com` / `password123`.

### Pemetaan tipe usaha → modul

| Skenario | Pilih tipe saat daftar | Modul aktif |
|---|---|---|
| Warung | Warung Sembako / Kelontong | POS, Inventori, Kasbon, PPOB, Kulakan B2B, Harga Grosir |
| Gerobak | Gerobak | POS, Inventori, Kasbon |
| Cafe | Cafe / Kedai Kopi / Restoran | POS, Inventori, Varian, Resep, Meja, **KDS**, Split Bill |

---

## Blok A — Owner

Siapkan 3 akun owner baru: satu per tipe (Warung, Gerobak, Cafe).

### A1. Registrasi & Login
- [ ] Daftar owner tipe **Warung** → dashboard muncul (tidak blank)
- [ ] Daftar owner tipe **Gerobak** → dashboard muncul (tidak blank)
- [ ] Daftar owner tipe **Cafe** → dashboard muncul (tidak blank)
- [ ] Logout → login ulang (email + password) berhasil
- [ ] Login dengan **Google** berhasil

### A2. Dashboard & Modul sesuai tipe
- [ ] Badge tipe benar: `KELONTONG` / `GEROBAK` / `CAFE & RESTO`
- [ ] Warung: modul POS, Inventori, Kasbon, PPOB, Kulakan B2B, Harga Grosir
- [ ] Gerobak: modul POS, Inventori, Kasbon (KDS & Meja **tidak** muncul)
- [ ] Cafe: modul Varian, Resep, Meja, **KDS/Dapur**, Split Bill muncul

### A3. QRIS Manual (penting)
- [ ] Banner "QRIS belum diatur" muncul di dashboard owner baru
- [ ] Klik banner → dialog QRIS terbuka (tombol langsung aktif)
- [ ] Isi QRIS → simpan → banner hilang
- [ ] QRIS tersimpan per-outlet (logout/login tetap ada)

### A4. Produk
- [ ] Tambah produk → muncul di daftar
- [ ] Hapus produk (ikon trash di card / tombol "Hapus Produk") → hilang

### A5. Karyawan (staf login)
- [ ] Tambah karyawan role **Kasir** dengan email + password → berhasil
- [ ] Tambah karyawan role **Admin** dengan email + password → berhasil
- [ ] Login akun staf → masuk POS (kasir) / dashboard admin, **tidak blank**

### A6. POS & Transaksi
- [ ] Tambah item ke keranjang
- [ ] Bayar **Cash** → transaksi tersimpan
- [ ] Bayar **QRIS** → dialog menampilkan **QRIS toko milik owner**
- [ ] Bayar **Bank Transfer** → transaksi tersimpan

### A7. Laporan
- [ ] Transaksi muncul di Laporan dengan nominal benar

### A8. Pengaturan
- [ ] Menu bernama **"Tautkan Akun Google"** (bukan OTP / telepon)
- [ ] **QRIS Toko** bisa dibuka & disimpan

---


---

## Blok B — Admin
- [ ] Login akun admin (dibuat owner) → masuk `#/admin`
- [ ] Bisa akses Produk
- [ ] Bisa akses Laporan

## Blok C — Kasir
- [ ] Login akun kasir (dibuat owner) → masuk `#/cashier` (POS)
- [ ] Buat transaksi Cash
- [ ] Buat transaksi QRIS

## Blok D — Pelanggan
- [ ] Buka `#/customer` (tanpa login)
- [ ] Masukkan kode outlet → menu/produk tampil

## Blok E — Superadmin (web terpisah)
- [ ] Buka `.../kasirgo/admin/` → halaman login tampil
- [ ] Login (fallback `admin@kasirgo.com` / `password123`) → masuk
- [ ] Navigasi antar menu berjalan (data mock)

---

## Format laporan hasil

Untuk tiap item, catat:

| Item | Hasil (PASS/FAIL/BLOKIR) | Catatan | Screenshot |
|---|---|---|---|
| contoh: A2 Cafe KDS muncul | PASS | | — |
| | | | |
