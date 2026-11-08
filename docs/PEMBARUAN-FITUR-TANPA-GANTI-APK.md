# Update Fitur Tanpa Mengganti Aplikasi yang Sedang Berjalan

Cara menambah/mengubah fitur KasirGo tanpa memaksa semua pengguna meng-install
ulang APK, dan tanpa downtime. Empat jalur saling melengkapi — pilih berdasar
jenis perubahannya.

## Ringkasan

| Jenis perubahan | Jalur | Butuh rilis APK? |
|---|---|---|
| Ubah margin/integrasi/toggle fitur | A. Feature flag + Control Plane | Tidak |
| Fitur baru yang sudah ada kodenya (ship dark) | A. Feature flag | Tidak |
| UI/logic di **web & admin** | B. Deploy gh-pages (CI) | Tidak |
| Kode Dart di **APK** (kompilasi) | C. Play staged rollout + in-app update | Ya (bertahap) |
| Patch Dart cepat (tanpa review Play) | D. Shorebird code push | Tidak (patch) |

---

## A. Feature Flag (ship dark) + Control Plane

KasirGo sudah punya mekanisme rollout terpusat. Fitur baru boleh **ikut
ter-build ke APK tetapi default OFF**, lalu dinyalakan per outlet/segmen/tipe
tanpa rilis ulang.

### Skema (sudah ada di DB)

Tabel `public.feature_flags`:

- `key` — nama flag (untuk modul: `module_<nama>`).
- `enabled` — `false` = mati semuanya; `true` = nyala.
- `rollout_pct` — persen outlet yang dapat (hash stabil, 0–100).
- `outlet_types` — JSONB array tipe usaha (mis. `["cafe","restoran"]`).
- `segments` — JSONB array id segmen outlet.

RPC `feature_flags_for_outlet(p_outlet_id)` mengevaluasi flag efektif per outlet
(`enabled` + `rollout_pct` hash + `outlet_types` + `segments`), lalu di-override
oleh `outlet_module_overrides` (prioritas tertinggi per outlet).

Di app, flag modul dibaca oleh `ModuleRegistry.loadFlagsForOutlet()` dan fitur
syarat Pendukung dibaca oleh `SupporterService.hasFeature(outletId, key)`.

### Contoh: rilis fitur baru bertahap

```sql
-- 1) Fitur baru 'Sidak Stok Pro' kapal-gelap: kode sudah ada, default OFF.
INSERT INTO public.feature_flags (key, enabled, rollout_pct, outlet_types, segments)
VALUES ('sidak_stok_pro', false, 100, '[]'::jsonb, '[]'::jsonb)
ON CONFLICT (key) DO UPDATE SET updated_at = now();

-- 2) Buka 10% outlet (canary) — tanpa rilis APK.
UPDATE public.feature_flags
SET enabled = true, rollout_pct = 10
WHERE key = 'sidak_stok_pro';

-- 3) Batasi hanya tipe cafe jika perlu.
UPDATE public.feature_flags
SET outlet_types = '["cafe","restoran"]'::jsonb
WHERE key = 'sidak_stok_pro';

-- 4) Setelah stabil, buka 100%.
UPDATE public.feature_flags SET rollout_pct = 100 WHERE key = 'sidak_stok_pro';

-- 5) Nyalakan/padamkan khusus satu outlet (mis. beta tester).
INSERT INTO public.outlet_module_overrides (outlet_id, module_key, enabled)
VALUES ('<outlet-id>', 'module_sidak_stok_pro', true)
ON CONFLICT (outlet_id, module_key) DO UPDATE SET enabled = true;
```

Di kode, bungkus fitur dengan flag:

```dart
// Dart — contoh gate
final on = await SupporterService().hasFeature(outletId, 'sidak_stok_pro');
if (!on) return; // atau tampilkan dialog upgrade
```

Atau lewat UI gate yang sudah ada:

```dart
if (!await requireSupporterFeature(context, ref, 'sidak_stok_pro')) return;
```

### Integrasi/margin tanpa kode

Semua nilai integrasi/margin/monitor disimpan di `platform_integrations` +
`platform_configs`, di-cache app dengan fallback default. Ubah lewat tab
Control Plane superadmin (tanpa `git`/deploy).

---

## B. Web & Admin: deploy statis (instan)

- Flutter web + React admin di-deploy ke `gh-pages` oleh
  `.github/workflows/deploy-web.yml` (trigger: push ke `main` dengan path
  `kasirgo/**`, `kasirgo-admin/**`, atau `workflow_dispatch`).
- Pengguna cukup refresh browser; tidak ada proses install.
- `kasirgo-config.js` memuat `supabaseUrl` + `supabaseAnonKey` sehingga frontend
  bisa menunjuk ke project Supabase lain (mis. hasil restore) **tanpa rebuild**.

```bash
# Trigger manual (butuh token GitHub) atau cukup push ke main.
gh workflow run deploy-web.yml --ref main
```

Untuk cache service worker, minta pengguna hard refresh (`Ctrl+Shift+R`).

---

## C. APK Android: staged rollout + in-app update

Tidak perlu "ganti aplikasi" sekaligus; update bertahap:

1. Naikkan `version`/`build_number` di `pubspec.yaml` (semantic version).
2. Push tag `v*` → `.github/workflows/release-apk.yml` build APK/AAB bertanda
   tangan (secret: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
   `KEY_PASSWORD`).
3. Di **Play Console**, pakai **staged rollout**: 10% → pantau crash report →
   50% → 100%. Pengguna lama tetap memakai versi berjalan sampai punya giliran.
4. **In-App Update** (`in_app_update`): versi lama menampilkan prompt "Update
   tersedia" tanpa keluar aplikasi.
5. SQLite (drift) memigrasi data lokal otomatis via `schemaVersion`, sehingga
   data pengguna aman saat versi naik.

> Versi lama tetap harus kompatibel dengan DB baru: gunakan migration aditif
> (lihat di bawah).

---

## D. Shorebird code push (opsional, patch Dart instan)

Untuk perbaikan/patch murni Dart tanpa menunggu review Play Store:

- `shorebird init` + `shorebird release` untuk rilis awal, lalu
  `shorebird patch` untuk patch berikutnya.
- Hanya Dart, TIDAK untuk native code / asset / perubahan `pubspec` native.
- Kombinasikan: fitur besar → Play staged rollout; hotfix Dart → Shorebird.

---

## Aturan DB agar rollout aman (backward compatible)

Semua migration di `docs/migrations/*.sql` harus idempoten & aditif:

- `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`,
  `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`.
- Jangan `DROP`, `RENAME`, atau mengubah tipe kolom yang dipakai versi lama.
- Kolom baru wajib `DEFAULT` aman / `NULL`, sehingga versi app lama tetap jalan.

Checklist fitur baru:

1. [ ] Kode fitur masuk, default OFF (bila masih eksperimental).
2. [ ] Migration DB aditif + idempoten diterapkan sebelum deploy apa pun.
3. [ ] Flag `feature_flags`/`module_*` disiapkan (rollout 0%).
4. [ ] Web/admin di-deploy (instan), APK di-build (bertahap).
5. [ ] Pantau metrik/error; naikkan `rollout_pct` bertahap hingga 100%.
6. [ ] Setelah stabil penuh, bersihkan cabang flag usang.