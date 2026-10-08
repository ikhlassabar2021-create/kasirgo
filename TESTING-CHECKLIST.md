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
