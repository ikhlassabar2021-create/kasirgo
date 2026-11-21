-- ============================================================================
-- KasirGo -- Rilis Android 1.0.18 (build 19)
-- Tanggal: 2026-11-21
-- APK split-per-ABI di gh-pages /updates/ (domain dokterbisnis.web.id).
-- Idempotent: update bila versi sudah ada, insert bila belum.
-- ============================================================================

DO $$
DECLARE
  v_id uuid;
  v_files jsonb := '{
    "arm64": "https://dokterbisnis.web.id/updates/kasirgo-arm64.apk",
    "armeabi_v7a": "https://dokterbisnis.web.id/updates/kasirgo-armeabi-v7a.apk",
    "x86_64": "https://dokterbisnis.web.id/updates/kasirgo-x86_64.apk"
  }'::jsonb;
  v_url text := 'https://dokterbisnis.web.id/updates/kasirgo-arm64.apk';
  v_changelog text := 'Rilis 1.0.18: tutup shift kasir lintas pengguna outlet, kode referral otomatis dari link, dan pembayaran/penjadwalan closing afiliasi oleh superadmin.';
BEGIN
  SELECT id INTO v_id
  FROM public.app_releases
  WHERE platform = 'android' AND version = '1.0.18'
  LIMIT 1;

  IF v_id IS NULL THEN
    INSERT INTO public.app_releases (
      platform, version, build_number,
      file_url, files, changelog,
      is_published, force_update, published_at, created_at
    ) VALUES (
      'android', '1.0.18', 19,
      v_url, v_files, v_changelog,
      true, false, now(), now()
    );
  ELSE
    UPDATE public.app_releases
    SET build_number = 19,
        file_url = v_url,
        files = v_files,
        changelog = v_changelog,
        is_published = true,
        force_update = false,
        published_at = now()
    WHERE id = v_id;
  END IF;
END $$;
