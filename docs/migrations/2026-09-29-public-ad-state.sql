-- ============================================================================
-- KasirGo — Status Iklan Publik per Outlet (sisi pelanggan)
-- Tanggal: 2026-09-29
--
-- Tujuan (ST7.8-6):
--   Pelanggan anonim (tanpa akun) perlu tahu apakah outlet menonaktifkan iklan
--   (Pendukung / ad_free). Tidak membuka tabel outlet_ad_state ke anon; pakai
--   RPC SECURITY DEFINER yang hanya mengembalikan boolean aman.
--
-- CARA PAKAI:
--   Supabase Dashboard -> SQL Editor -> tempel semua -> RUN.
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_public_ad_state(p_outlet TEXT)
RETURNS TABLE (ad_free BOOLEAN, is_supporter BOOLEAN, ad_enabled BOOLEAN)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    COALESCE(s.ad_free, e.ad_free, false) AS ad_free,
    (
      COALESCE(e.is_supporter, false)
      OR EXISTS (
        SELECT 1 FROM public.supporters sp
        WHERE sp.outlet_id = p_outlet::uuid
          AND sp.status = 'active'
          AND (sp.end_date IS NULL OR sp.end_date > now())
      )
    ) AS is_supporter,
    COALESCE(s.ad_enabled, true) AS ad_enabled
  FROM (SELECT 1) dummy
  LEFT JOIN public.outlet_ad_state s ON s.outlet_id = p_outlet::uuid
  LEFT JOIN public.entitlements e ON e.outlet_id = p_outlet::uuid;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_ad_state(TEXT) TO anon, authenticated;

-- ============================================================================
-- VERIFIKASI:
--   SELECT * FROM get_public_ad_state('<outlet-id>');
--   -> ad_free / is_supporter true untuk outlet Pendukung.
-- ============================================================================
