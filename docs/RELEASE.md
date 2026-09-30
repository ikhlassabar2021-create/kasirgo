# Panduan Rilis APK KasirGo (Phase 12 / ST12-3)

## Build APK rilis

### Via CI (disarankan)
1. Push tag: `git tag v1.0.0 && git push origin v1.0.0`
2. GitHub Actions workflow `.github/workflows/release-apk.yml` otomatis build:
   `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info`
3. Unduh artifact `apk-release` dari tab Actions (3 APK: arm64-v8a,
   armeabi-v7a, x86_64 + simbol debug untuk re-obfuscate stack trace).
4. Distribusikan APK `arm64-v8a` ke mayoritas HP (target tiap APK < 10MB).

### Via mesin lokal
```bash
cd kasirgo
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info
```

## WAJIB sebelum publish ke Play Store
1. **Keystore rilis sendiri** (jangan debug key). Buat:
   ```bash
   keytool -genkey -v -keystore ~/kasirgo-release.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias kasirgo
   ```
   Isi `android/key.properties` (storeFile, storePassword, keyAlias,
   keyPassword) dan ubah `build.gradle.kts` release `signingConfig`.
   Ganti `signingConfig = signingConfigs.getByName("debug")` di buildTypes
   release dengan keystore tersebut. SIMPAN keystore + password dengan aman
   (hilang = tidak bisa update app).
2. **Jalankan migrasi SQL** di Supabase SQL Editor (urut):
   - `docs/migrations/2026-10-01-kasirgo-11.sql` (Phase 11, jalankan ulang)
   - `docs/migrations/2026-10-02-kasirgo-12-security.sql` (hardening ST12-1)
3. Rotasi password akun GitHub/Supabase + PAT lama (housekeeping).

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
