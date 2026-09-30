# Progress Phase 13 — Superadmin Web & Control Plane

Tujuan: menyederhanakan Superadmin React menjadi tiga halaman inti
(Laporan Utama, Outlet Terdaftar, Fitur Utama) dan menjadikan Control Plane
sebagai satu-satunya tempat mengatur integrasi (Payment Gateway, PPOB,
B2B Kulakan, Modal Usaha) tanpa ubah koding.

## ST13-1 — Superadmin: Laporan Utama, Outlet, Fitur
Status: SELESAI (commit `ba6cf28`)

- Nav baru: `Laporan Utama` (`/superadmin`), `Outlet Terdaftar` (`/outlets`),
  `Fitur Utama` (`/features`), Affiliates, Control Plane. Halaman lama
  (Revenue/Audit/Intelligence/Users/OwnerDashboard) dialihkan (redirect).
- `MainReport.tsx`: rekap paket + Pendukung (MRR/revenue), PPOB, Payment
  Gateway untuk 7/30/90 hari.
- `Outlets.tsx`: tabel outlet + filter KYC/paket + paginasi (default KYC verified).
- `OutletDetail.tsx`: verifikasi KYC, ubah paket, toggle modul, laporan per
  outlet, kelola staf (hapus), backup/restore/jadwal, hapus akun (zona bahaya).
- `Features.tsx` + `FeatureToggleList.tsx`: toggle `module_<nama>` per outlet.
- `lib/adminApi.ts`: tipe + helper `platformOutletsList`, `platformSetVerification`,
  `platformSetPlan`, `platformOutletFeatures`, `platformOutletSetFeature`,
  `platformOutletStaff`, `platformOutletRemoveStaff`, `platformOutletDeleteAccount`,
  `platformOutletReport`, `platformMainReport`.
- Migrasi `docs/migrations/2026-10-03-kasirgo-13-admin.sql`: tabel
  `outlet_module_overrides` + `feature_flags_for_outlet` (override menang) +
  RPC `platform_*`.

## ST13-2 — Control Plane: Iklan, Payment Gateway, PPOB, B2B, Modal Usaha
Status: SELESAI (batch ini)

Tab Control Plane lama `Financial`/`Integrasi & Secret` diganti:

- **Iklan**: kreatif per-item (nama iklan editable, judul, subjudul, CTA,
  URL Tujuan, Kode HTML, Kode Script, Kategori). Banner gambar/video
  di-upload dan **disimpan LOKAL** (base64 embedded di config, bukan storage).
  `provider`/`adsterra_key`/`sponsor_local` dihapus.
- **Payment Gateway**: margin/fee existing + kredensial di
  `platform_integrations('payment_gateway')` — API Key, Server Key, Secret,
  Client Key, Public Key, Merchant ID, Callback/Webhook URL, Script/SDK Library.
- **PPOB** (tab baru): provider, margin %, endpoint, callback URL, IP whitelist,
  kode produk di `platform_configs('ppob')`; kredensial (API Key/Secret/Token)
  di `platform_integrations('ppob')`.
- **B2B Kulakan**: link distributor, komisi, domain diizinkan + Kode HTML/Script
  + URL Tujuan (`platform_configs('b2b_restock')`).
- **Modal Usaha**: mitra, link pengajuan, WA + Kode HTML/Script + URL Tujuan
  (`platform_configs('fintech_partner')`).

Klien (Flutter):
- `ad_service.dart`: `SponsorAd` baca `image_base64`/`image_mime` (data URI),
  `html_code`/`script_code`/`target_url`; `AdDecision` tanpa `provider`.
- `sponsor_ad_slot.dart`: render banner lokal (`ad.imageSrc`) maupun URL.
- `supporter_service.dart`: `fallbackAds` baru (creatives).
- `test/ad_service_test.dart`: 5 test parsing/pemfilteran kreatif.

Migrasi: `docs/migrations/2026-10-04-kasirgo-13-control-plane.sql`
(integrasi kanonik `payment_gateway` + `ppob`, field PPOB baru, bersihkan key
iklan lama, siapkan field embed B2B/Modal Usaha). Idempotent.

## Verifikasi
- `npx tsc -b` (admin) PASS; `vite build` sukses.
- `flutter analyze`: 21 issues (baseline, 0 baru).
- `flutter test`: 7 gagal = baseline pra-ada (POS/Phase5), tidak terkait.
  `test/ad_service_test.dart`: 5/5 PASS.

## Migrasi (SUDAH DITERAPKAN ke Supabase produksi)
- `2026-10-01-kasirgo-11.sql` — sudah ada (dikonfirmasi).
- `2026-10-02-kasirgo-12-security.sql` — sudah ada (dikonfirmasi; `ppob` tanpa `api_key`).
- `2026-10-03-kasirgo-13-admin.sql` — DITERAPKAN. `outlet_module_overrides` + 11 RPC
  `platform_*`/`feature_flags_for_outlet`. Diuji end-to-end via PostgREST sebagai
  superadmin (main_report, outlets_list, features, staff, report, set_feature).
- `2026-10-04-kasirgo-13-control-plane.sql` — DITERAPKAN. Integrasi kanonik
  `payment_gateway` + `ppob`; field PPOB baru; `creatives` iklan; field embed
  B2B/Modal Usaha.

Catatan keamanan: migrasi 2026-10-04 versi awal tidak sengaja membuat ulang policy
`Client read active integrations` yang sudah dihapus Phase 12 (bocor `secret_config`).
Sudah diperbaiki: policy DIBUANG dari file & DB. Verifikasi: sebagai `anon`,
`select from platform_integrations` = 0 baris; akses klien hanya lewat view
`platform_integrations_public` (tanpa `secret_config`).