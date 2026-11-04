# KasirGo Self-host Backup &amp; Restore (Duplicator-style)

Duplikator mirip plugin Duplicator WordPress: buat **paket backup ZIP** berisi
seluruh database + aplikasi, lalu **pulihkan** di server baru lewat wizard web
(isi nama database, user, password → next-next → selesai). Alamat/domain adaptasi
otomatis, dan **akun login ikut dipulihkan** (hash password ikut ter-copy).

## Cara kerja singkat

1. **Backup** — `dump-database.sh` menghasilkan SQL portable (schema + data +
   `auth.users`), lalu `package-backup.mjs` membungkus SQL + build web + build
   admin + installer menjadi satu `.zip`.
2. **Restore** — ekstrak zip di server, `cd installer && npm install && npm start`,
   buka domain → wizard isi DB + URL → next-next → data dipulihkan + aplikasi
   tersaji dengan alamat mengikuti domain.

## Kebutuhan

- `pg_dump` (paket `postgresql-client`) di mesin yang membuat backup.
- Node.js >= 18 (untuk menjalankan installer restore).
- PostgreSQL tujuan (rekomendasi: instance **Supabase self-host** atau VPS
  PostgreSQL; aplikasi KasirGo membutuhkan backend Supabase — bukan hanya DB).

## 1. Membuat paket backup

```bash
# a) Dump database (isi kredensial DB Postgres)
PGHOST=... PGPORT=5432 PGDATABASE=postgres PGUSER=... PGPASSWORD=... \
  bash selfhost/scripts/dump-database.sh

# b) Build aplikasi (web + admin) bila belum ada
cd kasirgo && flutter build web --release --base-href /
cd ../kasirgo-admin && npm run build
cd ..

# c) Bundel menjadi ZIP
node selfhost/scripts/package-backup.mjs
```

Hasil: `kasirgo-selfhost-backup-YYYY-MM-DD.zip`.

## 2. Restore di server baru

```bash
# Di server tujuan
unzip kasirgo-selfhost-backup-YYYY-MM-DD.zip
cd kasirgo-selfhost/installer
npm install
PORT=3000 npm start
```

Buka `http://domain-anda:3000` (atau proxy domain → port 3000), ikuti wizard:

1. **Database** — host, port, nama database, user, password → *Tes Koneksi*.
2. **API & Situs** — Supabase URL + anon key (otomatis terisi dari domain).
3. **Restore** — klik *Jalankan Restore*.
4. **Selesai** — buka aplikasi `/` dan admin `/admin/`.

## Isi paket

```
kasirgo-selfhost/
├── MANIFEST.json
├── database/           # 01-schema.sql, 02-data-public.sql, 03-data-auth.sql
├── app/
│   ├── web/            # build Flutter web
│   └── admin/          # build React admin
└── installer/          # server restore + wizard (Node/Express)
    ├── server.mjs
    ├── lib/ (restore.mjs, sql_split.mjs)
    └── public/ (index.html, app.css, app.js)
```

## Catatan teknis

- Aplikasi membaca `window.KASIRGO_CONFIG` (web) dan
  `window.__KASIRGO_ADMIN_CONFIG__` (admin) untuk menimpa `Supabase URL` dan anon
  key tanpa rebuild. Non-web (APK) tetap memakai nilai bawaan.
- Deep-link (QR Meja, katalog) sudah memakai `Uri.base.origin`, sehingga otomatis
  mengikuti domain baru.
- Hapus `state.json` (atau POST `/api/reset`) untuk kembali ke wizard.
- Kredensial database & anon key disimpan lokal di `state.json` pada server —
  amankan file ini (jangan publish ke repo; sudah di-`.gitignore`).