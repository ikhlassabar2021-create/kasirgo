# CHECKLIST TESTING KASIRGO 3.0 — Phase 1 s.d. Phase 15

Tanggal checklist: 2026-10-08 (tanggal sistem sandbox).
Semua password akun test: **`sabar2021`**

## Akses

| Platform | URL |
|---|---|
| App (owner/admin/kasir/koki/customer) | https://ikhlassabar2021-create.github.io/kasirgo/ |
| Superadmin (React) | https://ikhlassabar2021-create.github.io/kasirgo/admin/ |
| Supabase project | `lmvjecdvfzsmrowwwpck` |

### Akun Test
| Email | Role | Outlet | Keterangan |
|---|---|---|---|
| ikhlassabar2021@gmail.com | Owner | Toko Test (Cafe) | trial s.d. 14 Okt |
| ikhlassabar2021+warung@gmail.com | Owner | Warung Test (Sembako) | trial s.d. 13 Okt, PG sandbox |
| ikhlassabar2021+gerobak@gmail.com | Owner | Gerobak Test | **trial EXPIRED** → uji paywall |
| ikhlassabar2021+adminc@gmail.com | Admin | Toko Test | |
| ikhlassabar2021+adminw@gmail.com | Admin | Warung Test | |
| ikhlassabar2021+adming@gmail.com | Admin | Gerobak Test | |
| ikhlassabar2021+kasir@gmail.com | Kasir | Toko Test | |
| ikhlassabar2021+kasirw@gmail.com | Kasir | Warung Test | |
| ikhlassabar2021+kasirg@gmail.com | Kasir | Gerobak Test | |
| ikhlassabar2021+kokitest@gmail.com | Koki | Toko Test | langsung masuk KDS |
| superadmin@kasirgo.com | Superadmin | — | hanya di `/admin/` |
| ikhlassabar2021+affiliate@gmail.com | Owner | Toko Baru | uji afiliasi |

### Blocker & Catatan Global
- ⚠️ **Midtrans production QRIS belum aktif** (`402 Payment channel is not activated`) → uji QRIS Midtrans via **sandbox** saja.
- ⚠️ **pg_cron/pg_net tidak terpasang** → observasi dokter/laporan mingguan dijalankan manual via tombol admin "Jalankan Observasi".
- ⚠️ **Warung Test `unlimited_tokens=true`** masih menyala (sisa uji ST15-2) → chat AI outlet ini tidak kena kuota token.
- ⚠️ **Data uji lama belum dibersihkan** → akan terlihat sisa resep uji, target, bundle, referral, transaksi `KGO-13A-*`, dst.
- Tanggal trial mengacu 8 Okt 2026; untuk uji paywall gunakan **Gerobak Test** (expired).

### Link Pelanggan (Katalog & QR Meja)
Pola: `https://ikhlassabar2021-create.github.io/kasirgo/#/catalog?outlet=<OUTLET_ID>`
Test: `https://ikhlassabar2021-create.github.io/kasirgo/#/catalog?outlet=229c94d7-ce6d-4be1-98f5-448f600528cc`

| Outlet | Jenis | Outlet ID | Link Katalog Pelanggan |
|---|---|---|---|
| Toko Test | Cafe | `229c94d7-ce6d-4be1-98f5-448f600528cc` | https://ikhlassabar2021-create.github.io/kasirgo/#/catalog?outlet=229c94d7-ce6d-4be1-98f5-448f600528cc |
| Warung Test | Warung Sembako | `5dda8727-2439-432a-91e6-308c824c4f7a` | https://ikhlassabar2021-create.github.io/kasirgo/#/catalog?outlet=5dda8727-2439-432a-91e6-308c824c4f7a |

- **QR Meja** (dine-in cafe/resto): dibuat dari app owner → QR Meja (deep-link `#/customer?outlet=<ID>&table=<NO>`).
- Outlet uji hanya Toko Test & Warung Test yang punya produk **published** (masing-masing 2 produk).

---

## PHASE 1–2: Register & Auth + Offline-first
Akun: **daftar akun baru** (owner) + **kasir @ Toko Test**

- [ ] Daftar akun baru → outlet otomatis dibuat, masuk ke dashboard owner.
- [ ] Login kasir `+kasir@gmail.com` → menu dibatasi sesuai role kasir.
- [ ] Matikan internet → transaksi POS tetap jalan (offline-first).
- [ ] Nyalakan internet → data tersinkron otomatis (±30 detik), tidak ada transaksi dobel.

## PHASE 3: Produk, POS, Struk PDF, QRIS manual
Akun: **owner @ Toko Test**

- [ ] Produk: tambah/edit produk, stok & min-stock, badge stok menipis tampil.
- [ ] POS: cari produk, tambah ke keranjang, ubah qty, checkout tunai.
- [ ] POS: checkout QRIS manual → QR tampil, bisa diselesaikan.
- [ ] Struk: tombol cetak/PDF struk dengan **logo custom** (unggah logo di Pengaturan dulu).
- [ ] Katalog pelanggan (QR) produk tampil publik.

## PHASE 4: Laporan, Pelanggan, Karyawan
Akun: **owner @ Toko Test**

- [ ] Laporan: ringkasan penjualan, export PDF/Excel, tombol Share.
- [ ] Pelanggan: tambah pelanggan, riwayat transaksi pelanggan tampil.
- [ ] Karyawan: tambah admin/kasir/koki → kuota staf dipakai (free=terbatas, Pendukung=lebih banyak).
- [ ] Login user baru tersebut → role & outlet sesuai.

## PHASE 5–6: Kasbon, WA Broadcast, Sponsored Receipt
Akun: **owner @ Toko Test**

- [ ] Kasbon: catat kasbon pelanggan, tandai lunas.
- [ ] WA: kirim "Pesan WA" ke pelanggan (wa.me terbuka, pesan terisi).
- [ ] Sponsored receipt: slot iklan sponsor tampil di katalog/struk pelanggan.

## PHASE 7–7.8: Onboarding KYC, Redesign, Control Plane, Afiliasi
Akun: **akun baru** + **superadmin** + **affiliate**

- [ ] 7.5 Onboarding: daftar → isi KYC (email/nohp/nama toko/alamat/KTP/selfie) → status `pending` di DB `merchant_onboarding`; hanya owner melihat menu ini.
- [ ] 7.6 Redesign: semua halaman konsisten tema "Centennial Modern Ocean White", tanpa hardcode warna liar.
- [ ] 7.7 Control Plane: login superadmin di `/admin/` → tab Integrasi (RateCRB/PG/Midtrans), margin, config global — bisa diubah tanpa deploy ulang.
- [ ] 7.8 Afiliasi: login `+affiliate@gmail.com` → salin kode referral → daftar akun baru pakai kode → komisi tercatat (status pending).

## PHASE 10–11: Keuangan Platform & Payout (Superadmin)
Akun: **superadmin @ `/admin/`**

- [ ] Verifikasi KYC merchant: `pending` → `verified`.
- [ ] Laporan keuangan platform: biaya layanan, subscription, sponsor tampil.
- [ ] Afiliasi: ubah status komisi `pending` → `paid`.

## PHASE 12: RateCRB & Paylater (PG)
Akun: **customer katalog @ Warung Test** (scan QR katalog) + owner

- [ ] Skoring kredit RateCRB tampil di alur customer.
- [ ] Apply paylater PG jalan (Warung Test `outlet_pg_configs` = verified/sandbox).
- [ ] Owner melihat daftar pengajuan paylater outlet.

## PHASE 13: Midtrans QRIS & Payment Orders
Akun: **owner/kasir @ Warung Test**

- [ ] 13A: checkout via Midtrans **sandbox** → QRIS tampil → selesaikan bayar (sandbox).
- [ ] 13B: `payment_orders` berubah pending → paid (webhook sandbox).
- [ ] 13C: tawaran paylater muncul saat checkout (staff PG).
- [ ] ⚠️ Production QRIS: DOKUMENTASIKAN sebagai blocker, jangan dianggap gagal test.

## PHASE 14: Dokter Bisnis AI (Intake → Resep → Evaluasi → Teguran)
Akun: **owner @ Warung Test**

- [ ] Intake: "Diagnosa Usaha" → isi cek fisik (omzet/trafik/promosi) → AI vonis + skor kesehatan.
- [ ] Resep: checklist langkah tampil; centang langkah → progress tersimpan (tetap setelah refresh).
- [ ] Evaluasi: catat promosi (biaya/hasil) → AI hitung ROI & putuskan lanjut/ubah resep.
- [ ] Hasil Diagnosa: layar gauge/vonis/checklist/timeline tampil.
- [ ] Teguran: minta superadmin klik **"Jalankan Observasi"** (admin, tab Dokter Bisnis) → teguran bertingkat muncul bila resep lewat tenggat (anti-spam 1/hari).
- [ ] Rate limit: cek kuota token harian terpakai (kecuali Warung Test, unlimited ON).

## PHASE 15: Master Prompt, Skill & Bos Virtual
Akun: **owner @ Warung Test** + **superadmin**

- [ ] 15A: admin → tab Dokter Bisnis → Master Prompt tampil (Preview/Reset) + 16 toggle skill.
- [ ] 15B: chat "Buat target omzet harian Rp200.000" → kartu target; shortcut "Peta Ekspansi" di home → readiness + roadmap H-30/60/90; kartu target + Pace Alert di home.
- [ ] 15C: chat "Buat paket bundling Indomie + rokok" → Bundle Manager terisi; "Buat kode referral" → Referral screen (share wa.me); chip bundling di POS; strip "Paket Hemat" di katalog customer; kartu Peluang Cross-Sell di home.
- [ ] 15D (O) Kartu Identitas Bisnis: di atas chat — fase, penyakit aktif, resep berjalan, tenggat, skor kesehatan, usia usaha.
- [ ] 15D (M) Guardrail aksi: chat "Terapkan flash sale Indomie 10%" → AI mengusulkan (tidak eksekusi) → kartu **Perlu Persetujuan Anda** → Setujui/Tolak berfungsi.
- [ ] 15D (N) Benchmark hyperlocal: chat "Bandingkan omzet saya dengan warung sekitar" → agregat anonim; data tipis → tanda **"perlu verifikasi"**.
- [ ] 15D (L) Laporan mingguan: superadmin jalankan Observasi → kartu **Laporan Mingguan** muncul di chat (maks 1/pekan; jalankan kedua kali hari ini → tidak dobel).

---

## Hasil Test
| Tanggal | Phase | Tester | Hasil (OK/Gagal/Catatan) |
|---|---|---|---|
| | | | |
| | | | |
| | | | |

Laporan bug: sebutkan **email akun + phase + langkah + screenshot**.

---

## Fix List Pasca-Testing (2026-10-21) — RE-TEST
Semua item fix list sudah dieksekusi. Checklist re-test:

Owner:
- [ ] FIX #1: login dengan email belum konfirmasi → pesan "Harap konfirmasi email dulu".
- [ ] FIX #2: KYC — KTP bukan asli ditolak; selfie beda NIK ditolak; NIK+nama ter-autofill; NIK lahir 1900-an diterima.
- [ ] FIX #3: setelah checkout sukses muncul dialog sukses + tombol Struk PDF (unduh web berfungsi).
- [ ] FIX #4: Laporan → Excel (3 sheet: Ringkasan/Penjualan/Per Produk) & PDF (SAK EMKM: identitas, laba rugi, metode bayar, tanda tangan).
- [ ] FIX #5: pembayaran ada field Nama Pelanggan; isi nomor WA → nama ter-autofill.
- [ ] FIX #6: setelah checkout, pelanggan otomatis masuk daftar; hapus pelanggan via menu (⋯) berfungsi.
- [ ] FIX #7: tombol X ujung kanan di dialog Tambah Pelanggan / Hapus Produk / Scan Barcode.
- [ ] FIX #8: hapus produk yang pernah terjual kini berhasil.
- [ ] FIX #9: shortcut Peta Ekspansi & Referral tidak ada lagi di beranda.
- [ ] FIX #10: kartu PPOB/Kulakan B2B/Modal Usaha tidak tampil; tidak ada tulisan "donasi sukarela".
- [ ] FIX #11: pembayaran QRIS hanya mode statis.
- [ ] FIX #12: beranda → Afiliasi: kode & link referral (salin), komisi, riwayat closing, simpan rekening.
- [ ] FIX #13: langkah resep diklik "Jalankan" → membuka fitur terkait & tercentang tercoret.
- [ ] FIX #14: balasan Dokter Bisnis AI selalu Bahasa Indonesia & tanpa kode program.
- [ ] FIX #16: QR Meja — Enter pada field menambah meja; hapus meja sukses + snackbar.
- [ ] FIX #17: Riwayat Kasus — filter Harian/Mingguan/Bulanan; hapus satuan (⋯) & hapus semua (ikon AppBar).

Superadmin:
- [ ] FIX #12: halaman Affiliates tab Afiliasi Outlet + detail closing; ControlPlane > Afiliasi pengaturan pembayaran komisi.
- [ ] Hide laporan: Laporan Utama tanpa kartu PPOB & QRIS; Detail Outlet tanpa stat finansial & Riwayat Transaksi.
- [ ] Setting: ControlPlane > Laporan → 4 toggle visibilitas untuk membuka kembali.

---

## BATCH #2 (2026-10-08) — RE-TEST
Commit `7d57a00` (main) / web gh-pages `680c199`. Fokus: resep, struk WA, KYC, gating Dokter Bisnis, trial.

Owner:
- [ ] B2-1: Resep punya DUA tombol per langkah: "Jalankan" (buka fitur terkait + otomatis tercoret) & "Tandai Selesai" (centang murni). Semua langkah selesai → snack "Semua langkah resep selesai".
- [ ] B2-2: Struk WA text — setelah checkout (isi Nama/No WA pelanggan) → tombol "Kirim Struk Text ke WA" membuka wa.me dengan struk terisi.
- [ ] B2-3: Struk WA PDF — tombol "Kirim Struk PDF ke WA": web unduh PDF + buka chat WA; native share sheet PDF.
- [ ] B2-4: KYC — NIK 16 digit apa pun diterima (kecuali digit seragam); berkas bukan gambar (PDF di-rename .jpg) ditolak "Berkas bukan gambar"; foto asal/screenshot KTP ditolak (butuh >=2 penanda struktural + NIK).
- [ ] B2-5: Dokter Bisnis AI ter-gate Program Pendukung — akun tanpa akses (Gerobak Test) → layar kunci dengan tombol Coba Trial / Upgrade.
- [ ] B2-6: Upgrade Pendukung via QRIS DINAMIS otomatis (Warung Test sandbox). ⚠️ Production QRIS tetap blocker.
- [ ] B2-7: "Coba Trial Gratis" (di layar kunci/gate maupun di SupporterScreen) → trial aktif, semua fitur premium terbuka.

Catatan gelar: Toko Test & Warung Test masih trial aktif → untuk uji paywall pakai **Gerobak Test** (expired).

---

## BATCH #3 (2026-10-08) — RE-TEST
Commit `672286b` (main) / web gh-pages `6a7acb2`. Fokus: KYC submit, login wording, X hapus produk, resep, QRIS dinamis otomatis.

Owner:
- [ ] B3-1: submit KYC outlet baru (belum verified) → BERHASIL (`status=verified`, `auto_verified=true`); tidak lagi "Verifikasi gagal".
- [ ] B3-2: login email belum dikonfirmasi → pesan "Email harus dikonfirmasi dulu. Silakan cek email Anda (kotak masuk / folder spam) untuk tautan konfirmasi."
- [ ] B3-3: dialog Hapus Produk → tombol X di ujung kanan.
- [ ] B3-4: resep → "Tandai Selesai" langsung mencoret langkah (kartu aktif, gelembung chat, layar Hasil Diagnosa).
- [ ] B3-5: resep langkah cross_sell → "Jalankan" membuka POS (chip saran upsell), bukan Paket Bundling.
- [ ] B3-6: pembayaran produk di POS tetap memakai QRIS Statis manual (sesuai kebijakan bisnis). QRIS Dinamis otomatis digunakan saat Owner/pengguna upgrade ke Program Pendukung di SupporterScreen (`hasDynamicQr` -> pop up dynamic QRIS payment).

---

## BATCH #4 (2026-10-08) — RE-TEST
Commit `731fb3b` (main) / web gh-pages `d0e66bf`. Fokus: CORS EF payment gateway, sembunyikan menu QRIS dinamis/konfigurasi platform, hapus outlet.

Owner:
- [ ] B4-1: Pengaturan tidak lagi menampilkan menu "Hubungkan Midtrans (QRIS Dinamis)" dan kartu "Konfigurasi Platform".
- [ ] B4-2: Upgrade Program Pendukung menampilkan QRIS DINAMIS otomatis (bukan fallback statis). Root cause diperbaiki: CORS EF (`rcb_create_charge` dll) sehingga preflight browser berhasil; polling status `rcb_check_status` jalan.
- [ ] B4-3: Multi-outlet → tombol hapus (ikon tong sampah) pada outlet non-aktif. Konfirmasi → outlet terhapus. Outlet terakhir TIDAK bisa dihapus ("Minimal harus ada 1 outlet").

Catatan: CORS sudah diperbaiki di 5 EF (`rcb_create_charge`, `rcb_check_status`, `create_payment`, `save_payment_config`, `test_payment_connection`) dan ter-deploy (live tanpa rebuild app).

## BATCH #5 (2026-10-08) — RE-TEST
Commit `ff04bb3` (main) / web gh-pages `050051c`. Fokus: QRIS dinamis muncul di alur dukung Program Pendukung DARI HALAMAN PENGATURAN.

Owner:
- [ ] B5-1: Pengaturan → kartu Program Pendukung → "Dukung KasirGo Sekarang" / "Perpanjang Dukungan" → dialog konfirmasi → "Dukung/Perpanjang Sekarang" → sheet "Pembayaran QRIS" TAMPIL (QR asli + "Menunggu pembayaran…" + tombol "Buka Halaman Bayar").
- [ ] B5-2: Polling status otomatis (`rcb_check_status` tiap 5 dtk); saat PAID sheet berubah "Pembayaran Berhasil".
- [ ] B5-3: Jalur yang sama via kartu "Pendukung KasirGo" di Dashboard tetap menampilkan QRIS dinamis (regresi).

Catatan: root cause = `settings_screen._handleSupport` membuang hasil QR (hanya SnackBar). Fix: widget bersama `widgets/common/dynamic_qris_sheet.dart` dipakai kedua jalur. Verifikasi live Playwright `#/owner/settings` LULUS (`rcb_create_charge` 200 + `rcb_check_status` PENDING).
