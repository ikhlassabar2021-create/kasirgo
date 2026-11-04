# Pindahkan KasirGo ke Hosting cPanel (Panduan Ringkas)

Panduan ini untuk **pemilik/bos** yang biasa pindah-pindah website WordPress
dengan Duplicator. KasirGo beda: aplikasinya bisa dipindah ke cPanel, tapi
**databasenya tetap di Supabase** (KasirGo pakai PostgreSQL, bukan MySQL).

Hasil akhirnya sama-sama "website jalan di domain sendiri", hanya saja database
tetap tinggal di Supabase, bukan di cPanel.

## Ringkasan

- **File aplikasi** (web + admin) → diupload ke cPanel, jalan seperti website biasa.
- **Database** → tetap di Supabase, tidak dipindah ke cPanel.

## Langkah

### 1. Siapkan file

Dua cara, pilih salah satu:

- **Ambil dari paket backup** — buka `kasirgo-selfhost-backup-XXXX.zip`, ada folder
  `app/web` dan `app/admin`.
- **Atau build sendiri** — `kasirgo` (`flutter build web`) dan `kasirgo-admin`
  (`npm run build`).

### 2. Upload ke cPanel

Pakai File Manager cPanel (atau FTP/FileZilla):

1. Buka `public_html`.
2. Upload **semua isi** folder `app/web` ke `public_html`.
3. Buat folder `admin` di dalam `public_html`.
4. Upload **semua isi** folder `app/admin` ke `public_html/admin`.

Selesai. Buka domain Anda, aplikasi langsung jalan (database otomatis terhubung
ke Supabase yang sudah dipakai).

### 3. Kalau mau ganti Supabase (opsional)

Hanya perlu kalau Anda restore ke Supabase project lain:

1. Buka file `kasirgo-config.js` di `public_html` dan di `public_html/admin`.
2. Ganti `supabaseUrl` dan `supabaseAnonKey` dengan project Supabase yang baru.
3. Simpan. Tidak perlu rebuild — nilainya dibaca saat halaman dibuka.

```js
window.KASIRGO_CONFIG = {
  supabaseUrl: 'https://xxxx.supabase.co',
  supabaseAnonKey: 'ANON_KEY_ANDA',
};
window.__KASIRGO_ADMIN_CONFIG__ = window.KASIRGO_CONFIG;
```

### 4. Pindahkan database ke Supabase lain (opsional)

Kalau Anda ingin memindahkan isi database ke Supabase project baru:

1. Ambil file `database/01-schema.sql`, `02-data-public.sql`, `03-data-auth.sql`
   dari paket backup.
2. Buka Supabase project baru → **SQL Editor**.
3. Jalankan ketiga file tersebut berurutan (mulai dari `01-...`).
4. Sesuaikan `kasirgo-config.js` (langkah 3) ke project baru tadi.

> Catatan: cara lain yang lebih cepat untuk database ialah menjalankan installer
> restore Node (lihat README jalur 2A) di komputer/server yang bisa menjalankan
> Node.js, bila tidak ingin memakai SQL Editor.

## Catatan penting

- Akun login/pegawai ikut ter-copy karena `auth.users` ikut di-dump.
- Jangan pernah upload file `state.json` ke cPanel (khusus jalur restore Node).
- Kalau domain berubah, semua link QR meja & katalog menyesuaikan otomatis.