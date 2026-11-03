# Panduan Aplikasi KasirGo — Link Unduh + Struktur UI + Langkah Demi Langkah

Dokumen ini rangkuman dari kode sumber (`kasirgo/lib/`) dan dirangkai menjadi
panduan pemakaian yang bisa langsung diikuti.

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

```
kasirgo/lib/
├── main.dart                      # entry point
├── app.dart                       # router (GoRouter) + wiring role + alert/tema
├── config/
│   ├── app_theme.dart             # DESIGN SYSTEM "Centennial Modern Ocean White" (SATU SUMBER WARNA/FONT)
│   ├── constants.dart             # appVersion/appBuildNumber + konstanta bisnis
│   └── supabase_config.dart       # URL + anon key Supabase
├── core/                          # util inti (error messages, helpers)
├── models/                        # Product, Transaction, Customer, dll (data classes)
├── providers/                     # Riverpod state (currentUser, order badge, dll)
├── services/                      # SupabaseService, SyncService, AI, Payment, dll
├── utils/                         # ai_engine, wa_helper, pdf, geo, dll
├── screens/                       # ★ Halaman UI (lihat rincian di bawah)
└── widgets/                       # ★ Komponen UI reusable
```

### 2.1 Screens (halaman) — dikelompokkan berdasarkan peran

```
screens/auth/            # Login, daftar, verifikasi KYC
├── login_screen.dart
├── register_screen.dart
├── onboarding_kyc_screen.dart     # form KYC (nama/KTP/selfie/toko)
└── kyc_upload_screen.dart         # unggah foto KTP + selfie

screens/buyer/           # Mode pembeli (pasar hyperlocal)
├── mode_gate.dart                 # ganti mode: Penjual / Pembeli
├── mode_select_screen.dart
├── buyer_shell.dart               # kerangka navigasi pembeli
├── buyer_home_tab.dart            # radar toko terdekat
├── buyer_auth_screen.dart         # login/daftar pembeli
├── buyer_onboarding_screen.dart   # isi identitas & kategori usaha (pembeli)
├── buyer_checkout_screen.dart     # checkout pesanan
├── buyer_order_tracking_screen.dart # lacak pesanan realtime
└── buyer_help_screen.dart         # panduan pembeli

screens/owner/           # Halaman pemilik (paling lengkap)
├── owner_home_screen.dart         # dashboard beranda (kartu omzet + shortcut)
├── pos_screen.dart                # kasir/POS pemilik
├── product_list_screen.dart       # daftar produk
├── product_form_screen.dart       # tambah/edit produk (+ varian/layanan)
├── customer_list_screen.dart      # data pelanggan (kasbon/piutang)
├── employee_screen.dart           # kelola karyawan & peran
├── shift_screen.dart              # shift kasir
├── report_screen.dart             # laporan keuangan (SAK EMKM)
├── report_schedule_screen.dart    # laporan otomatis ke bos
├── staff_performance_screen.dart  # performa staf
├── qr_table_screen.dart           # QR meja (cafe/resto)
├── online_catalog_screen.dart     # katalog online / WA
├── whatsapp_broadcast_screen.dart # broadcast promo via WA
├── settings_screen.dart           # pengaturan toko & program pendukung
├── guide_screen.dart              # panduan dalam aplikasi
├── help_center_screen.dart        # pusat bantuan (panduan + tiket)
├── support_tickets_screen.dart    # tiket bantuan ke tim
├── debt_screen.dart               # kasbon / piutang pelanggan
├── multi_outlet_screen.dart       # kelola multi-outlet
├── affiliate_owner_screen.dart    # program afiliasi pemilik
├── health_score_screen.dart       # skor kesehatan usaha
├── business_doctor_screen.dart    # Dokter Bisnis AI (chat)
├── doctor_intake_screen.dart      # cek fisik toko (wizard)
├── doctor_cases_screen.dart       # riwayat konsultasi
├── doctor_result_screen.dart      # hasil diagnosa
├── doctor_promotion_log_screen.dart # catat hasil promosi & ROI
├── doctor_rapor_roi_screen.dart   # rapor ROI
├── doctor_scaling_screen.dart     # rencana scaling
├── doctor_vitals_screen.dart      # vital/ringkasan bisnis
├── dynamic_pricing_screen.dart    # atur harga & diskon (AI)
├── bundle_manager_screen.dart     # bundling produk
├── referral_screen.dart           # kode referral pelanggan
├── promotion_screen.dart          # studio promosi (kalender konten)
├── design_studio_screen.dart      # studio desain (copy/gambar/video)
├── ads_studio_screen.dart         # studio iklan (Meta/Google/TikTok/Shopee)
├── sidak_bos_screen.dart          # sidak stok & kas
├── sidak_stock_count_screen.dart  # hitung stok fisik
├── progress_tracker_screen.dart   # laporan & progres
├── app_update_screen.dart         # cek pembaruan aplikasi
├── lapak_live_screen.dart         # tampilkan toko di radar (live)
├── hyperlocal_screen.dart         # pasar hyperlocal (penjual)
├── midtrans_connect_screen.dart   # hubungkan Midtrans (QRIS dinamis)
├── delegate_board... -> delegation_board_screen.dart  # delegasi tugas staf
└── staradmin_dashboard.dart       # (warisan/referensi)

screens/admin/           # Halaman admin (staf)
└── admin_home_screen.dart         # dashboard admin (tab pesanan, POS, laporan)

screens/cashier/         # Halaman kasir
├── cashier_home_screen.dart       # beranda kasir (kartu pesanan masuk)
├── cashier_pos_screen.dart        # POS kasir
├── cashier_report_screen.dart     # laporan kasir
├── incoming_orders_screen.dart    # pesanan masuk (dine-in + online)
└── online_orders_screen.dart      # pesanan online

screens/kitchen/         # Halaman koki / dapur
└── kitchen_home_screen.dart       # KDS (layar dapur)

screens/customer/        # Sisi pelanggan (QR meja / katalog)
├── customer_menu_screen.dart      # menu dine-in
├── customer_catalog_screen.dart   # katalog publik
└── customer_order_screen.dart     # status pesanan pelanggan

screens/modules/         # Modul lintas peran
├── debt_screen.dart               # kasbon
├── kitchen_display_screen.dart    # display dapur (KDS)
├── ppob_screen.dart               # PPOB (pulsa/token/dll)
├── restock_screen.dart            # B2B kulakan (restock)
└── supporter_screen.dart          # berlangganan Program Pendukung (Rp50.000/bln)
```

### 2.2 Widgets (komponen reusable)

```
widgets/
├── pos/                 # komponen POS
│   ├── cart_panel.dart
│   ├── checkout_dialog.dart
│   ├── checkout_success_dialog.dart
│   └── product_grid.dart
├── ads/sponsor_ad_slot.dart        # slot iklan sisi pelanggan
├── guide/guide_mock.dart           # simulasi layar panduan bergambar
└── common/                         # komponen bersama
    ├── app_button.dart / app_card.dart / app_text_field.dart / app_badge.dart
    ├── app_drawer.dart / app_close_button.dart / app_dropdown_field.dart
    ├── app_empty_state.dart / empty_state_widget.dart / error_widget.dart
    ├── loading_widget.dart / logout_button.dart / search_bar.dart
    ├── glass_card.dart / bubble_glass.dart / centennial_background.dart
    ├── responsive.dart             # mobile/tablet/desktop
    ├── stock_badge.dart            # badge stok (hijau/kuning/merah)
    ├── kyc_gate.dart               # gerbang KYC
    ├── web_install_gate.dart       # gerbang web->APK (wajib install HP)
    ├── supporter_gate.dart         # gerbang fitur premium
    ├── delegation_tasks_card.dart  # kartu tugas delegasi
    ├── dm_channel_connect_sheet.dart
    ├── dynamic_qris_sheet.dart     # sheet pembayaran QRIS dinamis
    ├── doctor_badge_chip.dart
    └── business_doctor/doctor_blocks.dart  # renderer blok jawaban AI
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