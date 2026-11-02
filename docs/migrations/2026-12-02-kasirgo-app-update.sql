-- KasirGo: Sistem Update Aplikasi + Panduan terpusat di Cloudflare R2.
--
-- Alur:
--   1. Superadmin (Control Plane > Update Aplikasi) upload APK/panduan ke R2,
--      lalu simpan + publish rilis (app_releases).
--   2. App (klien) memanggil get_latest_app_release untuk melihat pembaruan.
--   3. Superadmin konfigurasi SMTP (system_smtp_config) khusus untuk email
--      VERIFIKASI pendaftaran (auth), diterapkan via EF apply_smtp_auth.
--   4. Banner "Update tersedia" ditampilkan di dashboard owner; klik Update Sistem
--      -> download file terbaru (APK via install / web reload) tanpa hapus DB lokal.

-- ============================================================
-- 1. Tabel rilis aplikasi (APK & web) + panduan
-- ============================================================
CREATE TABLE IF NOT EXISTS public.app_releases (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  platform     text NOT NULL CHECK (platform IN ('android','web')),
  version      text NOT NULL,
  build_number integer NOT NULL DEFAULT 0,
  file_key     text,
  file_url     text,
  file_size    bigint,
  sha256       text,
  guide_key    text,
  guide_url    text,
  changelog    text NOT NULL DEFAULT '',
  is_published boolean NOT NULL DEFAULT false,
  force_update boolean NOT NULL DEFAULT false,
  published_at timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  created_by   uuid
);
CREATE INDEX IF NOT EXISTS idx_app_releases_platform
  ON public.app_releases (platform, build_number DESC);

ALTER TABLE public.app_releases ENABLE ROW LEVEL SECURITY;
-- Klien hanya boleh membaca rilis yang sudah terbit (URL R2 bersifat publik).
CREATE POLICY "app_releases_select_published" ON public.app_releases
  FOR SELECT USING (is_published = true);
-- Tulis hanya via RPC superadmin (tidak ada policy INSERT/UPDATE/DELETE).

-- ============================================================
-- 3. Tabel konfigurasi SMTP (verifikasi email / auth, kunci hanya service_role)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.system_smtp_config (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider       text NOT NULL DEFAULT 'smtp',
  host           text,
  port           integer NOT NULL DEFAULT 587,
  secure         boolean NOT NULL DEFAULT false,
  username       text,
  password       text,
  from_email     text,
  from_name      text NOT NULL DEFAULT 'KasirGo',
  is_active      boolean NOT NULL DEFAULT false,
  apply_as_auth  boolean NOT NULL DEFAULT false,
  updated_at     timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.system_smtp_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.system_smtp_config FROM anon, authenticated;

-- ============================================================
-- 4. RPC: baca rilis terbaru (klien)
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
    'build_number', r.build_number, 'file_url', r.file_url,
    'file_size', r.file_size, 'sha256', r.sha256,
    'guide_url', r.guide_url, 'changelog', r.changelog,
    'force_update', r.force_update, 'published_at', r.published_at
  );
END $$;
GRANT EXECUTE ON FUNCTION public.get_latest_app_release(text) TO anon, authenticated;

-- ============================================================
-- 5. RPC superadmin: daftar rilis
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_list_app_releases()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  RETURN COALESCE(
    (SELECT jsonb_agg(row_to_json(t) ORDER BY t.created_at DESC)
     FROM (SELECT id, platform, version, build_number, file_key, file_url, file_size,
                  sha256, guide_key, guide_url, changelog, is_published, force_update,
                  published_at, created_at
           FROM public.app_releases) t),
    '[]'::jsonb
  );
END $$;
GRANT EXECUTE ON FUNCTION public.admin_list_app_releases() TO authenticated;

-- ============================================================
-- 6. RPC superadmin: simpan rilis (upsert berdasar platform+version)
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_save_app_release(p_release jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_platform text := nullif(btrim(coalesce(p_release->>'platform','')),'');
  v_version  text := nullif(btrim(coalesce(p_release->>'version','')),'');
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
      (platform, version, build_number, file_key, file_url, file_size, sha256,
       guide_key, guide_url, changelog, is_published, force_update, created_by)
    VALUES
      (v_platform, v_version, COALESCE((p_release->>'build_number')::int, 0),
       nullif(btrim(coalesce(p_release->>'file_key','')),''),
       nullif(btrim(coalesce(p_release->>'file_url','')),''),
       NULLIF((p_release->>'file_size')::bigint, 0),
       nullif(btrim(coalesce(p_release->>'sha256','')),''),
       nullif(btrim(coalesce(p_release->>'guide_key','')),''),
       nullif(btrim(coalesce(p_release->>'guide_url','')),''),
       coalesce(p_release->>'changelog',''),
       COALESCE((p_release->>'is_published')::boolean, false),
       COALESCE((p_release->>'force_update')::boolean, false),
       auth.uid())
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.app_releases SET
      build_number = COALESCE((p_release->>'build_number')::int, build_number),
      file_key     = COALESCE(nullif(btrim(coalesce(p_release->>'file_key','')),''), file_key),
      file_url     = COALESCE(nullif(btrim(coalesce(p_release->>'file_url','')),''), file_url),
      file_size    = COALESCE(NULLIF((p_release->>'file_size')::bigint, 0), file_size),
      sha256       = COALESCE(nullif(btrim(coalesce(p_release->>'sha256','')),''), sha256),
      guide_key    = COALESCE(nullif(btrim(coalesce(p_release->>'guide_key','')),''), guide_key),
      guide_url    = COALESCE(nullif(btrim(coalesce(p_release->>'guide_url','')),''), guide_url),
      changelog    = COALESCE(p_release->>'changelog', changelog),
      force_update = COALESCE((p_release->>'force_update')::boolean, force_update)
    WHERE id = v_id;
  END IF;

  RETURN public.admin_list_app_releases();
END $$;
GRANT EXECUTE ON FUNCTION public.admin_save_app_release(jsonb) TO authenticated;

-- ============================================================
-- 7. RPC superadmin: terbitkan / tarik rilis
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_publish_app_release(p_id uuid, p_publish boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  UPDATE public.app_releases SET
    is_published = p_publish,
    published_at = CASE WHEN p_publish THEN now() ELSE published_at END
  WHERE id = p_id;
  PERFORM public.log_admin_action('app_release.publish', p_id::text,
    jsonb_build_object('publish', p_publish));
  RETURN public.admin_list_app_releases();
END $$;
GRANT EXECUTE ON FUNCTION public.admin_publish_app_release(uuid, boolean) TO authenticated;

-- ============================================================
-- 8. RPC superadmin: hapus rilis
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_delete_app_release(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  DELETE FROM public.app_releases WHERE id = p_id;
  PERFORM public.log_admin_action('app_release.delete', p_id::text, '{}'::jsonb);
  RETURN public.admin_list_app_releases();
END $$;
GRANT EXECUTE ON FUNCTION public.admin_delete_app_release(uuid) TO authenticated;

-- ============================================================
-- 9. RPC superadmin: baca konfigurasi SMTP (password ter-mask)
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_get_smtp_config()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE c record;
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  SELECT * INTO c FROM public.system_smtp_config
  ORDER BY updated_at DESC NULLS LAST LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('has_config', false); END IF;
  RETURN jsonb_build_object(
    'has_config', true,
    'id', c.id, 'provider', c.provider, 'host', c.host, 'port', c.port,
    'secure', c.secure, 'username', c.username, 'from_email', c.from_email,
    'from_name', c.from_name, 'is_active', c.is_active, 'apply_as_auth', c.apply_as_auth,
    'has_password', (c.password IS NOT NULL AND length(btrim(c.password)) > 0),
    'password_hint', CASE WHEN c.password IS NULL OR length(btrim(c.password)) = 0
                          THEN NULL ELSE '****' || right(c.password, 4) END,
    'updated_at', c.updated_at
  );
END $$;
GRANT EXECUTE ON FUNCTION public.admin_get_smtp_config() TO authenticated;

-- ============================================================
-- 10. RPC superadmin: simpan konfigurasi SMTP (password hanya ditimpa bila dikirim)
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_save_smtp_config(p_config jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_host text := nullif(btrim(coalesce(p_config->>'host','')),'');
  v_user text := nullif(btrim(coalesce(p_config->>'username','')),'');
  v_pass text := nullif(btrim(coalesce(p_config->>'password','')),'');
  v_from text := nullif(btrim(coalesce(p_config->>'from_email','')),'');
  v_clear boolean := coalesce((p_config->>'clear_password')::boolean, false);
  rec record;
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;

  SELECT * INTO rec FROM public.system_smtp_config
  ORDER BY updated_at DESC NULLS LAST LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.system_smtp_config
      (provider, host, port, secure, username, password, from_email, from_name, is_active, apply_as_auth)
    VALUES
      (coalesce(nullif(btrim(coalesce(p_config->>'provider','')),''),'smtp'),
       v_host, COALESCE((p_config->>'port')::int, 587),
       COALESCE((p_config->>'secure')::boolean, false),
       v_user, v_pass, v_from,
       coalesce(nullif(btrim(coalesce(p_config->>'from_name','')),''),'KasirGo'),
       COALESCE((p_config->>'is_active')::boolean, false),
       COALESCE((p_config->>'apply_as_auth')::boolean, false));
  ELSE
    UPDATE public.system_smtp_config SET
      provider      = COALESCE(nullif(btrim(coalesce(p_config->>'provider','')),''), provider),
      host          = COALESCE(v_host, host),
      port          = COALESCE((p_config->>'port')::int, port),
      secure        = COALESCE((p_config->>'secure')::boolean, secure),
      username      = COALESCE(v_user, username),
      password      = CASE WHEN v_clear THEN NULL
                           WHEN v_pass IS NOT NULL THEN v_pass
                           ELSE password END,
      from_email    = COALESCE(v_from, from_email),
      from_name     = COALESCE(nullif(btrim(coalesce(p_config->>'from_name','')),''), from_name),
      is_active     = COALESCE((p_config->>'is_active')::boolean, is_active),
      apply_as_auth = COALESCE((p_config->>'apply_as_auth')::boolean, apply_as_auth),
      updated_at    = now()
    WHERE id = rec.id;
  END IF;

  PERFORM public.log_admin_action('smtp.save', COALESCE(v_host,''), '{}'::jsonb);
  RETURN public.admin_get_smtp_config();
END $$;
GRANT EXECUTE ON FUNCTION public.admin_save_smtp_config(jsonb) TO authenticated;