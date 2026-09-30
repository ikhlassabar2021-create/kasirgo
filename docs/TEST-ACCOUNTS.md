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

## Panduan Uji Phase 8 - 13

Urutan disarankan (semua password `sabar2021`):

### Phase 8 - Modul per outlet_type
1. **Modul dinamis.** Owner Cafe (`ikhlassabar2021@gmail.com`) -> kartu "Kitchen (KDS)"
   + "QR Meja Dine-in" tampil, tanpa PPOB. Owner Warung (`+warung@`) -> "PPOB & Pulsa"
   tampil, tanpa QR Meja. Owner Gerobak (`+gerobak@`) -> tanpa PPOB & QR Meja.
   Override per outlet diatur Superadmin (menu Fitur Utama / Outlet Detail) dan menang
   di atas default tipe.
2. **Varian.** Hanya outlet_type retail yang menampilkan toggle "Produk punya varian".
   Produk -> tambah varian (delta harga) -> POS pilih varian -> checkout; stok varian
   berkurang, badge "N varian" muncul di daftar.
3. **Resep/BOM (Cafe).** Produk: buat bahan "Gula Pasir" (modal/kg) + "Es Teh". Menu
   "Resep & HPP" -> Es Teh -> Buat Resep (bahan, yield, target margin) -> Set HPP.
   POS jual Es Teh -> stok bahan berkurang.
4. **KDS (Cafe).** Owner -> QR Meja Dine-in -> tampilkan QR. Pelanggan scan
   (login -> "Masuk sebagai Pelanggan (Scan QR Meja)") -> order. Tiket muncul di
   "Kitchen (KDS)" realtime -> MENUNGGU -> DIMASAK -> SIAP SAJI. Tiket >10 menit memerah.
5. **Shift/Tip/Split.** Owner/Kasir -> "Shift Kasir" -> Buka Shift (modal awal).
   POS -> "Split Bill (Bayar Gabungan)" (cash+qris = tagihan) + tip. Tutup Shift ->
   hitung fisik -> tampil KAS PAS/Selisih + riwayat.

### Phase 9 - PPOB + Closed-loop + B2B
6. **PPOB (Warung).** Pastikan config PPOB aktif (Control Plane -> PPOB; margin 5%,
   15 produk katalog). Menu "PPOB & Pulsa" -> beli (harga jual = modal + margin
   otomatis) -> saldo QRIS->PPOB & laba PPOB tampil di laporan.
7. **B2B.** Menu "Kulakan B2B" -> WebView distributor (domain-lock) -> restock order
   -> komisi tercatat.

### Phase 10 - Fintech + Hyperlocal + Asuransi
8. "Modal Usaha" (skor arus kas + estimasi plafon), "Tren Wilayah" (consent UU PDP),
   "Asuransi Mikro" (lead + polis). Semua digate config Superadmin.

### Phase 11 & 13 - Superadmin + Control Plane
9. Login `superadmin@kasirgo.com` di https://ikhlassabar2021-create.github.io/kasirgo/admin/
   - Laporan Utama `/superadmin`, Outlet Terdaftar `/outlets` (KYC verified default) ->
     Outlet Detail -> toggle fitur (override menang, tercatat di `outlet_module_overrides`).
   - Fitur Utama `/features`: feature flags global + staged rollout.
   - Control Plane: Payment Gateway, PPOB, B2B Kulakan, Modal Usaha, Iklan, Flags,
     Override. Secret PG/PPOB di `platform_integrations.secret_config` (tak ke APK);
     banner iklan disimpan lokal (base64), bukan storage.

### Phase 12 - Security/Offline
10. Mode offline: transaksi tetap jalan, sync saat online (30 detik). Sebagai `anon`,
    akses `platform_integrations` harus 0 baris (hanya view publik).

Catatan modul: RPC `feature_flags_for_outlet` mengevaluasi enabled + rollout_pct +
outlet_types + segments, lalu override per-outlet. Flag global `module_ppob` dibatasi
ke `outlet_types=['warung sembako']`.

## Catatan Email Konfirmasi

Karena "Confirm email" aktif, registrasi lewat form & tambah karyawan via
`signUp` akan kena rate limit email (~3/jam). Solusi:
- Deploy Edge Function `create_staff` (lihat `2026-09-28-deploy-create-staff.sql`), atau
- Matikan "Confirm email" sementara di Authentication -> Sign In / Providers -> Email.
