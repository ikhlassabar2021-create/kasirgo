# Test Plan KasirGo — Phase 1 s/d 7 × Role × Tipe Usaha

App: **https://ikhlassabar2021-create.github.io/kasirgo/**
Superadmin: **https://ikhlassabar2021-create.github.io/kasirgo/admin/**

Legenda: `[ ]` belum · `[x]` PASS · `[!]` FAIL · `[/]` BLOKIR · `[-]` tak bisa di web

---

# BAGIAN 0 — PERSIAPAN (WAJIB)

## 0.1 Setelan Supabase
Dashboard: https://supabase.com/dashboard/project/lmvjecdvfzsmrowwwpck

- [ ] **Authentication → URL Configuration**
  - Site URL = `https://ikhlassabar2021-create.github.io/kasirgo/`
  - Redirect URLs = `https://ikhlassabar2021-create.github.io/kasirgo/`
- [ ] **Authentication → Providers → Email → Confirm email**
  - Pilih **ON** (ada email konfirmasi) atau **OFF** (langsung login)
- [ ] **SQL Editor** → jalankan `docs/migrations/2026-09-28-fix-staff-auth-trigger.sql`

## 0.2 Akun yang harus dibuat (matriks test)

| Akun | Dibuat oleh | Cara | Login |
|---|---|---|---|
| Owner Warung | Anda | `/register` pilih "Warung Sembako" | email+password |
| Owner Gerobak | Anda | `/register` pilih "Gerobak" | email+password |
| Owner Cafe | Anda | `/register` pilih "Cafe" | email+password |
| Admin | Owner | menu Karyawan role Admin | email+password |
| Kasir | Owner | menu Karyawan role Kasir | email+password |
| Superadmin | — | panel `/admin/` | `admin@kasirgo.com` / `password123` |
| Pelanggan | — | `/customer` | tanpa login (kode outlet) |

---

# BAGIAN 1 — TEST PER PHASE (alur utama)

## PHASE 1 — Supabase DB + Auth
- [ ] 1.1 Registrasi owner (email+password) berhasil
- [ ] 1.2 Logout → login ulang
- [ ] 1.3 Password salah → error jelas
- [ ] 1.4 Register email duplikat → error jelas
- [ ] 1.5 Login Google berhasil
- [ ] 1.6 Outlet otomatis dibuat saat daftar
- [ ] 1.7 RLS: 2 owner tidak saling lihat data

## PHASE 2 — App Shell + Auth
- [ ] 2.1 Halaman login rapi
- [ ] 2.2 Navigasi tidak ada layar putih
- [ ] 2.3 Redirect sesuai role (owner→/owner, kasir→/cashier, admin→/admin)
- [ ] 2.4 Refresh saat login → tetap login
- [ ] 2.5 Belum login → diarahkan ke /login
- [-] 2.6 Offline engine (SQLite) — tak bisa di web

## PHASE 3 — Produk + POS + QRIS Manual + AI
- [ ] 3.1 Tambah produk
- [ ] 3.2 Edit produk
- [ ] 3.3 Hapus produk
- [ ] 3.4 POS tambah item ke keranjang
- [ ] 3.5 Ubah qty → subtotal benar
- [ ] 3.6 Hapus item
- [ ] 3.7 Checkout Cash → tersimpan
- [ ] 3.8 Upload gambar QRIS (Pengaturan → QRIS Toko)
- [ ] 3.9 Checkout QRIS → gambar QRIS muncul otomatis
- [ ] 3.10 Ganti/hapus gambar QRIS
- [ ] 3.11 AI insight di dashboard
- [-] 3.12 Scan barcode kamera — tak bisa di web

## PHASE 4 — Laporan + Pelanggan + Karyawan
- [ ] 4.1 Laporan transaksi nominal benar
- [ ] 4.2 Total pendapatan cocok
- [ ] 4.3 Tambah pelanggan
- [ ] 4.4 Edit/hapus pelanggan
- [ ] 4.5 Buat akun Karyawan Kasir (email+password)
- [ ] 4.6 Buat akun Karyawan Admin (email+password)
- [ ] 4.7 Login Kasir → masuk POS
- [ ] 4.8 Login Admin → masuk dashboard admin

## PHASE 5 — Premium/Subscription (OBSOLETE)
- [ ] 5.1 Tidak ada gate upgrade premium
- [ ] 5.2 Tidak ada batas 500 produk/transaksi

## PHASE 5.5 — Retrofit 3.0 (modul + kasbon)
- [ ] 5.5.1 Modul dashboard sesuai tipe (lihat Bagian 2)
- [ ] 5.5.2 Badge tipe benar
- [ ] 5.5.3 Kasbon dibuat
- [ ] 5.5.4 Kasbon ditandai lunas
- [-] 5.5.5 SQLCipher/sync — terbatas web

## PHASE 6 — Kasbon + WhatsApp + Sponsor
- [ ] 6.1 Catat piutang kasbon
- [ ] 6.2 Cicilan kasbon
- [ ] 6.3 Kirim struk WhatsApp
- [ ] 6.4 Teks struk benar
- [ ] 6.5 Broadcast promo
- [!] 6.6 Banner sponsor struk — tidak ada di kode

## PHASE 7 — QRIS Payment
- [ ] 7.1 QRIS manual/statis (gambar) berfungsi
- [!] 7.2 QRIS dinamis gateway — backend belum ada
- [-] 7.3 Webhook HMAC — butuh backend
- [-] 7.4 Settlement/split — butuh backend

## PHASE 7.6 — UI Retrofit (light)
- [ ] 7.6.1 Tema terang konsisten
- [ ] 7.6.2 Tidak ada layar tema gelap lama
- [ ] 7.6.3 Layout rapi di mobile

## PHASE 7.7 — Control Plane + KYC + Superadmin
- [ ] 7.7.1 Panel superadmin terbuka
- [ ] 7.7.2 Login superadmin
- [ ] 7.7.3 Navigasi menu superadmin
- [!] 7.7.4 Setting superadmin mock
- [ ] 7.7.5 KYC field di register

---

# BAGIAN 2 — MATRIKS MODUL PER TIPE (Phase 5.5)

Cek di dashboard owner: menu yang muncul HARUS sesuai tabel ini.

| Menu Modul | Warung | Gerobak | Cafe/Resto | Retail |
|---|:---:|:---:|:---:|:---:|
| POS | ✅ | ✅ | ✅ | ✅ |
| Inventori/Produk | ✅ | ✅ | ✅ | ✅ |
| Kasbon | ✅ | ✅ | ✅ | ✅ |
| **PPOB** | ✅ | ❌ | ❌ | ✅ |
| **QR Meja Dine-in** | ❌ | ❌ | ✅ | ❌ |
| **KDS/Dapur** | ✅ | ✅ | ✅ | ❌ |
| Varian | ✅ | ✅ | ✅ | ✅ |
| Resep | ✅ | ✅ | ✅ | ✅ |
| Split Bill | ✅ | ✅ | ✅ | ✅ |
| Kulakan B2B | ✅ | ✅ | ✅ | ✅ |
| Harga Grosir | ✅ | ✅ | ✅ | ✅ |
| WA Marketing | ✅ | ✅ | ✅ | ✅ |
| Katalog Online | ✅ | ✅ | ✅ | ✅ |
| Health Score | ✅ | ✅ | ✅ | ✅ |

**Test:**
- [ ] Warung: PPOB **muncul**, QR Meja **tidak muncul**
- [ ] Gerobak: PPOB **tidak muncul**, QR Meja **tidak muncul**
- [ ] Cafe: PPOB **tidak muncul**, QR Meja **muncul**, KDS **muncul**
- [ ] Badge tipe di dashboard: KELONTONG / GEROBAK / CAFE & RESTO

---

# BAGIAN 3 — TEST PER ROLE LOGIN

## 3A. SUPERADMIN  (web terpisah, data mock)
URL: `.../kasirgo/admin/` · Login: `admin@kasirgo.com` / `password123`

- [ ] Buka `/admin/` → halaman login tampil
- [ ] Login superadmin berhasil
- [ ] Dashboard superadmin (statistik) tampil
- [ ] Menu **Users** → daftar user (mock)
- [ ] Klik satu user → detail user
- [ ] Menu **Revenue/Transactions** tampil
- [ ] Menu **Affiliates** tampil
- [ ] Menu **Control Plane / Settings** tampil
- [ ] Menu **Backup** tampil
- [ ] Logout berhasil
- [!] Catat: data = MOCK, tidak tersambung DB asli

## 3B. OWNER  (login email+password) — 3 tipe
Untuk **Owner Warung**, **Owner Gerobak**, **Owner Cafe** (ulangi tiap tipe):

**Dashboard**
- [ ] Masuk dashboard tidak blank
- [ ] Badge tipe benar
- [ ] Modul sesuai Bagian 2
- [ ] Banner QRIS muncul (belum diatur)

**Produk (Phase 3)**
- [ ] Tambah produk → muncul
- [ ] Edit produk
- [ ] Hapus produk

**QRIS (Phase 3 & 7)**
- [ ] Pengaturan → QRIS Toko → upload gambar → simpan
- [ ] Banner QRIS hilang
- [ ] POS → QRIS → gambar toko muncul

**POS (Phase 3)**
- [ ] Tambah item, Cash → tersimpan
- [ ] Transaksi QRIS → tersimpan
- [ ] Transaksi Bank Transfer → tersimpan

**Laporan (Phase 4)**
- [ ] Transaksi muncul nominal benar

**Pelanggan (Phase 4)**
- [ ] Tambah pelanggan
- [ ] Edit/hapus pelanggan

**Karyawan (Phase 4)**
- [ ] Buat akun Kasir → berhasil
- [ ] Buat akun Admin → berhasil

**Kasbon (Phase 5.5/6)**
- [ ] Buat kasbon
- [ ] Tandai lunas

**WhatsApp (Phase 6)**
- [ ] Checkout centang "Kirim Struk WhatsApp" → wa.me terbuka

**Pengaturan**
- [ ] Edit profil usaha
- [ ] Menu "Tautkan Akun Google" (bukan OTP)

## 3C. ADMIN  (login email+password, dibuat owner)
- [ ] Login admin → masuk `/admin`, tidak blank
- [ ] Bisa lihat/modif Produk
- [ ] Bisa lihat Laporan
- [ ] Logout berhasil

## 3D. KASIR  (login email+password, dibuat owner)
- [ ] Login kasir → masuk `/cashier` (POS), tidak blank
- [ ] Buat transaksi Cash
- [ ] Buat transaksi QRIS (gambar QRIS muncul)
- [ ] Logout berhasil

## 3E. PELANGGAN  (tanpa login)
- [ ] Buka `#/customer`
- [ ] Masukkan kode outlet
- [ ] Menu/produk tampil
- [ ] Buat pesanan (jika alur tersedia)

---

# BAGIAN 4 — MATRIKS LENGKAP (centang per sel)

Format: Phase → role × tipe. Isi P/F/B.

## Phase 1 (Auth)
| Role | Warung | Gerobak | Cafe |
|---|:---:|:---:|:---:|
| Superadmin | — | — | — |
| Owner | [ ] | [ ] | [ ] |
| Admin | [ ] | [ ] | [ ] |
| Kasir | [ ] | [ ] | [ ] |

## Phase 2 (Shell/Nav)
| Role | Warung | Gerobak | Cafe |
|---|:---:|:---:|:---:|
| Owner | [ ] | [ ] | [ ] |
| Admin | [ ] | [ ] | [ ] |
| Kasir | [ ] | [ ] | [ ] |

## Phase 3 (Produk/POS/QRIS)
| Role | Warung | Gerobak | Cafe |
|---|:---:|:---:|:---:|
| Owner | [ ] | [ ] | [ ] |
| Kasir | [ ] | [ ] | [ ] |

## Phase 4 (Laporan/Pelanggan/Karyawan)
| Role | Warung | Gerobak | Cafe |
|---|:---:|:---:|:---:|
| Owner | [ ] | [ ] | [ ] |
| Admin | [ ] | [ ] | [ ] |

## Phase 5 (Premium - obsolete)
| Role | Warung | Gerobak | Cafe |
|---|:---:|:---:|:---:|
| Owner | [ ] | [ ] | [ ] |

## Phase 5.5 (Modul/Kasbon)
| Role | Warung | Gerobak | Cafe |
|---|:---:|:---:|:---:|
| Owner | [ ] | [ ] | [ ] |

## Phase 6 (Kasbon/WA)
| Role | Warung | Gerobak | Cafe |
|---|:---:|:---:|:---:|
| Owner | [ ] | [ ] | [ ] |
| Kasir | [ ] | [ ] | [ ] |

## Phase 7 (QRIS)
| Role | Warung | Gerobak | Cafe |
|---|:---:|:---:|:---:|
| Owner | [ ] | [ ] | [ ] |
| Kasir | [ ] | [ ] | [ ] |
| Superadmin | [ ] | [ ] | [ ] |

## Phase 7.6 (UI)
| Role | Warung | Gerobak | Cafe |
|---|:---:|:---:|:---:|
| Owner | [ ] | [ ] | [ ] |
| Admin | [ ] | [ ] | [ ] |
| Kasir | [ ] | [ ] | [ ] |
| Superadmin | [ ] | [ ] | [ ] |

## Phase 7.7 (Control Plane/KYC)
| Role | Warung | Gerobak | Cafe |
|---|:---:|:---:|:---:|
| Superadmin | [ ] | [ ] | [ ] |
| Owner | [ ] | [ ] | [ ] |

---

# BAGIAN 5 — URUTAN EKSEKUSI YANG DISARANKAN

1. Siapkan Supabase (Bagian 0.1).
2. Buat 3 owner (Warung, Gerobak, Cafe) via `/register`.
3. Untuk tiap owner: jalankan Blok 3B lengkap.
4. Dari owner, buat akun Admin & Kasir.
5. Jalankan Blok 3C (Admin) & 3D (Kasir).
6. Jalankan Blok 3E (Pelanggan).
7. Jalankan Blok 3A (Superadmin).
8. Isi matriks Bagian 4.

# BAGIAN 6 — LAPORAN HASIL
Kirim ke saya item yang FAIL/BLOKIR dengan nomor + screenshot, contoh:
- `3.9 Warung QRIS muncul → FAIL, gambar kosong`
- `3D Kasir login → BLOKIR, stuck loading`
