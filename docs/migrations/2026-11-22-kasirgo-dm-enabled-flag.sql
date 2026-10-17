-- ============================================================================
-- KasirGo 3.0 - Squad DM: flag publik tanpa membocorkan kredensial LLM
-- Tanggal: 2026-11-22
--
-- Masalah: RLS `platform_configs` sengaja menutup `digital_marketing_llm`
-- untuk klien (agar api_key tidak bocor). Akibatnya app owner tidak bisa
-- membaca `aktif` -> kartu "Squad DM" (Studio Desain/Promosi/Iklan) tidak
-- pernah tampil.
--
-- Solusi: RPC SECURITY DEFINER yang HANYA mengembalikan boolean `aktif`
-- (tanpa api_key/base_url/model).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.dm_enabled()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE((value ->> 'aktif')::boolean, false)
  FROM public.platform_configs
  WHERE key = 'digital_marketing_llm'
  LIMIT 1
$$;

REVOKE ALL ON FUNCTION public.dm_enabled() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dm_enabled() TO authenticated, service_role;

COMMENT ON FUNCTION public.dm_enabled() IS
  'Squad DM aktif? (boolean saja, tanpa kredensial LLM)';
