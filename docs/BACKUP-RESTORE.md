# Backup & Restore KasirGo

Panduan lengkap untuk mem-backup dan memulihkan seluruh sistem KasirGo
(aplikasi Flutter, superadmin web, database Supabase, Edge Functions, dan
konfigurasi eksternal) ke kondisi yang berfungsi penuh.

Dibuat: 2 November 2026 — commit `fc9fb51`, tag backup `backup-2026-11-02`.

---

## 1. Fakta Kritis (jangan sampai hilang)

| Item | Nilai |
|------|-------|
| Repo GitHub | `https://github.com/ikhlassabar2021-create/kasirgo.git` |
| Supabase Project Ref | `lmvjecdvfzsmrowwwpck` |
| Region / DB host | `ap-southeast-1` / `db.lmvjecdvfzsmrowwwpck.supabase.co` |
| Pooler (psql) | `aws-0-ap-southeast-1.pooler.supabase.com:5432` user `postgres.lmvjecdvfzsmrowwwpck` |
| Domain web | `https://dokterbisnis.web.id/` (GitHub Pages root) |
| Superadmin | `https://dokterbisnis.web.id/admin/` |
| Akun superadmin | `superadmin@kasirgo.com` |
| SMTP | Mailjet `in-v3.mailjet.com:587`, user `ac09e11a9bc0835fa33b2dc7766c1b8b` |
| Keystore release APK | PKCS12 `kasirgo` (dipegang pemilik, TIDAK di repo) |

---

## 2. Komponen yang Perlu Di-backup

1. **Kode sumber** (aplikasi Flutter + admin React + migrations + docs) — Git.
2. **Database Postgres** (13+ tabel, RLS, triggers, RPC, data) — Supabase.
3. **Vault secrets** (server key gateway, kunci enkripsi DM, kunci AI) — Supabase.
4. **Edge Functions** (17 fungsi) — sumber di repo + konfigurasi deployed.
5. **Konfigurasi Auth SMTP & redirect** — Supabase dashboard.
6. **Bundle web + admin** (gh-pages) — dapat dibangun ulang dari kode.
7. **PDF panduan** — `docs/panduan-kasirgo.pdf` (dapat digenerate ulang).
8. **Keystore APK** — dipegang manual oleh pemilik.

---

## 3. Cara Backup

### 3.1 Kode sumber (otomatis)
```bash
git clone https://github.com/ikhlassabar2021-create/kasirgo.git
git tag backup-$(date +%F)   # penanda titik pulih
git push origin --tags
```

### 3.2 Database (cara termudah — dashboard)
1. Buka Supabase Dashboard → project `lmvjecdvfzsmrowwwpck`.
2. Menu **Database → Backups**.
3. Klik **Create backup** (jika tersedia) atau unduh backup terbaru
   (file `.sql` hasil `pg_dump`, berisi schema + data).

### 3.3 Database (via psql, opsional)
```bash
# Menggunakan koneksi langsung (password DB dimiliki owner)
pg_dump "postgresql://postgres.lmvjecdvfzsmrowwwpck@db.lmvjecdvfzsmrowwwpck.supabase.co:5432/postgres" \
  --clean --if-exists --no-owner > kasirgo-backup-$(date +%F).sql
```

### 3.4 Vault secrets (DAFTAR — nilai hanya bisa dibaca service_role)
Isi `system_api_configs` menyimpan `secret_id` (uuid ke `vault.secrets`),
bukan teks. Nilai kunci **tidak dapat diekspor** dari dashboard. Pastikan
pemilik menyimpan cadangan nilai berikut di tempat aman (password manager):

| Nama secret | Untuk apa |
|-------------|-----------|
| `midtrans_229c94d7-...` | Server key Midtrans (Toko Test) |
| `midtrans_5dda8727-...` | Server key Midtrans (Warung Test) |
| `dm_channel_token_key` | Kunci enkripsi token akun channel DM |
| `kasirgo system_api primary` | Primary key LLM (sistem API AI) |

### 3.5 Konfigurasi Auth/SMTP (catat manual)
- `site_url` = `https://dokterbisnis.web.id/`
- `uri_allow_list` = `https://dokterbisnis.web.id/**` (+ github.io lama selama transisi)
- SMTP Mailjet: host/port/user seperti tabel §1; **password SMTP (secret Mailjet)
  disimpan terpisah dan tidak bisa dibaca ulang** — simpan `MJ_APIKEY` / `MJ_SECRET`.

---

## 4. Cara Restore

### 4.1 Restore Database (prioritas utama)
Dari backup `pg_dump`:
```bash
psql "postgresql://postgres.lmvjecdvfzsmrowwwpck@db.lmvjecdvfzsmrowwwpck.supabase.co:5432/postgres" \
  -f kasirgo-backup-YYYY-MM-DD.sql
```
Alternatif (jika tidak ada pg_dump, dari migrations):
```bash
# Berlaku BERSIH dari awal, urut sesuai tanggal
for f in docs/migrations/*.sql; do
  psql "<dsn>" -f "$f"
done
```
> Catatan: sebagian migration idempoten (`IF NOT EXISTS`), sebagian mengasumsikan
> kondisi tertentu. Untuk hasil terbaik gunakan pg_dump, bukan replays migrations.

### 4.2 Restore Vault secrets
Superadmin dapat menulis ulang kunci via aplikasi:
- Superadmin → Control Plane → **Konfigurasi API AI** (primary/backup key → Vault).
- Atau via RPC `admin_save_system_api_config` / `vault_put_secret` (service_role).

### 4.3 Deploy ulang Edge Functions
```bash
export SUPABASE_ACCESS_TOKEN=<PAT>   # sbp_... (di /tmp/opencode/sb.env saat aktif)
/tmp/opencode/supabase functions deploy doctor-proxy --project-ref lmvjecdvfzsmrowwwpck
# Lifetime fungsi + verify_jwt (dari §5): rcb_webhook, midtrans_webhook,
#   dm_creative, dm_oauth, rcb_create_charge => verify_jwt=false
```

### 4.4 Restore web + admin (gh-pages)
```bash
git push origin main   # memicu workflow Deploy Web (build Flutter web + admin)
# atau manual:
#   cd kasirgo && flutter build web --release --base-href /
#   cd kasirgo-admin && npm ci && npm run build
#   salin deploy/ ke branch gh-pages (keep_files)
```

### 4.5 Restore APK release
1. Pastikan GitHub Secrets terisi: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
   `KEY_ALIAS`, `KEY_PASSWORD`.
2. Push tag `v*` → workflow `Release APK` → artefak signed.
   Tanpa secret, artefak debug-signed dan harus di-re-sign lokal (lihat `docs/RELEASE.md`).

---

## 5. Daftar Edge Functions (17)

| Fungsi | verify_jwt | Catatan |
|--------|-----------|---------|
| rcb_create_charge | false | |
| rcb_check_status | true | |
| rcb_webhook | false | |
| create_staff | true | |
| onboard_merchant | true | |
| save_payment_config | true | |
| test_payment_connection | true | |
| create_payment | true | |
| midtrans_webhook | false | |
| business_doctor_chat | true | |
| doctor_observe | true | |
| dm_creative | false | |
| dm_oauth | false | |
| doctor_briefing | true | |
| tts_speak | true | |
| stt_fix | true | |
| doctor-proxy | true | |

---

## 6. Verifikasi Setelah Restore

- [ ] `https://dokterbisnis.web.id/` membuka aplikasi (HTTP 200).
- [ ] Login owner berhasil, KYC dan data produk/stok tampil.
- [ ] `https://dokterbisnis.web.id/admin/` membuka superadmin.
- [ ] `https://dokterbisnis.web.id/panduan/panduan-kasirgo.pdf` HTTP 200.
- [ ] QRIS dinamis / pembayaran berfungsi (server key di Vault terisi).
- [ ] Chat Dokter Bisnis merespons (kunci AI di `system_api_configs` valid).
- [ ] Email konfirmasi pendaftaran terkirim ke domain `dokterbisnis.web.id`.