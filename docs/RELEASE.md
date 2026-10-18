# Panduan Rilis APK KasirGo (Phase 12 / ST12-3)

## Build APK rilis

### Via CI (disarankan)
1. Push tag: `git tag v1.0.2 && git push origin v1.0.2`
2. GitHub Actions workflow `.github/workflows/release-apk.yml` otomatis build
   APK + AAB bertanda tangan:
   `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info`
3. Unduh artifact `apk-release` (3 APK: arm64-v8a, armeabi-v7a, x86_64 +
   `checksums.txt` SHA-256 + simbol debug) dan `aab-release` (Play Store).
4. Distribusikan APK `arm64-v8a` ke mayoritas HP. Ukuran realistis ~58 MB
   (fitur lengkap: ML Kit OCR/face/barcode). Target <10 MB tidak mungkin.

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
