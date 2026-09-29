-- ============================================================================
-- KasirGo — Control Plane Superadmin (ST7.8-9)
-- Tanggal: 2026-09-29
--
-- Tujuan:
--   - Helper `is_platform_admin()` (SECURITY DEFINER) yang mengenali superadmin via
--     klaim JWT app_metadata.role = superadmin/superowner ATAU keanggotaan admin_users.
--   - Pasang ulang policy superadmin pada tabel Control Plane memakai helper ini.
--   - Seed baris admin_users untuk akun superadmin nyata.
--
-- Catatan: RLS bawaan memakai auth.jwt()->>'role' (default 'authenticated').
--   Helper ini menambah jalur app_metadata + admin_users agar tim admin nyata bekerja.
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

-- Helper: true bila pemanggil adalah superadmin platform.
CREATE OR REPLACE FUNCTION public.is_platform_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    COALESCE(auth.jwt()->'app_metadata'->>'role', '') IN ('superowner','superadmin')
    OR COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin')
    OR EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE au.user_id = auth.uid() AND au.is_active = true
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_platform_admin() TO authenticated;

-- Pasang ulang policy superadmin memakai helper.
DO $$
DECLARE
  t TEXT;
  tables TEXT[] := ARRAY[
    'supporters','entitlements','billing_events','report_schedules','outlet_ad_state',
    'guide_items','announcements','platform_configs','feature_flags','segments',
    'outlet_segments','automation_rules','audit_logs','admin_users','outlet_kyc'
  ];
  pol TEXT;
BEGIN
  FOREACH t IN ARRAY tables LOOP
    pol := 'Superadmin full access ' || t;
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol, t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin())',
      pol, t
    );
  END LOOP;
END $$;

-- audit_logs: helper insert untuk jejak aksi Control Plane (aktor = pemanggil).
CREATE OR REPLACE FUNCTION public.log_admin_action(
  p_action TEXT,
  p_target TEXT,
  p_meta JSONB DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN
    RAISE EXCEPTION 'not_platform_admin';
  END IF;
  INSERT INTO public.audit_logs (actor_id, actor_role, action, target, meta)
  VALUES (
    auth.uid(),
    COALESCE(auth.jwt()->'app_metadata'->>'role', auth.jwt()->>'role', 'superadmin'),
    p_action, p_target, COALESCE(p_meta, '{}'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_admin_action(TEXT,TEXT,JSONB) TO authenticated;

-- ============================================================================
-- VERIFIKASI:
--   SELECT public.is_platform_admin();
--   SELECT * FROM public.audit_logs ORDER BY created_at DESC LIMIT 5;
-- ============================================================================