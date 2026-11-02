-- KasirGo: Update Aplikasi per-ABI (arm64 / armeabi-v7a / x86_64).
--
-- Alur baru (lepas Cloudflare R2, simpan di gh-pages /updates/ dengan link domain):
--   1. release-apk.yml membangun APK split-per-abi lalu mempublikasikan 3 file
--      stabil ke gh-pages: kasirgo-arm64.apk, kasirgo-armeabi-v7a.apk,
--      kasirgo-x86_64.apk (file lama tertimpa, tidak menumpuk).
--   2. Superadmin (Control Plane > Update Aplikasi) mengisi maps `files`
--      {arm64: url, armeabi_v7a: url, x86_64: url} lalu Terbitkan.
--   3. App (klien) membaca files lalu memilih URL sesuai ABI perangkat
--      (dart:io Abi.current()) -> download APK yang tepat.
--
-- Kolom lama (file_url, file_key, guide_key, file_size, sha256) tidak lagi
-- dipakai; dibiarkan untuk kompatibilitas.

-- ============================================================
-- 1. Kolom JSONB untuk maps URL per ABI
-- ============================================================
ALTER TABLE public.app_releases ADD COLUMN IF NOT EXISTS files jsonb;

-- ============================================================
-- 2. RPC klien: baca rilis terbaru + files
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_latest_app_release(p_platform text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r public.app_releases%ROWTYPE;
BEGIN
  SELECT * INTO r FROM public.app_releases
  WHERE platform = p_platform AND is_published = true
  ORDER BY build_number DESC, created_at DESC
  LIMIT 1;
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN jsonb_build_object(
    'id', r.id, 'platform', r.platform, 'version', r.version,
    'build_number', r.build_number, 'files', COALESCE(r.files, '{}'::jsonb),
    'guide_url', r.guide_url, 'changelog', r.changelog,
    'force_update', r.force_update, 'published_at', r.published_at
  );
END $$;
GRANT EXECUTE ON FUNCTION public.get_latest_app_release(text) TO anon, authenticated;

-- ============================================================
-- 3. RPC superadmin: daftar rilis
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_list_app_releases()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  RETURN COALESCE(
    (SELECT jsonb_agg(row_to_json(t) ORDER BY t.created_at DESC)
     FROM (SELECT id, platform, version, build_number, files, guide_url, changelog,
                  is_published, force_update, published_at, created_at
           FROM public.app_releases) t),
    '[]'::jsonb
  );
END $$;
GRANT EXECUTE ON FUNCTION public.admin_list_app_releases() TO authenticated;

-- ============================================================
-- 4. RPC superadmin: simpan rilis (upsert berdasar platform+version)
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_save_app_release(p_release jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_platform text := nullif(btrim(coalesce(p_release->>'platform','')),'');
  v_version  text := nullif(btrim(coalesce(p_release->>'version','')),'');
  v_files    jsonb := CASE WHEN p_release ? 'files' AND jsonb_typeof(p_release->'files') = 'object'
                           THEN p_release->'files' ELSE NULL END;
  v_guide    text := nullif(btrim(coalesce(p_release->>'guide_url','')),'');
  rec record; v_id uuid;
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  IF v_platform IS NULL OR v_version IS NULL THEN
    RETURN jsonb_build_object('error', 'platform dan version wajib diisi');
  END IF;

  SELECT id INTO v_id FROM public.app_releases
  WHERE platform = v_platform AND version = v_version
  ORDER BY created_at DESC LIMIT 1;

  IF v_id IS NULL THEN
    INSERT INTO public.app_releases
      (platform, version, build_number, files, guide_url, changelog, is_published, force_update, created_by)
    VALUES
      (v_platform, v_version, COALESCE((p_release->>'build_number')::int, 0),
       v_files, v_guide, coalesce(p_release->>'changelog',''),
       COALESCE((p_release->>'is_published')::boolean, false),
       COALESCE((p_release->>'force_update')::boolean, false),
       auth.uid())
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.app_releases SET
      build_number = COALESCE((p_release->>'build_number')::int, build_number),
      files        = COALESCE(v_files, files),
      guide_url    = COALESCE(v_guide, guide_url),
      changelog    = COALESCE(p_release->>'changelog', changelog),
      force_update = COALESCE((p_release->>'force_update')::boolean, force_update)
    WHERE id = v_id;
  END IF;

  RETURN public.admin_list_app_releases();
END $$;
GRANT EXECUTE ON FUNCTION public.admin_save_app_release(jsonb) TO authenticated;