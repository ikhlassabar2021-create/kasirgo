-- =============================================================================
-- 2026-12-01-kasirgo-system-api-config-vault.sql
--
-- Konfigurasi API AI global (system_api_configs) — penyempurnaan:
--  1) Backup key 1 & 2 kini punya BASE URL + MODEL sendiri, sehingga setiap
--     kunci bisa menunjuk provider yang berbeda (fallback lintas provider).
--  2) Kunci API (primary/backup_1/backup_2) dipindah ke Supabase Vault.
--     Kolom plaintext dihapus; tabel hanya menyimpan `*_secret_id` (uuid).
--     Kunci dibaca/ditulis lewat public.vault_put_secret / vault_read_secret
--     (hanya service_role/postgres), jadi klien tidak pernah melihat kunci.
--
-- Aman dijalankan berulang (idempotent).
-- =============================================================================

\set ON_ERROR_STOP on
BEGIN;

-- -----------------------------------------------------------------------------
-- 0. Pastikan tabel dasar ada (idempotent untuk DB live yang belum punya tabel)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.system_api_configs (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_name text NOT NULL DEFAULT 'custom_llm',
  base_url      text,
  model_name    text,
  is_active     boolean NOT NULL DEFAULT true,
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 1. Kolom baru: base URL + model per backup, dan secret id per kunci
-- -----------------------------------------------------------------------------
ALTER TABLE public.system_api_configs
  ADD COLUMN IF NOT EXISTS backup1_base_url   text,
  ADD COLUMN IF NOT EXISTS backup1_model_name text,
  ADD COLUMN IF NOT EXISTS backup2_base_url   text,
  ADD COLUMN IF NOT EXISTS backup2_model_name text,
  ADD COLUMN IF NOT EXISTS primary_secret_id  uuid,
  ADD COLUMN IF NOT EXISTS backup1_secret_id  uuid,
  ADD COLUMN IF NOT EXISTS backup2_secret_id  uuid;

-- -----------------------------------------------------------------------------
-- 2. Migrasi kunci plaintext lama -> Vault (hanya bila masih ada kolom lama).
--    Tabel biasanya masih kosong sehingga blok ini no-op; tetap dibuat agar
--    migrasi aman bila ada data tersimpan.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  r record;
  v_id uuid;
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='system_api_configs'
      AND column_name='primary_key'
  ) THEN
    FOR r IN SELECT * FROM public.system_api_configs LOOP
      IF r.primary_key IS NOT NULL AND length(btrim(r.primary_key)) > 0 THEN
        v_id := public.vault_put_secret(r.primary_key, 'kasirgo system_api primary', NULL);
        UPDATE public.system_api_configs SET primary_secret_id = v_id WHERE id = r.id;
      END IF;
      IF r.backup_key_1 IS NOT NULL AND length(btrim(r.backup_key_1)) > 0 THEN
        v_id := public.vault_put_secret(r.backup_key_1, 'kasirgo system_api backup1', NULL);
        UPDATE public.system_api_configs SET backup1_secret_id = v_id WHERE id = r.id;
      END IF;
      IF r.backup_key_2 IS NOT NULL AND length(btrim(r.backup_key_2)) > 0 THEN
        v_id := public.vault_put_secret(r.backup_key_2, 'kasirgo system_api backup2', NULL);
        UPDATE public.system_api_configs SET backup2_secret_id = v_id WHERE id = r.id;
      END IF;
    END LOOP;
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 3. Hapus kolom plaintext kunci agar tidak pernah tersimpan di DB.
-- -----------------------------------------------------------------------------
ALTER TABLE public.system_api_configs DROP COLUMN IF EXISTS primary_key;
ALTER TABLE public.system_api_configs DROP COLUMN IF EXISTS backup_key_1;
ALTER TABLE public.system_api_configs DROP COLUMN IF EXISTS backup_key_2;

-- -----------------------------------------------------------------------------
-- 4. RPC admin: baca konfigurasi (kunci ter-mask; baca hint dari Vault).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_get_system_api_config()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  c record;
  v_primary text;
  v_backup1 text;
  v_backup2 text;
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  SELECT * INTO c FROM public.system_api_configs
  WHERE is_active = true
  ORDER BY updated_at DESC NULLS LAST
  LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('has_config', false);
  END IF;

  v_primary := NULLIF(public.vault_read_secret(c.primary_secret_id), '');
  v_backup1 := NULLIF(public.vault_read_secret(c.backup1_secret_id), '');
  v_backup2 := NULLIF(public.vault_read_secret(c.backup2_secret_id), '');

  RETURN jsonb_build_object(
    'has_config', true,
    'id', c.id,
    'provider_name', c.provider_name,
    'base_url', c.base_url,
    'model_name', c.model_name,
    'backup1_base_url', c.backup1_base_url,
    'backup1_model_name', c.backup1_model_name,
    'backup2_base_url', c.backup2_base_url,
    'backup2_model_name', c.backup2_model_name,
    'is_active', c.is_active,
    'has_primary_key', (v_primary IS NOT NULL),
    'has_backup_key_1', (v_backup1 IS NOT NULL),
    'has_backup_key_2', (v_backup2 IS NOT NULL),
    'primary_hint', CASE WHEN v_primary IS NULL THEN NULL ELSE '****' || right(v_primary, 4) END,
    'backup1_hint', CASE WHEN v_backup1 IS NULL THEN NULL ELSE '****' || right(v_backup1, 4) END,
    'backup2_hint', CASE WHEN v_backup2 IS NULL THEN NULL ELSE '****' || right(v_backup2, 4) END,
    'updated_at', c.updated_at
  );
END $$;
GRANT EXECUTE ON FUNCTION public.admin_get_system_api_config() TO authenticated;

-- -----------------------------------------------------------------------------
-- 5. RPC admin: simpan konfigurasi. Kunci dikirim ke Vault; field kosong
--    tidak menimpa yang lama; `clear_keys=true` melepas kunci (secret_id NULL).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_save_system_api_config(p_config jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_provider text := nullif(btrim(coalesce(p_config->>'provider_name','')),'');
  v_base text := nullif(btrim(coalesce(p_config->>'base_url','')),'');
  v_model text := nullif(btrim(coalesce(p_config->>'model_name','')),'');
  v_b1_base text := nullif(btrim(coalesce(p_config->>'backup1_base_url','')),'');
  v_b1_model text := nullif(btrim(coalesce(p_config->>'backup1_model_name','')),'');
  v_b2_base text := nullif(btrim(coalesce(p_config->>'backup2_base_url','')),'');
  v_b2_model text := nullif(btrim(coalesce(p_config->>'backup2_model_name','')),'');
  v_primary text := nullif(btrim(coalesce(p_config->>'primary_key','')),'');
  v_backup1 text := nullif(btrim(coalesce(p_config->>'backup_key_1','')),'');
  v_backup2 text := nullif(btrim(coalesce(p_config->>'backup_key_2','')),'');
  v_clear_keys boolean := coalesce((p_config->>'clear_keys')::boolean, false);
  v_active boolean := coalesce((p_config->>'is_active')::boolean, true);
  rec record;
  v_found boolean;
  v_primary_id uuid;
  v_backup1_id uuid;
  v_backup2_id uuid;
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  IF v_provider IS NULL THEN v_provider := 'custom_llm'; END IF;

  SELECT * INTO rec FROM public.system_api_configs
  WHERE provider_name = v_provider
  ORDER BY updated_at DESC NULLS LAST
  LIMIT 1;
  v_found := FOUND;

  IF v_found THEN
    v_primary_id := rec.primary_secret_id;
    v_backup1_id := rec.backup1_secret_id;
    v_backup2_id := rec.backup2_secret_id;
  ELSE
    v_primary_id := NULL;
    v_backup1_id := NULL;
    v_backup2_id := NULL;
  END IF;

  IF v_clear_keys THEN
    v_primary_id := NULL;
    v_backup1_id := NULL;
    v_backup2_id := NULL;
  ELSE
    IF v_primary IS NOT NULL THEN
      v_primary_id := public.vault_put_secret(v_primary, 'kasirgo system_api primary', v_primary_id);
    END IF;
    IF v_backup1 IS NOT NULL THEN
      v_backup1_id := public.vault_put_secret(v_backup1, 'kasirgo system_api backup1', v_backup1_id);
    END IF;
    IF v_backup2 IS NOT NULL THEN
      v_backup2_id := public.vault_put_secret(v_backup2, 'kasirgo system_api backup2', v_backup2_id);
    END IF;
  END IF;

  IF NOT v_found THEN
    INSERT INTO public.system_api_configs
      (provider_name, base_url, model_name,
       backup1_base_url, backup1_model_name, backup2_base_url, backup2_model_name,
       primary_secret_id, backup1_secret_id, backup2_secret_id, is_active)
    VALUES
      (v_provider, v_base, v_model,
       v_b1_base, v_b1_model, v_b2_base, v_b2_model,
       v_primary_id, v_backup1_id, v_backup2_id, v_active);
  ELSE
    UPDATE public.system_api_configs SET
      base_url           = COALESCE(v_base, base_url),
      model_name         = COALESCE(v_model, model_name),
      backup1_base_url   = COALESCE(v_b1_base, backup1_base_url),
      backup1_model_name = COALESCE(v_b1_model, backup1_model_name),
      backup2_base_url   = COALESCE(v_b2_base, backup2_base_url),
      backup2_model_name = COALESCE(v_b2_model, backup2_model_name),
      primary_secret_id  = v_primary_id,
      backup1_secret_id  = v_backup1_id,
      backup2_secret_id  = v_backup2_id,
      is_active          = v_active,
      updated_at         = now()
    WHERE id = rec.id;
  END IF;

  RETURN public.admin_get_system_api_config();
END $$;
GRANT EXECUTE ON FUNCTION public.admin_save_system_api_config(jsonb) TO authenticated;

COMMIT;

-- =============================================================================
-- VERIFIKASI:
--   SELECT public.admin_get_system_api_config();  -- superadmin, has_config:false
--   -- Simpan: SELECT admin_save_system_api_config('{"base_url":"https://api.a.com/v1",
--   --   "model_name":"m1","primary_key":"k-prim","backup1_base_url":"https://api.b.com/v1",
--   --   "backup1_model_name":"m2","backup_key_1":"k-b1"}'::jsonb);
--   -- Pastikan tidak ada kolom primary_key tersisa:
--   SELECT column_name FROM information_schema.columns
--   WHERE table_name='system_api_configs' AND column_name LIKE '%key';
-- =============================================================================