# PROGRESS PHASE 12 — Polish + Security Audit + Release

## SELESAI

### ST12-1 — Security Audit + Hardening (2026-10-02)
**Audit (grep + review statik):**
- `service_role` TIDAK ada di APK/repo (hanya anon key yang memang publik;
  service key hanya untuk Edge Function/service-side). PASS.
- `flutter_secure_storage` SUDAH terpasang: session Supabase disimpan via
  `SecureLocalStorage` (supabase_config.dart), bukan SharedPreferences. PASS.
- `proguard-rules.pro` ada. Isu: release block belum mengaktifkan minify.
- Izin Android: hanya RECEIVE_BOOT_COMPLETED (notifikasi terjadwal).
  **BUG KRITIKAL DITEMUKAN**: permission INTERNET hanya ada di manifest
  debug/profile -> APK release tidak bisa akses jaringan sama sekali.
- **Bocor secret ditemukan (kritikal)**:
  1) Policy `"Client read active integrations"` di `platform_integrations`
     memperbolehkan client SELECT seluruh baris aktif, TERMASUK
     `secret_config` (api_key payment gateway, WA bisnis, dll).
  2) `platform_configs` key 'ppob' memuat `api_key` di value, dan tabel
     ini bisa dibaca semua client (`USING (true)`), lalu di-cache plaintext
     di SharedPreferences oleh PpobService.
- RLS final: owner/admin/cashier tercakup; **kitchen TIDAK** (role ditambah
  di Phase 3.0 tapi policy SELECT tidak diperbarui -> KDS kosong untuk staf
  dapur). Customer aman: semua akses via RPC publik SECURITY DEFINER
  (get_public_menu, get_public_outlet, get_public_ad_state,
  get_public_outlet_payment) tanpa akses tabel langsung.

**Perbaikan:**
- Migrasi `docs/migrations/2026-10-02-kasirgo-12-security.sql` (idempotent,
  **perlu dijalankan di SQL Editor**):
  - Hapus policy client di `platform_integrations`; view
    `platform_integrations_public` dibuat security DEFINER (kolom aman
    saja, tanpa secret_config).
  - Strip `api_key`/`secret`/`password`/`token` dari semua value
    `platform_configs` (aturan: config = nilai non-secret; secret hanya di
    platform_integrations.secret_config yang dibaca Edge Function).
  - Policy SELECT outlets/products/transactions/transaction_items/
    product_prices diperbarui menyertakan role `kitchen`.
- `android/app/src/main/AndroidManifest.xml`: + permission INTERNET.
- `android/app/build.gradle.kts`: release `isMinifyEnabled` +
  `isShrinkResources` + proguard-android-optimize + proguard-rules.pro
  (obfuscate Dart tetap via flag `--obfuscate --split-debug-info`).
- `ppob_service.dart`: berhenti menyimpan `api_key` ke cache prefs; dokumen
  integrasi provider nyata = via Edge Function (bukan dari APK).
- `flutter analyze` file terubah: bersih.

**Catatan keamanan sisa (tidak diblok rilis):**
- release APK masih pakai debug signing key -> wajib keystore rilis sendiri
  sebelum publish ke Play Store (doc di ST12-3).
- PAT GitHub / password akun: sudah transient; rotasi password & PAT lama
  disarankan (housekeeping user).

## BERIKUTNYA
- ST12-2: stress test sync offline<->online (Isolate, LWW, idempotent
  event_id), uji beban stok/antrean/memori, perbaiki bottleneck.
