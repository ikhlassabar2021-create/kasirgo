-- KasirGo: rilis Android 1.0.11 (fix deteksi ABI + helper KTP + bypass QA + web cadangan).
-- 1. Normalkan build_number 1.0.10 (sebelumnya salah 2011 -> 11).
-- 2. Tambah rilis 1.0.11 (build 12) dengan URL APK signed GitHub Release.
-- Idempotent.

UPDATE public.app_releases
SET build_number = 11
WHERE platform = 'android' AND version = '1.0.10' AND build_number <> 11;

INSERT INTO public.app_releases
  (platform, version, build_number, files, changelog, is_published, force_update, published_at, created_at)
SELECT
  'android', '1.0.11', 12,
  '{
    "arm64": "https://github.com/ikhlassabar2021-create/kasirgo/releases/download/v1.0.11-signed-20261103/kasirgo-1.0.11-arm64-v8a.apk",
    "armeabi_v7a": "https://github.com/ikhlassabar2021-create/kasirgo/releases/download/v1.0.11-signed-20261103/kasirgo-1.0.11-armeabi-v7a.apk",
    "x86_64": "https://github.com/ikhlassabar2021-create/kasirgo/releases/download/v1.0.11-signed-20261103/kasirgo-1.0.11-x86_64.apk"
  }'::jsonb,
  'Rilis 1.0.11: deteksi ABI Android, helper nama sesuai KTP, bypass akun uji, web hanya cadangan.',
  true, false, now(), now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.app_releases WHERE platform = 'android' AND version = '1.0.11'
);