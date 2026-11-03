# Panduan Aplikasi KasirGo — Link Unduh + Struktur UI + Langkah Demi Langkah

Dokumen ini rangkuman dari kode sumber (`kasirgo/lib/`) dan dirangkai menjadi
panduan pemakaian yang bisa langsung diikuti.

Struktur folder/UI ditampilkan sebagai **gambar** (PNG/SVG). Sumber diagram
(Mermaid + Graphviz) disimpan terpisah di `docs/diagrams/` agar bisa dirender
ulang atau diberikan ke model AI untuk dibuat gambar.

---

## Bagian 1 — Link Unduh APK (v1.0.11, release-signed)

APK ditandatangani keystore resmi KasirGo (sama dengan 1.0.10), jadi bisa diinstall
langsung di atas versi lama **tanpa perlu uninstall** data.

| Perangkat | Ukuran | Link Unduh |
|-----------|--------|-----------|
| HP Android modern (arm64) — **Direkomendasikan** | ~57 MB | https://github.com/ikhlassabar2021-create/kasirgo/releases/download/v1.0.11-signed-20261103/kasirgo-1.0.11-arm64-v8a.apk |
| HP Android lama (armeabi-v7a) | ~46 MB | https://github.com/ikhlassabar2021-create/kasirgo/releases/download/v1.0.11-signed-20261103/kasirgo-1.0.11-armeabi-v7a.apk |
| Emulator / PC Intel (x86_64) | ~61 MB | https://github.com/ikhlassabar2021-create/kasirgo/releases/download/v1.0.11-signed-20261103/kasirgo-1.0.11-x86_64.apk |

Checksum (SHA-256) tersedia di:
https://github.com/ikhlassabar2021-create/kasirgo/releases/download/v1.0.11-signed-20261103/SHA256SUMS-1.0.11.txt

> Web aplikasi (cadangan ketika HP bermasalah): https://dokterbisnis.web.id/
> Dashboard superadmin: https://dokterbisnis.web.id/admin/

---

## Bagian 2 — Struktur Kode UI

Lokasi root aplikasi Flutter: `kasirgo/lib/`

### 2.1 Peta folder utama

![Peta folder utama kasirgo/lib](diagrams/struktur-lib.png)

### 2.2 Screens (halaman) — dikelompokkan berdasarkan peran

![Delapan folder utama di bawah screens](diagrams/struktur-screens.png)

**Folder `owner/` (halaman pemilik — paling lengkap):**

![Halaman owner](diagrams/struktur-owner.png)

**Folder `auth/`, `admin/`, `cashier/`, `kitchen/` (staf toko):**

![Halaman staf toko](diagrams/struktur-staf.png)

**Folder `buyer/`, `customer/`, `modules/` (pelanggan & modul):**

![Pelanggan & modul](diagrams/struktur-pelanggan.png)

### 2.3 Widgets (komponen reusable)

![Komponen widgets](diagrams/struktur-widgets.png)

### Sumber diagram & cara render ulang

- **PNG / SVG** sudah jadi di folder `docs/diagrams/` — tinggal ditempel ke panduan.
- **Mermaid** (`*.mmd`) — format yang dipahami model AI, mermaid.live, dan GitHub.
- **Graphviz DOT** (`*.dot`) — untuk render ulang gambar lokal.

Render ulang semua gambar (Graphviz):

```bash
python3 docs/tools/make_structure_images.py
```

Render Mermaid menjadi gambar (misal buat model/integrasi lain):

```bash
npx -y @mermaid-js/mermaid-cli -i docs/diagrams/struktur-lib.mmd -o struktur-lib.png
```

---

## Bagian 3 — Panduan Langkah Demi Langkah

### A. Instalasi & Akun Baru

1. **Unduh APK** sesuai perangkat (link di Bagian 1). Untuk HP modern pakai
   `arm64-v8a`; jika gagal install/cepat crash coba `armeabi-v7a`.
2. **Buka aplikasi** → layar pemilihan mode **Penjual / Pembeli**
   (`mode_select_screen.dart`). Pilih **Penjual** untuk kelola toko.
3. **Daftar akun** (`register_screen.dart`): isi email, password, nama usaha,
   tipe usaha. Konfirmasi lewat email.
4. **Login** (`login_screen.dart`) → sistem otomatis membuat outlet.
5. **Verifikasi KYC** (`onboarding_kyc_screen.dart` + `kyc_upload_screen.dart`):
   nama sesuai KTP, no HP/email, alamat toko, foto KTP, foto selfie. KYC otomatis
   diverifikasi. (Akun uji `qa.gate@kasirgo.test` bisa melewati cek nama.)

### B. Siapkan Produk & Stok (Owner/Admin)

1. Buka **Produk** (`product_list_screen.dart`).
2. **Tambah produk** (`product_form_screen.dart`): nama, harga, stok, kategori,
   foto (foto disimpan lokal di HP), produk jasa/layanan (tanpa stok).
3. Kelola **stok** langsung dari daftar produk.

### C. Jual di Kasir (POS)

1. Owner: buka **POS** (`pos_screen.dart`) — Kasir: `cashier_pos_screen.dart`.
2. Pilih produk → masuk keranjang (`cart_panel.dart`) → **Bayar**.
3. Pilih metode bayar (Tunai / QRIS / Transfer) di `checkout_dialog.dart`.
4. Setelah sukses muncul `checkout_success_dialog.dart` dengan tombol **Struk
   PDF / Struk ke WA**.

### D. Pesanan Dine-in & QR Meja (cafe/resto)

1. Owner: siapkan **QR Meja** (`qr_table_screen.dart`) → cetak/salin QR.
2. Pelanggan scan QR → `customer_menu_screen.dart` → pilih menu → kirim
   (`customer_order_screen.dart` menampilkan status).
3. Kasir konfirmasi bayar di **Pesanan Masuk** (`incoming_orders_screen.dart`).
4. Koki melihat & mengubah status di **KDS** (`kitchen_home_screen.dart`).

### E. Katalog Online & WhatsApp

1. Owner: aktifkan **Katalog Online** (`online_catalog_screen.dart`).
2. Promosi via **Broadcast WA** (`whatsapp_broadcast_screen.dart`).

### F. Laporan & Keuangan

1. **Laporan** (`report_screen.dart`): laba rugi, penjualan, per produk (SAK EMKM).
2. Ekspor **Excel** & **PDF** dari tombol di layar laporan.
3. **Laporan performa staf** (`staff_performance_screen.dart`).
4. **Laporan otomatis ke bos** (`report_schedule_screen.dart`).

### G. Karyawan, Shift & Delegasi

1. **Karyawan** (`employee_screen.dart`): tambah Admin / Kasir / Koki
   (+ kuota staf gratis 1 Admin + 1 Kasir).
2. **Shift** (`shift_screen.dart`): atur shift & tip.
3. **Delegasi tugas** (`delegation_board_screen.dart`) + pengingat otomatis.

### H. Dokter Bisnis AI (Program Pendukung)

1. Beranda → kartu **Dokter Bisnis AI** (`business_doctor_screen.dart`).
2. Ikuti **Cek Fisik Toko** (`doctor_intake_screen.dart`).
3. Baca **Hasil Diagnosa** (`doctor_result_screen.dart`), jalankan resep.
4. Catat hasil promosi & ROI (`doctor_promotion_log_screen.dart`), lihat
   riwayat (`doctor_cases_screen.dart`).

### I. Fitur Pertumbuhan (AI / Marketing)

1. **Atur Harga & Diskon** (`dynamic_pricing_screen.dart`).
2. **Bundling produk** (`bundle_manager_screen.dart`).
3. **Referral pelanggan** (`referral_screen.dart`).
4. **Squad Marketing** (`design_studio_screen.dart`, `promotion_screen.dart`,
   `ads_studio_screen.dart`).
5. **Sidak Stok & Kas** (`sidak_bos_screen.dart`).

### J. Pasar Hyperlocal (mode Pembeli)

1. Ganti mode ke **Pembeli** (`mode_gate.dart`).
2. Login/daftar pembeli (`buyer_auth_screen.dart`) + isi identitas
   (`buyer_onboarding_screen.dart`).
3. Radar toko terdekat (`buyer_home_tab.dart`) → pilih toko → katalog.
4. **Checkout** (`buyer_checkout_screen.dart`) → **Lacak pesanan**
   (`buyer_order_tracking_screen.dart`).

### K. Bantuan & Pembaruan

1. **Pusat Bantuan** (`help_center_screen.dart`) + **Tiket** (`support_tickets_screen.dart`).
2. **Cek pembaruan** (`app_update_screen.dart`).
3. **Program Pendukung** (`supporter_screen.dart`) untuk fitur premium
   (Rp50.000/bulan).

---

## Catatan Rilis v1.0.11

- Deteksi ABI otomatis untuk pilih APK yang benar saat update.
- Helper di form KYC: "nama harus sama dengan KTP" + bypass validasi nama untuk
  akun uji (`@kasirgo.test` atau `is_qa`).
- Gerbang web→APK: HP jadi utama, web hanya cadangan.