# KasirGo — Akun Test & Panduan Uji

Semua password: `sabar2021`
Aplikasi: https://ikhlassabar2021-create.github.io/kasirgo/

Login via email + password (bukan Google). Setelah login, jika tampilan lama,
hard refresh (Ctrl+Shift+R / Incognito).

## Akun Owner (1 per tipe usaha)

| Tipe | Email | Outlet | Modul menonjol |
|------|-------|--------|----------------|
| Cafe | `ikhlassabar2021@gmail.com` | Toko Test | QR Meja ada, PPOB tidak |
| Warung | `ikhlassabar2021+warung@gmail.com` | Warung Test | Semua modul, QR Meja tidak |
| Gerobak | `ikhlassabar2021+gerobak@gmail.com` | Gerobak Test | Tanpa PPOB & QR Meja |

## Akun Admin (tanpa hapus produk)

| Outlet | Email |
|--------|-------|
| Cafe (Toko Test) | `ikhlassabar2021+adminc@gmail.com` |
| Warung (Warung Test) | `ikhlassabar2021+adminw@gmail.com` |
| Gerobak (Gerobak Test) | `ikhlassabar2021+adming@gmail.com` |

## Akun Kasir (POS + QRIS)

| Outlet | Email |
|--------|-------|
| Cafe (Toko Test) | `ikhlassabar2021+kasir@gmail.com` |
| Warung (Warung Test) | `ikhlassabar2021+kasirw@gmail.com` |
| Gerobak (Gerobak Test) | `ikhlassabar2021+kasirg@gmail.com` |

PENTING: Produk hanya terlihat oleh staf pada outlet yang sama.
Kasir Cafe hanya melihat produk Toko Test, kasir Warung hanya melihat
produk Warung Test, dan seterusnya.

## Akun Pelanggan (scan QR meja)

Pelanggan TIDAK perlu akun. Dari halaman login klik
"Masuk sebagai Pelanggan (Scan QR Meja)", atau buka QR yang di-generate
owner di menu QR Meja.

Wajib dijalankan sekali agar pelanggan anonim bisa membaca menu:
`docs/migrations/2026-09-28-customer-qr-order.sql`
(Supabase Dashboard -> SQL Editor -> tempel -> RUN).

## Produk contoh yang sudah di-seed

- Cafe: Kopi Susu, Nasi Goreng, Es Teh Manis, Roti Bakar
- Warung: rokok, Beras 1kg, Minyak Goreng 1L, Indomie Goreng
- Gerobak: Air Mineral, Gorengan, Kopi Sachet

## Catatan Email Konfirmasi

Karena "Confirm email" aktif, registrasi lewat form & tambah karyawan via
`signUp` akan kena rate limit email (~3/jam). Solusi:
- Deploy Edge Function `create_staff` (lihat `2026-09-28-deploy-create-staff.sql`), atau
- Matikan "Confirm email" sementara di Authentication -> Sign In / Providers -> Email.
