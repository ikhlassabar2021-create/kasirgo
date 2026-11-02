-- KasirGo: Seed rilis Android 1.0.10 agar tombol unduh APK di gate web->APK berfungsi.
-- APK dihosting di GitHub Releases (release v1.0.10-signed-20261102), bukan R2/gh-pages.
-- Idempotent: hanya insert bila belum ada rilis android sama sekali; superadmin bisa
-- menimpa URL lewat Control Plane > Update Aplikasi (kolom files per ABI).

INSERT INTO public.app_releases
  (platform, version, build_number, files, changelog, is_published, force_update, published_at, created_at)
SELECT
  'android', '1.0.10', 2011, v.files, 'Rilis 1.0.10 (gate web->APK)', true, false, now(), now()
FROM (VALUES (
  '{
    "arm64": "https://github.com/ikhlassabar2021-create/kasirgo/releases/download/v1.0.10-signed-20261102/kasirgo-1.0.10-arm64-v8a.apk",
    "armeabi_v7a": "https://github.com/ikhlassabar2021-create/kasirgo/releases/download/v1.0.10-signed-20261102/kasirgo-1.0.10-armeabi-v7a.apk",
    "x86_64": "https://github.com/ikhlassabar2021-create/kasirgo/releases/download/v1.0.10-signed-20261102/kasirgo-1.0.10-x86_64.apk"
  }'::jsonb
)::jsonb) AS v(files)
WHERE NOT EXISTS (
  SELECT 1 FROM public.app_releases WHERE platform = 'android' AND version = '1.0.10'
);