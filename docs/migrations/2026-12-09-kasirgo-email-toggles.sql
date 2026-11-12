-- KasirGo: Toggle email (konfirmasi / notifikasi / kirim) untuk SMTP sistem.
--
-- Tiga saklar yang dikelola superadmin melalui Control Plane > Update Aplikasi:
--   email_confirmation_enabled  -> mailer_autoconfirm = NOT (ini) di Supabase Auth.
--                                   false (default) = daftar awal TANPA konfirmasi email.
--   email_notifications_enabled -> izinkan kirim email notifikasi (report_scheduler dll).
--   is_active                   -> saklar utama "kirim email" (SMTP aktif).
--
-- Semua disimpan di system_smtp_config (kunci hanya service_role), diedit via RPC
-- superadmin (admin_get_smtp_config / admin_save_smtp_config) dan diterapkan ke
-- Supabase Auth oleh Edge Function apply_smtp_auth.

ALTER TABLE public.system_smtp_config
  ADD COLUMN IF NOT EXISTS email_confirmation_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS email_notifications_enabled boolean NOT NULL DEFAULT true;

-- ---------------------------------------------------------------------------
-- RPC baca (tambahkan dua kolom baru ke respons)
-- ---------------------------------------------------------------------------
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
    'email_confirmation_enabled', c.email_confirmation_enabled,
    'email_notifications_enabled', c.email_notifications_enabled,
    'has_password', (c.password IS NOT NULL AND length(btrim(c.password)) > 0),
    'password_hint', CASE WHEN c.password IS NULL OR length(btrim(c.password)) = 0
                          THEN NULL ELSE '****' || right(c.password, 4) END,
    'updated_at', c.updated_at
  );
END $$;
GRANT EXECUTE ON FUNCTION public.admin_get_smtp_config() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC simpan (terima + simpan dua toggle baru)
-- ---------------------------------------------------------------------------
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
      (provider, host, port, secure, username, password, from_email, from_name, is_active, apply_as_auth,
       email_confirmation_enabled, email_notifications_enabled)
    VALUES
      (coalesce(nullif(btrim(coalesce(p_config->>'provider','')),''),'smtp'),
       v_host, COALESCE((p_config->>'port')::int, 587),
       COALESCE((p_config->>'secure')::boolean, false),
       v_user, v_pass, v_from,
       coalesce(nullif(btrim(coalesce(p_config->>'from_name','')),''),'KasirGo'),
       COALESCE((p_config->>'is_active')::boolean, false),
       COALESCE((p_config->>'apply_as_auth')::boolean, false),
       COALESCE((p_config->>'email_confirmation_enabled')::boolean, false),
       COALESCE((p_config->>'email_notifications_enabled')::boolean, true));
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
      email_confirmation_enabled = COALESCE((p_config->>'email_confirmation_enabled')::boolean, email_confirmation_enabled),
      email_notifications_enabled = COALESCE((p_config->>'email_notifications_enabled')::boolean, email_notifications_enabled),
      updated_at    = now()
    WHERE id = rec.id;
  END IF;

  PERFORM public.log_admin_action('smtp.save', COALESCE(v_host,''), '{}'::jsonb);
  RETURN public.admin_get_smtp_config();
END $$;
GRANT EXECUTE ON FUNCTION public.admin_save_smtp_config(jsonb) TO authenticated;