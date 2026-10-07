-- Phase 14 ST14-3/ST14-12 lengkap: unlimited token + kuota token per outlet.
-- Menambah kolom unlimited_tokens + token_quota pada outlet_ai_configs dan
-- memperbarui RPC admin (list menyertakan field; set menyimpannya).
-- Aturan: unlimited_tokens ON -> kuota dilewati (tetap dicatat);
--         OFF -> pakai token_quota (bila null -> kuota global rate_limit.tokens_per_day).

-- 1. Kolom baru.
ALTER TABLE public.outlet_ai_configs
  ADD COLUMN IF NOT EXISTS unlimited_tokens BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS token_quota INT;

-- 2. Daftar outlet + status override AI (ter-mask) — tambah field baru.
CREATE OR REPLACE FUNCTION public.admin_list_outlet_ai_configs()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE res jsonb;
BEGIN
  IF NOT public.is_platform_admin() THEN
    RETURN jsonb_build_object('forbidden', true);
  END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'outlet_id', o.id,
    'outlet_name', o.name,
    'has_config', (c.outlet_id IS NOT NULL),
    'is_active', coalesce(c.is_active, false),
    'provider', c.provider,
    'base_url', c.base_url,
    'model', c.model,
    'temperature', c.temperature,
    'max_tokens', c.max_tokens,
    'unlimited_tokens', coalesce(c.unlimited_tokens, false),
    'token_quota', c.token_quota,
    'has_api_key', (c.api_key_enc IS NOT NULL),
    'last_tested_at', c.last_tested_at,
    'last_test_result', c.last_test_result
  ) ORDER BY o.name), '[]'::jsonb) INTO res
  FROM public.outlets o
  LEFT JOIN public.outlet_ai_configs c ON c.outlet_id = o.id;
  RETURN res;
END $$;
GRANT EXECUTE ON FUNCTION public.admin_list_outlet_ai_configs() TO authenticated;

-- 3. Simpan/ubah override provider AI satu outlet (tambah unlimited/kuota).
CREATE OR REPLACE FUNCTION public.admin_set_outlet_ai_config(p_outlet uuid, p_config jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN
    RETURN jsonb_build_object('forbidden', true);
  END IF;
  INSERT INTO public.outlet_ai_configs(
    outlet_id, provider, base_url, api_key_enc, model, temperature, max_tokens,
    is_active, unlimited_tokens, token_quota, updated_at)
  VALUES (
    p_outlet,
    nullif(p_config->>'provider', ''),
    nullif(p_config->>'base_url', ''),
    nullif(p_config->>'api_key', ''),
    nullif(p_config->>'model', ''),
    coalesce((p_config->>'temperature')::numeric, 0.7),
    coalesce((p_config->>'max_tokens')::int, 800),
    coalesce((p_config->>'is_active')::boolean, false),
    coalesce((p_config->>'unlimited_tokens')::boolean, false),
    nullif(p_config->>'token_quota', '')::int,
    now())
  ON CONFLICT (outlet_id) DO UPDATE SET
    provider = excluded.provider,
    base_url = excluded.base_url,
    api_key_enc = coalesce(excluded.api_key_enc, public.outlet_ai_configs.api_key_enc),
    model = excluded.model,
    temperature = excluded.temperature,
    max_tokens = excluded.max_tokens,
    is_active = excluded.is_active,
    unlimited_tokens = excluded.unlimited_tokens,
    token_quota = excluded.token_quota,
    updated_at = now();
  PERFORM public.log_admin_action('outlet_ai_config.set', p_outlet::text,
    jsonb_build_object('is_active', p_config->>'is_active',
                       'unlimited_tokens', p_config->>'unlimited_tokens',
                       'token_quota', p_config->>'token_quota',
                       'has_key', (p_config->>'api_key') IS NOT NULL));
  RETURN jsonb_build_object('success', true);
END $$;
GRANT EXECUTE ON FUNCTION public.admin_set_outlet_ai_config(uuid, jsonb) TO authenticated;
