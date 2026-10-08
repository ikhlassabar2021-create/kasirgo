-- ============================================================================
-- 2026-10-21-kasirgo-fix-report-visibility.sql
-- FIX superadmin: sembunyikan laporan PPOB & QRIS + riwayat PPOB/PG/B2B/Modal
-- Usaha per outlet — KONFIGURABEL (bisa dibuka kembali lewat setting).
--
-- Mekanisme:
--   1. platform_configs key='report' scope='global' ditambah flag:
--        show_ppob_report   (bool, default FALSE)  -> kartu PPOB di Laporan Utama
--        show_pg_report     (bool, default FALSE)  -> kartu Payment Gateway (QRIS)
--        show_outlet_hist   (bool, default FALSE)  -> panel Riwayat Transaksi
--                                                     (PPOB/PG/B2B/Modal Usaha)
--        show_outlet_ppob   (bool, default FALSE)  -> stat PPOB/PG/B2B/Modal Usaha
--                                                     di Laporan Outlet (detail)
--      Semua default FALSE = disembunyikan; superadmin bisa menyalakan kembali
--      lewat ControlPlane > Laporan.
--   2. RPC platform_report_visibility(): baca flag (superadmin & klien admin).
--   3. UI admin membaca flag dan menyembunyikan bagian terkait.
-- ============================================================================

-- 1. Patch config 'report' dengan flag visibility (merge, tidak menimpa).
INSERT INTO public.platform_configs (key, scope, scope_ref, value, updated_by)
VALUES ('report', 'global', 'all',
  jsonb_build_object(
    'show_ppob_report', FALSE,
    'show_pg_report', FALSE,
    'show_outlet_hist', FALSE,
    'show_outlet_ppob', FALSE
  ),
  (SELECT id FROM auth.users LIMIT 1)
)
ON CONFLICT (key, scope, scope_ref) DO UPDATE
SET value = public.platform_configs.value || EXCLUDED.value,
    version = public.platform_configs.version + 1,
    updated_at = NOW();

-- 2. RPC baca visibility (aman untuk admin; fallback default FALSE).
CREATE OR REPLACE FUNCTION public.platform_report_visibility()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ok boolean;
DECLARE v_value jsonb;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT value INTO v_value FROM public.platform_configs
  WHERE key = 'report' AND scope = 'global'
  ORDER BY version DESC LIMIT 1;

  RETURN jsonb_build_object(
    'show_ppob_report', COALESCE(v_value->>'show_ppob_report', 'false')::boolean,
    'show_pg_report',   COALESCE(v_value->>'show_pg_report',   'false')::boolean,
    'show_outlet_hist', COALESCE(v_value->>'show_outlet_hist', 'false')::boolean,
    'show_outlet_ppob', COALESCE(v_value->>'show_outlet_ppob', 'false')::boolean
  );
END;
$$;

REVOKE ALL ON FUNCTION public.platform_report_visibility() FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.platform_report_visibility() TO authenticated;
