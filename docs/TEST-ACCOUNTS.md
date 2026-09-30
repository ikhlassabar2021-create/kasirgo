# KasirGo - Proses Uji Phase 8 s/d Selesai + Akun Test

Semua password: `sabar2021`
Login via email + password (bukan Google). Jika tampilan lama, hard refresh
(Ctrl+Shift+R / Incognito).

## Link aplikasi

| Keperluan | Link |
|-----------|------|
| Aplikasi (Flutter, semua role) | https://ikhlassabar2021-create.github.io/kasirgo/ |
| Halaman login | https://ikhlassabar2021-create.github.io/kasirgo/#/login |
| Superadmin (React) | https://ikhlassabar2021-create.github.io/kasirgo/admin/ |

Catatan: halaman login belum mengisi email otomatis dari URL, jadi tempel email
akun di bawah ini pada form login.

## Akun Owner (1 per tipe usaha)

| Tipe | Email | Outlet | Modul menonjol |
|------|-------|--------|----------------|
| Cafe | `ikhlassabar2021@gmail.com` | Toko Test | QR Meja + KDS ada, PPOB tidak |
| Warung | `ikhlassabar2021+warung@gmail.com` | Warung Test | PPOB ada, QR Meja tidak |
| Gerobak | `ikhlassabar2021+gerobak@gmail.com` | Gerobak Test | Tanpa PPOB & QR Meja |

## Akun Admin (tanpa hapus produk)

| Outlet | Email |
|--------|-------|
| Cafe (Toko Test) | `ikhlassabar2021+adminc@gmail.com` |
| Warung (Warung Test) | `ikhlassabar2021+adminw@gmail.com` |
| Gerobak (Gerobak Test) | `ikhlassabar2021+adming@gmail.com` |

## Akun Kasir (POS + QRIS + Shift + Tip)

| Outlet | Email |
|--------|-------|
| Cafe (Toko Test) | `ikhlassabar2021+kasir@gmail.com` |
| Warung (Warung Test) | `ikhlassabar2021+kasirw@gmail.com` |
| Gerobak (Gerobak Test) | `ikhlassabar2021+kasirg@gmail.com` |

## Akun Superadmin (React web)

| Email | Link | Catatan |
|-------|------|---------|
| `superadmin@kasirgo.com` | https://ikhlassabar2021-create.github.io/kasirgo/admin/ | `admin_users`: role superadmin, aktif |

## Akun Pelanggan (tanpa akun, scan QR meja)

Pelanggan TIDAK perlu akun. Cara masuk:
- Dari halaman login klik "Masuk sebagai Pelanggan (Scan QR Meja)", atau
- Buka salah satu deep-link di bawah (outlet + meja sudah terisi):

| Outlet (tipe) | Link pelanggan |
|---------------|----------------|
| Toko Test (Cafe) | https://ikhlassabar2021-create.github.io/kasirgo/#/customer?outlet=229c94d7-ce6d-4be1-98f5-448f600528cc&table=Meja%2001 |
| Warung Test | https://ikhlassabar2021-create.github.io/kasirgo/#/customer?outlet=5dda8727-2439-432a-91e6-308c824c4f7a&table=Meja%2001 |
| Gerobak Test | https://ikhlassabar2021-create.github.io/kasirgo/#/customer?outlet=e545b57c-7ac8-4709-b4d2-db54819610e1&table=Meja%2001 |

Owner juga bisa membuka QR Meja (menu "QR Meja Dine-in") - QR memuat deep-link
yang sama. Aturan akses: pelanggan anonim hanya bisa membaca menu & kirim
pesanan dine-in lewat RPC `get_public_menu` / `place_dine_in_order`.

PENTING: produk hanya terlihat oleh staf pada outlet yang sama.

## Produk contoh yang sudah di-seed

- Cafe: Kopi Susu, Nasi Goreng, Es Teh Manis, Roti Bakar
- Warung: rokok, Beras 1kg, Minyak Goreng 1L, Indomie Goreng
- Gerobak: Air Mineral, Gorengan, Kopi Sachet
- PPOB (katalog global, 15 produk): Pulsa, Token PLN, Paket Data, E-Money, Game

---

# Proses Uji Phase 8 s/d Selesai

Centang tiap langkah. Urutan disarankan dari Phase 8 ke atas.

## Phase 8 - Modul per outlet_type

### 8.1 Modul dinamis per tipe (ST8-1)
1. Login owner Cafe (`ikhlassabar2021@gmail.com`).
   - Harapan: kartu "Kitchen (KDS)" + "QR Meja Dine-in" tampil; "PPOB & Pulsa" TIDAK tampil.
2. Logout, login owner Warung (`ikhlassabar2021+warung@gmail.com`).
   - Harapan: "PPOB & Pulsa" tampil; "QR Meja Dine-in" & "Kitchen (KDS)" TIDAK tampil.
3. Login owner Gerobak (`ikhlassabar2021+gerobak@gmail.com`).
   - Harapan: tanpa "PPOB & Pulsa", tanpa "QR Meja", tanpa "KDS".
4. Override: Superadmin -> Outlet Terdaftar -> pilih outlet -> toggle modul -> Simpan.
   - Harapan: override menang di atas default tipe (tercatat di `outlet_module_overrides`).

### 8.2 Varian produk (ST8-2)
1. Owner retail: buat produk -> toggle "Produk punya varian" (hanya muncul untuk tipe retail).
2. Tambah varian (mis. Original/Renyah, delta +2000) -> simpan.
3. POS -> klik produk -> pilih varian -> qty 2 -> checkout.
   - Harapan: stok varian berkurang 2; badge "N varian" di daftar produk; tap badge -> detail varian.

### 8.3 Resep / BOM + HPP (ST8-3)
1. Owner Cafe -> Produk: buat bahan "Gula Pasir" (harga modal/kg) + "Es Teh" (harga jual).
2. Menu "Resep & HPP" -> Es Teh -> Buat Resep (bahan Gula, qty, satuan, yield) -> target margin -> Set HPP.
3. POS -> jual 2 Es Teh.
   - Harapan: stok bahan Gula berkurang; laporan laba memakai HPP baru.

### 8.4 KDS + QR Meja (ST8-4)
1. Owner Cafe -> "QR Meja Dine-in" -> tampilkan QR (mis. Meja 01).
2. Pelanggan buka link pelanggan Cafe di atas -> pilih produk -> kirim pesanan.
   - Harapan: pesanan (channel dine_in) muncul di "Kitchen (KDS)" tanpa refresh.
3. KDS: tekan tiket -> MENUNGGU -> DIMASAK -> SIAP SAJI -> hilang dari antrean.
   - Harapan: tiket >10 menit berwarna merah; umur tiket bertambah sendiri tiap 30 detik.

### 8.5 Shift Kasir + Tip + Split Bill (ST8-5)
1. Owner/Kasir -> "Shift Kasir" -> Buka Shift (modal awal, mis. Rp200.000).
2. POS -> belanja Rp100.000 -> "Split Bill (Bayar Gabungan)" -> cash 60.000 + QRIS 40.000 -> sisa 0 -> konfirmasi.
3. Tambah Tip Rp5.000 pada transaksi.
4. "Shift Kasir" -> Tutup Shift -> hitung fisik Rp260.000.
   - Harapan: "KAS PAS" (selisih 0); riwayat shift tampil rekap cash/qris/tip.

## Phase 9 - PPOB + Closed-loop + B2B

### 9.1 PPOB + saldo closed-loop (ST9-1/9-2)
1. Login owner Warung -> "PPOB & Pulsa".
   - Harapan: katalog 15 produk; harga jual = modal (cost_price) + margin 5% dari Control Plane.
2. Beli produk (mis. Token PLN 20.000) -> pilih bayar tunai / saldo.
   - Harapan: transaksi tercatat di `ppob_transactions` (amount/cost/profit/status).
3. Bila bayar saldo: setor hasil QRIS ke saldo dulu (`settlement_add_qris`) lalu ulangi.
   - Harapan: saldo berkurang via RPC `ppob_use_saldo`; saldo tampil via `get_outlet_saldo`.
4. Laporan -> kartu "Laba PPOB" per periode (omzet/untung/jumlah/rata-rata).

### 9.2 Embedded B2B Restock (ST9-3)
1. Owner -> "Kulakan B2B" -> buka WebView distributor (domain-lock).
2. Buat restock order.
   - Harapan: order tercatat di `restock_orders`; komisi tampil di rekap superadmin.

## Phase 10 - Fintech + Hyperlocal + Asuransi

### 10.1 Modal Usaha (fintech lead)
1. Owner -> "Modal Usaha".
   - Harapan: skor kelayakan arus kas + estimasi plafon; kirim lead -> `fintech_leads` (amount_requested).
   - Gated config Superadmin: Control Plane -> Modal Usaha.

### 10.2 Tren Wilayah (hyperlocal)
1. Owner -> "Tren Wilayah" -> setujui consent UU PDP -> kirim laporan agregat anonim.
   - Harapan: `hyperlocal_reports` terisi tanpa PII; tampil agregat wilayah.
   - Gated config Superadmin: `hyperlocal`.

### 10.3 Asuransi Mikro
1. Owner -> "Asuransi Mikro" -> pilih produk -> ajukan polis.
   - Harapan: lead/polis tercatat; komisi tampil di rekap.
   - Gated config Superadmin: `insurance` (produk list harus tidak kosong).

## Phase 11 & 13 - Superadmin + Control Plane

Login `superadmin@kasirgo.com` di https://ikhlassabar2021-create.github.io/kasirgo/admin/

1. **Laporan Utama** (`/superadmin`): ringkasan lintas outlet (revenue engine).
2. **Outlet Terdaftar** (`/outlets`): daftar outlet (KYC verified tampil default) ->
   **Outlet Detail**: staff, laporan, toggle fitur per outlet (override).
3. **Fitur Utama** (`/features`): feature flags global + staged rollout
   (enabled, rollout_pct, outlet_types, segments).
4. **Affiliates**: referral + komisi + payout owner affiliate.
5. **Control Plane**: Payment Gateway, PPOB, B2B Kulakan, Modal Usaha, Iklan, Flags, Override.
   - Secret (PG/PPOB) disimpan di `platform_integrations.secret_config` (tidak pernah ke APK).
   - Iklan: kreatif per-item (nama editable, judul, subjudul, CTA, URL tujuan, kode HTML/script,
     kategori) + banner upload disimpan LOKAL (base64), bukan storage.
   - PPOB: margin persen -> harga jual auto; field callback_url/ip_whitelist/product_codes.
6. **Backup / Revenue**: backup terjadwal + rekap 12 revenue engine.

## Phase 12 - Security + Offline

1. Mode offline: putus internet -> transaksi tetap jalan (SQLite) -> sambung lagi.
   - Harapan: sync ke Supabase tiap 30 detik; konflik last-write-wins; dead-letter untuk gagal.
2. Keamanan: sebagai `anon`, akses `platform_integrations` harus 0 baris (hanya view publik).
   - `secret_config` tidak terbaca klien; RLS kitchen aktif; INTERNET permission + R8 minify di APK.

---

## Info proses

- Supabase project: `lmvjecdvfzsmrowwwpck` (ap-southeast-1). Migrasi Phase 8-13 sudah terpasang.
- Deploy app web: gh-pages (Flutter, base `/kasirgo/`). Deploy admin: gh-pages `/admin/`.
- APK rilis dibuild via CI `.github/workflows/release-apk.yml` (bukan di sandbox).
- QC kode: `flutter analyze` baseline 21 issue (0 baru); `flutter test` 7 gagal pra-ada
  (POS/Phase 5, tak terkait); `test/ad_service_test.dart` 5/5 PASS; `test/kyc_checks_test.dart`
  16/16 PASS; admin `npx tsc -b` PASS + `vite build` sukses.
- Modul: RPC `feature_flags_for_outlet` mengevaluasi enabled + rollout_pct + outlet_types +
  segments, lalu override per-outlet. Flag global `module_ppob` dibatasi ke
  `outlet_types=['warung sembako']`.

## Catatan Email Konfirmasi

Karena "Confirm email" aktif, registrasi lewat form & tambah karyawan via `signUp`
akan kena rate limit email (~3/jam). Solusi:
- Deploy Edge Function `create_staff` (lihat `2026-09-28-deploy-create-staff.sql`), atau
- Matikan "Confirm email" sementara di Authentication -> Sign In / Providers -> Email.