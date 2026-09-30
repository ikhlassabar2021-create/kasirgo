# PROGRESS PHASE 12 — Polish + Security Audit + Release

## SELESAI (Phase 12 selesai — aplikasi siap rilis)

### ST12-3 — Build Web + Deploy + APK CI (2026-10-02)
- `flutter build web --release --base-href /kasirgo/` OK.
- `npm run build` admin OK (1.1MB js / 296KB gzip — catatan: saran code-split
  untuk fase lanjut).
- Deploy gh-pages: app root + admin di /kasirgo/admin/ (commit `0edef08`).
  Smoke test: https://ikhlassabar2021-create.github.io/kasirgo/ (200) dan
  /kasirgo/admin/ (200), main.dart.js + chunk admin terlayani.
- APK rilis TIDAK dibangun di sandbox (sesuai aturan): workflow CI
  `.github/workflows/release-apk.yml` (picu via tag v* atau manual) build
  `--split-per-abi --obfuscate --split-debug-info`. Panduan lengkap:
  `docs/RELEASE.md` (termasuk WAJIB keystore rilis + urutan migrasi SQL +
  checklist E2E manual per role/offline/Program Pendukung).

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
- ST12-3: web build + deploy gh-pages, dokumen APK CI, E2E, Phase 12 SELESAI.

## ST12-2 — Stress Test Sync Offline<->Online (2026-10-02)

### Temuan stress test (serius)
1. **BUG DATA-LOSS (fix):** resolver stok di Isolate menggabungkan delta stok
   dan menaruh hasilnya di AKHIR list, sehingga indeks `preparedQueue`
   TIDAK sejajar dengan antrean mentah — padahal penghapusan antrean pakai
   indeks mentah. Sync parsial (beberapa item gagal) => **item salah
   terhapus**. Fix: resolver kini menjaga posisi (agregat di posisi
   kemunculan pertama, duplikat jadi null) + `removeMany` atomik.
2. **PIPELINE OFFLINE TIDAK PERNAH DI-WIRE (fix):** `queueOperation`/
   `queueSyncEvent` tidak pernah dipanggil siapa pun; `getUnsynced*` SQLite
   tidak pernah dibaca; checkout POS hanya memanggil Supabase langsung —
   transaksi offline HILANG. Fix (wiring end-to-end):
   - Checkout offline -> `OfflineTransactionService.saveOfflineCheckout`:
     transaksi (event_id, pending) + kurangi stok lokal + stock_logs ke
     SQLite. Snackbar "Disimpan offline".
   - `SyncService.syncQueue` kini mendorong baris lokal unsynced:
     transaksi (upsert onConflict id) + transaction_items (id DETERMINISTIK
     via IdGen.deterministic -> retry aman, trigger decrement_stock hanya
     jalan sekali) + kasbon + stock_logs (event_id UNIQUE) + PPOB.
   - Katalog offline: productsProvider cache SQLite (batchInsertProducts
     saat online; baca cache saat offline).
3. **O(n^2) + race di OfflineQueue (fix):** setiap add/remove decode+encode
   seluruh antrean tanpa lock; remove satu-per-satu saat sync (n tulis
   penuh). Fix: lock serial + cache memori + removeMany satu tulis.
4. **Retry habis = data dibuang diam-diam (fix):** kini masuk dead-letter
   (`offline_sync_dead_letter`) untuk inspeksi/replay.
5. **Dedupe event_id** saat menyiapkan batch (re-queue setelah crash tidak
   dobel). Delta stok server tidak pernah dikirim manual dari penjualan
   offline — trigger `decrement_stock` server-side yang mengurangi, jadi
   tidak ada deincrement ganda.

### Verifikasi
- `test/sync_stress_test.dart`: 10/10 PASS —
  300 add konkurensi + removeMany tanpa kehilangan; race add/remove lock;
  dead-letter; persist antar-restart; agregasi delta + LWW; idempotency
  resolver; dedupe event_id; beban 5000 event <1s; IdGen uuidV4 unik;
  deterministic id stabil.
- `flutter analyze`: 21 isu = baseline (0 baru).

### Catatan
- Tip/split payment offline belum tersimpan lokal (best-effort online saja);
  dicatat sebagai keterbatasan, tidak memblokir rilis.

## LANGKAH RILIS (untuk user)
1. Jalankan di SQL Editor: `2026-10-01-kasirgo-11.sql` (ulang) lalu
   `2026-10-02-kasirgo-12-security.sql`.
2. QA manual checklist di `docs/RELEASE.md`.
3. Buat keystore + `git tag v1.0.0 && git push origin v1.0.0` -> CI build APK.
