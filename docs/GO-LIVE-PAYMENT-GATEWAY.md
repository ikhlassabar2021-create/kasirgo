# KASIRGO — GO-LIVE Payment Gateway (Midtrans QRIS Dinamis)

> Phase 13C ST13C-3. Panduan go-live production + hasil audit keamanan.
> Prinsip zero-custody: Server Key TIDAK PERNAH ada di app/klien; hanya di
> Edge Function + Supabase Vault.

## 1. Checklist Go-Live per Outlet

| # | Langkah | Lokasi |
|---|---|---|
| 1 | Daftar/verifikasi akun Midtrans production (identitas + rekening) | dashboard.midtrans.com |
| 2 | **Aktifkan channel QRIS** (Settings → Payment Channels) — WAJIB, tanpa ini charge gagal `402 Payment channel is not activated` | dashboard.midtrans.com |
| 3 | Ambil Access Keys: **Merchant ID, Client Key, Server Key** (production, prefix `Mid-server-`) | Settings → Access Keys |
| 4 | Owner buka app → **Pengaturan → Hubungkan Midtrans (QRIS Dinamis)** → isi 3 kunci → toggle **Mode Produksi** ON → **Tes Koneksi** | App (wizard 13B) |
| 5 | Pastikan status berubah **verified** ("Kredensial valid") | App / Control Plane superadmin |
| 6 | (Opsional) Superadmin verifikasi di Control Plane → tab **Payment Gateway** → tabel Status per Outlet | Superadmin web |
| 7 | Uji charge nyata nominal kecil (mis. Rp 1.000–10.000), scan dengan e-wallet, pastikan otomatis LUNAS via webhook | POS app |

Catatan penting:
- **QRIS Midtrans = dinamis (API)** setelah channel aktif. QRIS statis (QR tetap milik
  toko, tanpa webhook) TIDAK bisa otomatis — tetap tersedia di app sebagai fallback
  gratis dengan konfirmasi manual kasir.
- **Notification URL**: Midtrans mengirim webhook ke URL yang didaftarkan di
  dashboard (Settings → Configuration → Payment Notification URL). Isi:
  `https://lmvjecdvfzsmrowwwpck.supabase.co/functions/v1/midtrans_webhook`
  (Uji sandbox 13A/13C-2 memanggil webhook langsung; di produksi pastikan URL ini
  terdaftar agar PAID otomatis tanpa panggilan manual.)

## 2. Hasil Uji E2E (ST13C-2, sandbox — SEMUA LULUS)

Outlet percontohan: **Warung Test** (`5dda8727-...`), `is_production=false`.

| Uji | Hasil |
|---|---|
| Tes koneksi (`test_payment_connection`) | `valid:true, HTTP 200`, status → `verified` |
| Charge QRIS dinamis (Rp 11.008) | `PENDING` + `qris_string` dinamis + `qris_url` PNG (HTTP 200) |
| Webhook `settlement` (signature SHA512 valid) | → `PAID` |
| Webhook ulang | `idempotent:true` (efek samping tak diulang) |
| Webhook signature salah | **401** "Invalid signature" |
| Alur POS penuh: transaksi `unpaid` → charge (dengan `transaction_id`) → webhook | `payment_orders=PAID`, `transactions.payment_status='paid'`, `paid_at` terisi, `provider_ref` = order id |

## 3. Hasil Audit Keamanan (ST13C-3)

| Area | Temuan | Status |
|---|---|---|
| Kunci di repo / git history / bundle web (app & admin) | Tidak ada kunci asli (hanya hint `SB-Mid-server-...` sebagai placeholder) | ✅ |
| Hardcoded JWT di repo | Hanya **anon key** (app + admin) — role `anon`, wajar | ✅ |
| `service_role` key | Tidak ada di repo; hanya env var Edge Function | ✅ |
| RLS `outlet_pg_configs` | Aktif; owner hanya bisa SELECT miliknya | ✅ |
| Kolom `server_key_secret_id` | Hanya postgres/service_role (owner tidak bisa baca) | ✅ |
| Vault (`vault_put_secret`/`vault_read_secret`) | Hanya service_role; `vault.decrypted_secrets` tak terbaca anon/authenticated | ✅ |
| EF tanpa JWT (`save/test/create`) | 401 semua; `midtrans_webhook` verify_jwt=false (sesuai desain, dilindungi signature SHA512) | ✅ |
| Webhook signature | SHA512(order_id+status_code+gross_amount+ServerKey), ditolak 401 bila salah; idempotent | ✅ |
| **REMEDIASI** `create_payment` | Dulu menerima `amount` bebas; kini bila `transaction_id` diberikan: transaksi wajib milik outlet yang sama (403), belum dibayar (409), dan **nominal wajib sama dengan `final_amount`** (400). Terverifikasi: 400/403/409 semua bekerja | ✅ diperbaiki |
| Superadmin | Hanya lewat `is_platform_admin()`; server key tidak pernah dikembalikan (hanya `has_server_key`) | ✅ |

### Rekomendasi tindak lanjut (tidak memblokir go-live)
1. **Rotate Server Key production Toko Test** — kunci pernah melewati chat (Phase 13A).
   Caranya: dashboard Midtrans → Access Keys → regenerate, lalu owner update di
   wizard app (Server Key baru otomatis menggantikan yang lama di Vault).
2. Kredensial sandbox diberikan via chat — tidak dipakai di produksi, boleh diabaikan;
   tidak tersimpan di repo.
3. Data uji sandbox tersisa di Warung Test (2 order + beberapa transaksi, nilai kecil)
   — aman dihapus kapan pun (minta helper psql bila perlu).

## 4. Provider QRIS Dinamis Alternatif (selain Midtrans & Duitku)

Kriteria user: proses verifikasi mudah (setara Midtrans "upload KTP saja"),
**berlisensi PJP** (Penyelenggara Jasa Pembayaran — laporan ke Bank Indonesia),
QRIS dinamis + webhook otomatis.

> Catatan: QRIS **hanya boleh diterbitkan lewat PJP/PJSP berizin BI**. Provider di
> bawah semuanya PJP/PJSP atau bekerja lewat PJP berizin, jadi QRIS-nya sah.

| Provider | Kemudahan onboarding | Biaya umum | Integrasi |
|---|---|---|---|
| **Xendit** | PJP via partner PJSP; pendaftaran online, dokumen: KTP+NPWP+foto usaha; approval umumnya 1–5 hari kerja; sandbox instan | QRIS ±0,7% | REST + webhook; SDK banyak; dokumentasi terbaik |
| **iPaymu** | PJP lokal; daftar online cukup KTP (umumnya 1–3 hari); sandbox tersedia | QRIS ±0,7% (flat) | REST + webhook sederhana; paling ringan |
| **Tripay** | Agya via PJP berizin; daftar online, dokumen ringan; approval cepat | QRIS ±0,7% | REST + webhook sederhana |
| **Duitku** | PJP; daftar online; approval cepat | QRIS ±0,7% | REST + webhook (dikecualikan user) |
| **Midtrans** (baseline) | PJP; upload KTP; approval bisa >1 minggu | QRIS 0,7% | Core API + webhook (sudah jalan) |

**Rekomendasi KasirGo**: **Xendit** (paling matang, sandbox instan, webhook rapi) atau
**iPaymu** (onboarding paling ringan, biaya flat). Arsitektur sudah siap: karena app
memakai lapisan `PgProviderClient`, menambah provider = 1 kelas Dart + kolom `provider`
+ 1–2 Edge Function baru (`create_payment`/`webhook` varian), tanpa mengubah UI.

## 5. Rollback / Darurat
- Nonaktifkan outlet: Control Plane superadmin → Payment Gateway → **Nonaktifkan**
  (`create_payment` otomatis menolak saat disabled).
- Server key bocor? **Segera rotate** di dashboard Midtrans + update di wizard app.
- Webhook tidak sampai? Cek order via Midtrans dashboard; alur manual: kasir
  konfirmasi QRIS statis (fallback).
