-- =============================================================================
-- 2026-10-06-kasirgo-13c-fixes.sql
--
-- Phase 13C:
--   1. Backup terjadwal: tambah cadence 'monthly' (harian/mingguan/bulanan).
--   2. Afiliasi: pendaftaran mandiri. Default OTOMATIS (langsung aktif),
--      superadmin bisa alihkan ke PERSETUJUAN MANUAL lewat Control Plane
--      (platform_configs('affiliate').require_approval).
--      - handle_new_user: pendaftar afiliasi tidak boleh membuat outlet.
--      - trigger membuat baris affiliates otomatis (atomik, tidak ada user "yatim").
--      - RPC affiliate_register: fallback/repair + idempotent.
--      - RPC platform_affiliate_set_status: approve/reject dari superadmin.
--
-- Dijalankan via psql (service_role tidak disimpan di repo).
-- =============================================================================

\set ON_ERROR_STOP on
BEGIN;

-- -----------------------------------------------------------------------------
-- 1. BACKUP TERJADWAL: cadence bulanan
-- -----------------------------------------------------------------------------
ALTER TABLE public.backup_schedules
  DROP CONSTRAINT IF EXISTS backup_schedules_cadence_check;

ALTER TABLE public.backup_schedules
  ADD CONSTRAINT backup_schedules_cadence_check
  CHECK (cadence = ANY (ARRAY['daily','weekly','monthly']));

-- Simpan nilai 'weekly'/'monthly' yang sudah ada (constraint lama sudah dilepas,
-- jadi tidak ada data invalid). Pastikan tidak ada nilai di luar daftar baru.
UPDATE public.backup_schedules
   SET cadence = 'daily'
 WHERE cadence IS NULL OR cadence NOT IN ('daily','weekly','monthly');

CREATE OR REPLACE FUNCTION public.platform_backup_schedule_set(
  p_outlet_id uuid,
  p_enabled boolean,
  p_cadence text DEFAULT 'daily'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.backup_schedules (outlet_id, enabled, cadence, updated_by, updated_at)
  VALUES (p_outlet_id, p_enabled,
          CASE WHEN p_cadence IN ('weekly','monthly') THEN p_cadence ELSE 'daily' END,
          auth.uid(), NOW())
  ON CONFLICT (outlet_id) DO UPDATE
    SET enabled = EXCLUDED.enabled, cadence = EXCLUDED.cadence,
        updated_by = EXCLUDED.updated_by, updated_at = NOW();

  PERFORM public.log_admin_action('backup_schedule_set', p_outlet_id::text,
    jsonb_build_object('enabled', p_enabled, 'cadence', p_cadence));
END;
$function$;

CREATE OR REPLACE FUNCTION public.platform_backup_run_due()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ok boolean;
  v_count int := 0;
  r RECORD;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  FOR r IN
    SELECT s.outlet_id, s.cadence
    FROM public.backup_schedules s
    WHERE s.enabled
      AND (s.last_run_at IS NULL
           OR (s.cadence = 'daily'   AND s.last_run_at < date_trunc('day', NOW()))
           OR (s.cadence = 'weekly'  AND s.last_run_at <  NOW() - interval '7 days')
           OR (s.cadence = 'monthly' AND s.last_run_at <  NOW() - interval '1 month'))
  LOOP
    PERFORM public.platform_backup_create(r.outlet_id, 'quick');
    UPDATE public.backup_schedules SET last_run_at = NOW() WHERE outlet_id = r.outlet_id;
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$function$;

-- -----------------------------------------------------------------------------
-- 2. AFILIASI: pendaftaran mandiri
-- -----------------------------------------------------------------------------

-- 2a. Generator kode referral unik (dipakai trigger & RPC).
CREATE OR REPLACE FUNCTION public.affiliate_generate_code()
RETURNS text
LANGUAGE plpgsql
VOLATILE
AS $function$
DECLARE
  v_code text;
  v_try int := 0;
BEGIN
  LOOP
    v_code := 'KGD' || upper(substr(md5(random()::text), 1, 6));
    IF NOT EXISTS (SELECT 1 FROM public.affiliates WHERE referral_code = v_code) THEN
      RETURN v_code;
    END IF;
    v_try := v_try + 1;
    IF v_try > 20 THEN
      -- Fallback deterministik dari uuid agar tetap unik.
      RETURN 'KGD' || upper(replace(substr(gen_random_uuid()::text, 1, 8), '-', ''));
    END IF;
  END LOOP;
END;
$function$;

-- 2b. Baca config afiliasi global (default: otomatis, komisi 10%).
CREATE OR REPLACE FUNCTION public.platform_affiliate_config()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
  SELECT COALESCE(
    (SELECT c.value
       FROM public.platform_configs c
      WHERE c.key = 'affiliate' AND c.scope = 'global'
      ORDER BY c.version DESC
      LIMIT 1),
    '{"require_approval": false, "default_commission": 10}'::jsonb
  );
$function$;

-- 2c. Trigger: pendaftar afiliasi TIDAK boleh membuat outlet.
--     Owner & staff tetap seperti sebelumnya.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  new_outlet_id UUID;
  staff_role TEXT;
  staff_outlet UUID;
  signup_kind TEXT;
  aff_name TEXT;
  aff_phone TEXT;
  aff_email TEXT;
  aff_code TEXT;
  aff_commission numeric;
  aff_status TEXT;
  cfg jsonb;
BEGIN
  signup_kind := COALESCE(NEW.raw_user_meta_data->>'signup_kind', '');
  staff_role := NEW.raw_user_meta_data->>'staff_role';
  staff_outlet := NULLIF(NEW.raw_user_meta_data->>'outlet_id', '')::UUID;

  -- Pendaftaran AFILIASI: buat baris affiliates, jangan buat outlet/user_roles.
  IF signup_kind = 'affiliate' THEN
    aff_name  := COALESCE(NULLIF(trim(NEW.raw_user_meta_data->>'full_name'), ''), split_part(NEW.email, '@', 1));
    aff_phone := NULLIF(trim(NEW.raw_user_meta_data->>'phone'), '');
    aff_email := lower(trim(COALESCE(NEW.email, '')));

    cfg := public.platform_affiliate_config();
    aff_commission := COALESCE((cfg->>'default_commission')::numeric, 10);
    aff_status := CASE
                   WHEN COALESCE((cfg->>'require_approval')::boolean, false)
                     THEN 'pending'   -- superadmin harus setujui
                   ELSE 'active'         -- default: langsung aktif
                 END;
    aff_code := public.affiliate_generate_code();

    INSERT INTO public.affiliates
      (name, email, phone, user_id, referral_code, commission_percent, status)
    VALUES
      (aff_name, NULLIF(aff_email, ''), aff_phone, NEW.id, aff_code, aff_commission, aff_status)
    ON CONFLICT (email) DO UPDATE
      SET user_id    = EXCLUDED.user_id,
          name       = COALESCE(NULLIF(EXCLUDED.name, ''), public.affiliates.name),
          phone      = COALESCE(EXCLUDED.phone, public.affiliates.phone);

    RETURN NEW;
  END IF;

  -- Kasus STAF
  IF staff_role IN ('admin', 'cashier') AND staff_outlet IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.outlets WHERE id = staff_outlet) THEN
      INSERT INTO public.user_roles (user_id, outlet_id, role)
      VALUES (NEW.id, staff_outlet, staff_role)
      ON CONFLICT (user_id, outlet_id) DO UPDATE SET role = EXCLUDED.role;
    END IF;
    RETURN NEW;
  END IF;

  -- Kasus OWNER / pendaftar biasa
  INSERT INTO public.outlets (owner_id, name, type)
  VALUES (
    NEW.id,
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'business_name', ''), 'Toko Baru'),
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'business_type', ''), 'warung')
  )
  RETURNING id INTO new_outlet_id;

  INSERT INTO public.user_roles (user_id, outlet_id, role)
  VALUES (NEW.id, new_outlet_id, 'owner')
  ON CONFLICT (user_id, outlet_id) DO UPDATE SET role = EXCLUDED.role;

  RETURN NEW;
END;
$function$;

-- 2d. RPC affiliate_register: idempotent, dipanggil portal setelah signUp.
--     Menutup kasus lama (akun dibuat sebelum migrasi ini / trigger gagal).
--     p_referral_code opsional = kode afiliasi yang mereferensikan orang ini.
CREATE OR REPLACE FUNCTION public.affiliate_register(
  p_name text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_referral_code text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_email text;
  v_id uuid;
  v_code text;
  v_status text;
  v_commission numeric;
  v_meta jsonb;
  cfg jsonb;
  referrer_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  SELECT COALESCE(email,'') INTO v_email FROM auth.users WHERE id = v_uid;
  v_email := lower(trim(v_email));
  IF v_email = '' THEN RAISE EXCEPTION 'email_missing'; END IF;

  cfg := public.platform_affiliate_config();
  v_commission := COALESCE((cfg->>'default_commission')::numeric, 10);
  v_status := CASE
                WHEN COALESCE((cfg->>'require_approval')::boolean, false) THEN 'pending'
                ELSE 'active'
              END;

  v_meta := COALESCE(
    (SELECT u.raw_user_meta_data FROM auth.users u WHERE u.id = v_uid), '{}'::jsonb);

  -- Sudah terdaftar? Kembalikan apa adanya (idempotent).
  SELECT id, referral_code, status INTO v_id, v_code, v_status
    FROM public.affiliates
   WHERE user_id = v_uid OR (email IS NOT NULL AND email = v_email)
   LIMIT 1;

  IF v_id IS NULL THEN
    v_code := public.affiliate_generate_code();
    INSERT INTO public.affiliates
      (name, email, phone, user_id, referral_code, commission_percent, status)
    VALUES
      (COALESCE(NULLIF(trim(p_name),''),
                NULLIF(trim(v_meta->>'full_name'),''),
                split_part(v_email,'@',1)),
       v_email,
       NULLIF(trim(COALESCE(p_phone, v_meta->>'phone', '')),''),
       v_uid, v_code, v_commission, v_status)
    RETURNING id, status INTO v_id, v_status;
  ELSE
    -- Perbarui kolom profil yang diisi registrant.
    UPDATE public.affiliates SET
      name  = COALESCE(NULLIF(trim(p_name),''), name),
      phone = COALESCE(NULLIF(trim(p_phone),''), phone),
      user_id = v_uid
    WHERE id = v_id;
  END IF;

  -- Catat referral kalau registrant menyebut kode afiliasi orang lain.
  IF NULLIF(trim(COALESCE(p_referral_code,'')),'') IS NOT NULL THEN
    SELECT id INTO referrer_id
      FROM public.affiliates
     WHERE upper(referral_code) = upper(trim(p_referral_code))
       AND id <> v_id
     LIMIT 1;
    IF referrer_id IS NOT NULL THEN
      INSERT INTO public.affiliate_referrals (affiliate_id, referred_user_id, status)
      VALUES (referrer_id, v_uid, 'pending')
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'id', v_id,
    'referral_code', v_code,
    'status', v_status,
    'commission_percent', (SELECT commission_percent FROM public.affiliates WHERE id = v_id)
  );
END;
$function$;

-- 2e. Superadmin: set status afiliasi (setujui / tolak / nonaktifkan).
CREATE OR REPLACE FUNCTION public.platform_affiliate_set_status(
  p_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ok boolean;
  v_code text;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.affiliates
     SET status = p_status
   WHERE id = p_id
  RETURNING referral_code INTO v_code;

  IF v_code IS NULL THEN RAISE EXCEPTION 'not_found'; END IF;

  PERFORM public.log_admin_action('affiliate.set_status', p_id::text,
    jsonb_build_object('status', p_status));

  RETURN jsonb_build_object('ok', true, 'id', p_id, 'status', p_status, 'referral_code', v_code);
END;
$function$;

-- 2f. Seed config afiliasi default (persetujuan manual = false = otomatis).
INSERT INTO public.platform_configs (key, scope, scope_ref, value, version, effective_from, updated_at)
VALUES ('affiliate', 'global', 'all',
        '{"require_approval": false, "default_commission": 10}'::jsonb,
        1, NOW(), NOW())
ON CONFLICT (key, scope, scope_ref) DO NOTHING;

-- 2g. Izinkan klien memanggil RPC baru.
GRANT EXECUTE ON FUNCTION public.affiliate_register(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.platform_affiliate_config() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.platform_affiliate_set_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.affiliate_generate_code() TO authenticated;

COMMIT;
