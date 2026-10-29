-- KasirGo: ganti Pool Token AI (slot tetap) dengan konfigurasi API AI dinamis.
-- Tabel `system_api_configs` menyimpan endpoint/model/kunci (primary + 2 backup)
-- secara terpusat dan dibaca dinamis oleh Edge Function `doctor-proxy` serta
-- `business_doctor_chat`. Fallback otomatis: primary -> backup 1 -> backup 2.
-- Kunci hanya dapat dibaca service_role; superadmin melihat versi ter-mask.

-- ============================================================
-- 1. Hapus fitur Pool Token AI (digantikan konfigurasi di atas)
-- ============================================================
DROP FUNCTION IF EXISTS public.doctor_ai_status(uuid);
DROP FUNCTION IF EXISTS public.doctor_ai_claim(uuid);
DROP FUNCTION IF EXISTS public.doctor_ai_claim_internal(uuid);
DROP FUNCTION IF EXISTS public.doctor_ai_pool_backfill_internal();
DROP FUNCTION IF EXISTS public.doctor_ai_pool_backfill();
DROP FUNCTION IF EXISTS public.admin_release_doctor_ai_outlet(uuid);
DROP FUNCTION IF EXISTS public.admin_delete_doctor_ai_token(bigint);
DROP FUNCTION IF EXISTS public.admin_save_doctor_ai_pool(bigint, jsonb);
DROP FUNCTION IF EXISTS public.admin_list_doctor_ai_pool();
DROP FUNCTION IF EXISTS public.doctor_ai_pool_max_per_key();
DROP TABLE IF EXISTS public.doctor_ai_pool_assignments;
DROP TABLE IF EXISTS public.doctor_ai_pool;

-- ============================================================
-- 2. Tabel konfigurasi API AI global
-- ============================================================
CREATE TABLE IF NOT EXISTS public.system_api_configs (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_name  text NOT NULL DEFAULT 'custom_llm',
  base_url       text,
  model_name     text,
  primary_key    text,
  backup_key_1   text,
  backup_key_2   text,
  is_active      boolean NOT NULL DEFAULT true,
  updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_system_api_configs_active
  ON public.system_api_configs (is_active, updated_at DESC);

ALTER TABLE public.system_api_configs ENABLE ROW LEVEL SECURITY;
-- Kunci hanya untuk service_role / postgres. Klien (anon/authenticated) dilarang
-- membaca tabel langsung; superadmin memakai RPC ter-mask di bawah.
REVOKE ALL ON public.system_api_configs FROM anon, authenticated;

-- ============================================================
-- 3. RPC superadmin: baca konfigurasi (kunci ter-mask)
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_get_system_api_config()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE c record; res jsonb;
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  SELECT * INTO c FROM public.system_api_configs
  WHERE is_active = true
  ORDER BY updated_at DESC NULLS LAST
  LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('has_config', false);
  END IF;
  RETURN jsonb_build_object(
    'has_config', true,
    'id', c.id,
    'provider_name', c.provider_name,
    'base_url', c.base_url,
    'model_name', c.model_name,
    'is_active', c.is_active,
    'has_primary_key', (c.primary_key IS NOT NULL AND length(btrim(c.primary_key)) > 0),
    'has_backup_key_1', (c.backup_key_1 IS NOT NULL AND length(btrim(c.backup_key_1)) > 0),
    'has_backup_key_2', (c.backup_key_2 IS NOT NULL AND length(btrim(c.backup_key_2)) > 0),
    'primary_hint', CASE WHEN c.primary_key IS NULL OR length(btrim(c.primary_key)) = 0
                         THEN NULL ELSE '****' || right(c.primary_key, 4) END,
    'backup1_hint', CASE WHEN c.backup_key_1 IS NULL OR length(btrim(c.backup_key_1)) = 0
                         THEN NULL ELSE '****' || right(c.backup_key_1, 4) END,
    'backup2_hint', CASE WHEN c.backup_key_2 IS NULL OR length(btrim(c.backup_key_2)) = 0
                         THEN NULL ELSE '****' || right(c.backup_key_2, 4) END,
    'updated_at', c.updated_at
  );
END $$;
GRANT EXECUTE ON FUNCTION public.admin_get_system_api_config() TO authenticated;

-- ============================================================
-- 4. RPC superadmin: simpan konfigurasi (kunci hanya ditimpa bila dikirim)
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_save_system_api_config(p_config jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_provider text := nullif(btrim(coalesce(p_config->>'provider_name','')),'');
  v_base text := nullif(btrim(coalesce(p_config->>'base_url','')),'');
  v_model text := nullif(btrim(coalesce(p_config->>'model_name','')),'');
  v_primary text := nullif(btrim(coalesce(p_config->>'primary_key','')),'');
  v_backup1 text := nullif(btrim(coalesce(p_config->>'backup_key_1','')),'');
  v_backup2 text := nullif(btrim(coalesce(p_config->>'backup_key_2','')),'');
  v_clear_keys boolean := coalesce((p_config->>'clear_keys')::boolean, false);
  v_active boolean := coalesce((p_config->>'is_active')::boolean, true);
  rec record;
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  IF v_provider IS NULL THEN v_provider := 'custom_llm'; END IF;

  SELECT * INTO rec FROM public.system_api_configs
  WHERE provider_name = v_provider
  ORDER BY updated_at DESC NULLS LAST
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.system_api_configs
      (provider_name, base_url, model_name, primary_key, backup_key_1, backup_key_2, is_active)
    VALUES (v_provider, v_base, v_model, v_primary, v_backup1, v_backup2, v_active);
  ELSE
    UPDATE public.system_api_configs SET
      base_url     = COALESCE(v_base, base_url),
      model_name   = COALESCE(v_model, model_name),
      primary_key  = CASE WHEN v_clear_keys THEN NULL
                          WHEN v_primary IS NOT NULL THEN v_primary
                          ELSE primary_key END,
      backup_key_1 = CASE WHEN v_clear_keys THEN NULL
                          WHEN v_backup1 IS NOT NULL THEN v_backup1
                          ELSE backup_key_1 END,
      backup_key_2 = CASE WHEN v_clear_keys THEN NULL
                          WHEN v_backup2 IS NOT NULL THEN v_backup2
                          ELSE backup_key_2 END,
      is_active    = v_active,
      updated_at   = now()
    WHERE id = rec.id;
  END IF;

  RETURN public.admin_get_system_api_config();
END $$;
GRANT EXECUTE ON FUNCTION public.admin_save_system_api_config(jsonb) TO authenticated;