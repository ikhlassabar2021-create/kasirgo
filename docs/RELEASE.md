# Panduan Rilis APK KasirGo (Phase 12 / ST12-3)

## Build APK rilis

### Via CI (disarankan)
1. Push tag: `git tag v1.0.2 && git push origin v1.0.2`
2. GitHub Actions workflow `.github/workflows/release-apk.yml` otomatis build
   APK + AAB bertanda tangan:
   `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info`
3. Unduh artifact `apk-release` (3 APK: arm64-v8a, armeabi-v7a, x86_64 +
   `checksums.txt` SHA-256 + simbol debug) dan `aab-release` (Play Store).
4. Distribusikan APK `arm64-v8a` ke mayoritas HP. Ukuran unduhan ~29 MB
   (fitur lengkap: ML Kit OCR/face/barcode).

### Ukuran APK (< 50 MB)
`android/app/build.gradle.kts` memakai `packaging { jniLibs { useLegacyPackaging = true } }`
sehingga `lib*.so` disimpan TERKOMPRES di dalam APK. Hasil (v1.0.3):

| ABI | Sebelum | Sesudah |
|---|---|---|
| arm64-v8a | 58,4 MB | 29,9 MB |
| armeabi-v7a | 47,4 MB | 27,9 MB |
| x86_64 | 60,1 MB | 30,9 MB |

Android mengekstrak library saat instalasi (butuh ~60 MB ruang kosong saat
install, setelah itu kembali). Tidak ada fitur yang dipangkas.

### Via mesin lokal
```bash
cd kasirgo
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info
```

## Signing rilis (WAJIB - jangan pakai debug key)

Keystore rilis KasirGo sudah dibuat: PKCS12, alias `kasirgo`, RSA 2048,
valid 10.000 hari (s.d. 2054). File TIDAK disimpan di repo; backup segera
ke tempat aman (kehilangan keystore = tidak bisa update app di Play Store).

Sertifikat (untuk verifikasi Play Console / APK):
- SHA-1   : `A6:17:30:2D:91:C6:A0:9C:F3:22:14:73:2B:6C:51:42:3A:41:4C:28`
- SHA-256 : `FE:D1:42:4C:12:56:9D:83:89:CC:4F:E0:01:2C:6E:A1:B3:3C:FD:F9:E2:35:7D:0F:E3:02:3E:29:E7:E6:F5:2F`

### GitHub Secrets (dipakai CI)
| Secret | Isi |
|---|---|
| `KEYSTORE_BASE64` | hasil `base64 -w0 kasirgo-upload.p12` |
| `KEYSTORE_PASSWORD` | password keystore (catat di tempat aman) |
| `KEY_ALIAS` | `kasirgo` |
| `KEY_PASSWORD` | sama dengan password keystore |

Bila keempat secret BELUM diisi, langkah "Siapkan keystore rilis" gagal
(disengaja: APK debug tidak boleh lolos sebagai rilis). Untuk build darurat
tanpa secret, dispatch workflow dengan input `debug_sign_fallback=true`, lalu
tanda tangani ulang APK/AAB secara lokal (lihat bawah).

### Tanda tangan ulang lokal (bila CI memakai debug_sign_fallback)
```bash
# APK: zipalign lalu apksigner (build-tools Android)
zipalign -p -f 4 app-arm64-v8a-release.apk aligned.apk
apksigner sign --ks kasirgo-upload.p12 --ks-type PKCS12 --ks-key-alias kasirgo \
  --out kasirgo-1.0.2-arm64-v8a.apk aligned.apk
apksigner verify --print-certs kasirgo-1.0.2-arm64-v8a.apk

# AAB: buang META-INF tanda tangan lama, lalu jarsigner
jarsigner -keystore kasirgo-upload.p12 -storetype PKCS12 \
  -sigalg SHA256withRSA -digestalg SHA-256 kasirgo-1.0.2.aab kasirgo
keytool -printcert -jarfile kasirgo-1.0.2.aab
```

### Build lokal dengan keystore
```bash
cd kasirgo
# buat android/key.properties berisi storeFile, storePassword, keyAlias, keyPassword
# salin keystore ke android/app/kasirgo-release.p12
flutter build apk --release --split-per-abi
```
`android/key.properties` + `*.p12`/`*.jks`/`*.keystore` sudah masuk `.gitignore`.

CATATAN: bila `key.properties` tidak ada, build otomatis memakai debug key
(hanya untuk uji lokal). APK debug-signed TIDAK boleh didistribusikan.

## Rilis 1.0.3 (23 Okt 2026) - APK < 50 MB

- Versi `1.0.3+4`; APK dikompres (`useLegacyPackaging`) -> arm64 29,9 MB,
  armeabi-v7a 27,9 MB, x86_64 30,9 MB. Ditandatangani keystore rilis (v1+v2+v3).
- Unduhan publik (GitHub Pages, tanpa login):
  - https://ikhlassabar2021-create.github.io/kasirgo/apk/kasirgo-1.0.3-arm64-v8a.apk
  - https://ikhlassabar2021-create.github.io/kasirgo/apk/kasirgo-1.0.3-armeabi-v7a.apk
- Build: `workflow_dispatch` (`debug_sign_fallback=true`) -> artifact `apk-release`
  -> `zipalign -p -f 4` + `apksigner sign` lokal dengan `kasirgo-upload.p12`.
- CATATAN: token GitHub App di sandbox tidak punya izin `contents:write` untuk
  membuat Release/upload aset (401/403), sehingga APK dipublikasikan lewat
  branch `gh-pages` folder `apk/`.

## Rilis 1.0.2 (18 Okt 2026) - release-signed

- Tag/Release: `v1.0.2-signed-20261018`
  (https://github.com/ikhlassabar2021-create/kasirgo/releases/tag/v1.0.2-signed-20261018)
- Aset: `kasirgo-1.0.2-arm64-v8a.apk` (58,4 MB), `armeabi-v7a.apk` (47,4 MB),
  `x86_64.apk` (63,0 MB), `kasirgo-1.0.2.aab` (106,3 MB), `SHA256SUMS.txt`.
- APK ditandatangani v1+v2+v3, sudah `zipalign`; AAB ditandatangani upload key
  (v1). Sertifikat terverifikasi = SHA-1/SHA-256 di atas.
- Token CI yang tersedia (GitHub App installation) TIDAK bisa menulis
  `actions/secrets` (403), jadi build memakai `debug_sign_fallback=true` lalu
  ditandatangani ulang lokal. Isi 4 secret di atas agar build berikutnya
  langsung release-signed dari CI.
- Sisa langkah manusia: backup `kasirgo-upload.p12` + password ke tempat aman
  (kehilangan = tidak bisa update app).

## Play Store (AAB)
CI juga membangun `app-release.aab` (artifact `aab-release`).
Checklist Play Console:
- [ ] App signing: unggah AAB; simpan upload key (jangan hilang).
- [ ] Privacy policy URL (wajib) + kebijakan retensi data.
- [ ] Data safety: kamera (scan barcode/KTP), lokasi (radar outlet), notifikasi,
      foto (bukti transfer), kontak/WA (opsional).
- [ ] Content rating + target audiens (bukan anak-anak).
- [ ] Izin Android (CAMERA, ACCESS_FINE_LOCATION, POST_NOTIFICATIONS, INTERNET)
      dijelaskan di listing.
- [ ] Screenshot + ikon 512px + feature graphic 1024x500.
- [ ] Uji internal testing track sebelum produksi.

## Catatan keamanan data lokal
Database lokal (`kasirgo_local.db`) saat ini SQLite biasa di dalam sandbox app
(`PRAGMA key` no-op karena `sqlcipher_flutter_libs` dilepas agar build Android
tidak bentrok). Untuk enkripsi at-rest: ganti `sqlite3_flutter_libs` ->
`sqlcipher_flutter_libs` + `openCipherOnAndroid` + migrasi DB lama (belum
dilakukan; butuh rencana migrasi data pengguna).

## Migrasi database Supabase (bila project baru)
Jalankan migrasi di `docs/migrations/` berurutan di Supabase SQL Editor.

## Deploy web (sudah otomatis lewat repo)
- App: salin `kasirgo/build/web` (dengan `--base-href /kasirgo/`) ke gh-pages root.
- Admin: `npm run build` di kasirgo-admin, salin `dist/` ke gh-pages `/admin/`.

## E2E manual checklist (buat rilis)
- [ ] Owner: login, produk, POS jual, laporan, pelanggan, karyawan
- [ ] Admin: produk (tanpa hapus), laporan
- [ ] Cashier: POS, QRIS manual
- [ ] Customer: scan QR meja -> order
- [ ] Offline: matikan internet -> jual -> "Disimpan offline" -> nyalakan ->
      transaksi masuk (cek Supabase, stok berkurang SEKALI)
- [ ] Program Pendukung: aktivasi Rp50rb/bln, iklan di sisi pelanggan
