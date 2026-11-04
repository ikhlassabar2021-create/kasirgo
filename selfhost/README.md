# KasirGo — Backup & Reset Pasang (ala Duplicator WordPress)

Buat **paket backup ZIP** (database + aplikasi web + admin), lalu pulihkan di
tempat baru. Akun login ikut dipulihkan (hash password ikut ter-copy).

## Penting: backend KasirGo = PostgreSQL (Supabase), BUKAN MySQL

KasirGo memakai Supabase/PostgreSQL (`uuid`, `JSONB`, RLS, trigger, function
`plpgsql`). Ini **tidak bisa** dipindah ke MySQL, termasuk cPanel shared hosting
biasa (yang cuma punya **MySQL + PHP**).

Karena itu backup/restore dibagi **dua jalur**:

| Jalur | Target | Database | Aplikasi web + admin |
|-------|--------|----------|----------------------|
| **A. Restore penuh** | PostgreSQL (Supabase project / Neon / RDS / VPS) | Dipulihkan | Dipulihkan (serve Node) |
| **B. Deploy statis** | cPanel shared (MySQL+PHP) | **Tetap di Supabase** | Upload file statis |

- Jalur A butuh server yang bisa menjalankan **PostgreSQL + Node.js**.
- Jalur B butuh **cPanel apa pun** (cukup upload file); database tetap di Supabase.

## 1. Membuat paket backup (dipakai kedua jalur)

```bash
# a) Dump database (isi kredensial DB Postgres)
PGHOST=... PGPORT=5432 PGDATABASE=postgres PGUSER=... PGPASSWORD=... \
  bash selfhost/scripts/dump-database.sh

# b) Build aplikasi (web + admin)
cd kasirgo && flutter build web --release --base-href /
cd ../kasirgo-admin && npm run build
cd ..

# c) Bundel menjadi ZIP
node selfhost/scripts/package-backup.mjs
```

Hasil: `kasirgo-selfhost-backup-YYYY-MM-DD.zip`.

## 2A. Restore penuh ke target PostgreSQL

```bash
# Di server tujuan (harus ada Node.js >= 18 + akses PostgreSQL)
unzip kasirgo-selfhost-backup-YYYY-MM-DD.zip
cd kasirgo-selfhost/installer
npm install
PORT=3000 npm start
```

Buka `http://domain-anda:3000`, ikuti wizard:

1. **Database** — host, port, nama database, user, password → *Tes Koneksi*.
2. **API & Situs** — Supabase URL + anon key.
3. **Restore** — klik *Jalankan Restore*.
4. **Selesai** — buka aplikasi `/` dan admin `/admin/`.

Target PostgreSQL yang cocok: project **Supabase** baru (koneksi ke direct
connection string), **Neon**, **RDS**, atau **VPS PostgreSQL**.

## 2B. Deploy statis ke cPanel shared (MySQL + PHP)

Karena cPanel biasa tidak punya PostgreSQL, **database tetap di Supabase** — yang
di-deploy ke cPanel hanya file web + admin (statis, tidak butuh Node).

1. Ekstrak ZIP, ambil isi `app/web/` dan `app/admin/`.
2. Upload isi `app/web/*` ke `public_html/` dan isi `app/admin/*` ke
   `public_html/admin/` (File Manager cPanel atau FTP).
3. Selesai — tidak ada wizard. Frontend langsung menunjuk ke Supabase bawaan.

Bila ingin menunjuk ke **Supabase project lain** (mis. hasil restore), edit
`kasirgo-config.js` (ada di `app/web/kasirgo-config.js` dan
`app/admin/kasirgo-config.js`) lalu isi URL + anon key project tersebut:

```js
window.KASIRGO_CONFIG = {
  supabaseUrl: 'https://xxxx.supabase.co',
  supabaseAnonKey: 'ANON_KEY_ANDA',
};
window.__KASIRGO_ADMIN_CONFIG__ = window.KASIRGO_CONFIG;
```

Nilainya dibaca saat halaman dibuka (tanpa rebuild), jadi cukup ganti file itu.

> Catatan: database di cPanel tidak dipakai sama sekali pada jalur B. Restore
> database (SQL dari `database/`) tetap harus masuk ke PostgreSQL (Supabase),
> misalnya lewat Supabase SQL Editor atau `psql`.

## Isi paket

```
kasirgo-selfhost/
├── MANIFEST.json
├── database/           # 01-schema.sql, 02-data-public.sql, 03-data-auth.sql
├── app/
│   ├── web/            # build Flutter web (+ kasirgo-config.js)
│   └── admin/          # build React admin (+ kasirgo-config.js)
└── installer/          # server restore + wizard (Node/Express; jalur A)
    ├── server.mjs
    ├── lib/ (restore.mjs, sql_split.mjs)
    └── public/ (index.html, app.css, app.js)
```

## Catatan teknis

- Aplikasi membaca `window.KASIRGO_CONFIG` (web) dan
  `window.__KASIRGO_ADMIN_CONFIG__` (admin) untuk menimpa `Supabase URL` dan anon
  key tanpa rebuild. Non-web (APK) tetap memakai nilai bawaan.
- Sumber `kasirgo-config.js` ada di `kasirgo/web/kasirgo-config.js` dan
  `kasirgo-admin/public/kasirgo-config.js`, dimuat sebelum bundle masing-masing.
- Deep-link (QR Meja, katalog) sudah memakai `Uri.base.origin`, jadi otomatis
  mengikuti domain baru.
- Kredensial database & anon key pada jalur A disimpan lokal di `state.json`
  server — jangan publish (sudah di-`.gitignore`); `POST /api/reset` untuk reset.
- Dump memakai `--column-inserts --no-owner --no-acl` supaya portabel; penanda
  psql `\restrict`/`\unrestrict`/`\.` otomatis dibuang saat restore.