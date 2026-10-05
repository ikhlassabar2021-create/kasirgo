-- =============================================================================
-- 2026-10-13-kasirgo-13c-superadmin-pg.sql
--
-- Phase 13C ST13C-1 — Superadmin Control Plane: Payment Gateway.
--
-- Menyediakan RPC khusus superadmin untuk melihat dan mengelola status
-- pembayaran Payment Gateway (Midtrans) per outlet. Semua RPC:
--   - SECURITY DEFINER + cek public.is_platform_admin() (forbidden bila bukan).
--   - TIDAK pernah mengembalikan server key / server_key_secret_id.
--   - Menulis jejak audit via public.log_admin_action().
--
-- Catatan: RLS outlet_pg_configs hanya mengizinkan owner membaca barisnya
-- sendiri, sehingga superadmin perlu RPC ini.
--
-- Idempotent: aman dijalankan berulang.
-- =============================================================================

\set ON_ERROR_STOP on
BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Daftar outlet + status PG (ter-mask)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_outlet_pg_configs()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_platform_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN COALESCE((
    SELECT jsonb_agg(to_jsonb(x) ORDER BY x.outlet_name)
    FROM (
      SELECT
        o.id                                  AS outlet_id,
        o.name                                AS outlet_name,
        o.type                                AS outlet_type,
        u.email                               AS owner_email,
        COALESCE(c.provider, 'midtrans')      AS provider,
        c.merchant_id,
        c.client_key,
        (c.server_key_secret_id IS NOT NULL)  AS has_server_key,
        COALESCE(c.is_production, false)      AS is_production,
        COALESCE(c.status, 'not_configured')  AS status,
        c.last_tested_at,
        c.last_test_result,
        c.updated_at
      FROM public.outlets o
      LEFT JOIN public.outlet_pg_configs c ON c.outlet_id = o.id
      LEFT JOIN auth.users u ON u.id = o.owner_id
    ) x
  ), '[]'::jsonb);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_list_outlet_pg_configs() TO authenticated;

-- -----------------------------------------------------------------------------
-- 2. Ubah status pembayaran outlet (verified | disabled | pending)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_outlet_pg_status(
  p_outlet uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_prev text;
BEGIN
  IF NOT public.is_platform_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_status NOT IN ('pending', 'verified', 'disabled') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  SELECT status INTO v_prev
    FROM public.outlet_pg_configs
   WHERE outlet_id = p_outlet;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_configured';
  END IF;

  UPDATE public.outlet_pg_configs
     SET status = p_status,
         updated_at = now()
   WHERE outlet_id = p_outlet;

  PERFORM public.log_admin_action(
    'outlet_pg.set_status',
    p_outlet::text,
    jsonb_build_object('from', v_prev, 'to', p_status)
  );

  RETURN jsonb_build_object('ok', true, 'status', p_status);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_set_outlet_pg_status(uuid, text) TO authenticated;

COMMIT;

-- =============================================================================
-- VERIFIKASI:
--   SELECT public.admin_list_outlet_pg_configs();
--   SELECT public.admin_set_outlet_pg_status('<outlet-uuid>', 'disabled');
--   SELECT action, target, meta, created_at FROM public.audit_logs
--    WHERE action = 'outlet_pg.set_status' ORDER BY created_at DESC LIMIT 5;
-- =============================================================================
