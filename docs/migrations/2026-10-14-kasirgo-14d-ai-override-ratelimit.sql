-- Phase 14 ST14-10: override provider AI per outlet (superadmin) + rate limit/kuota token.
-- RPC admin (SECURITY DEFINER, cek is_platform_admin) TIDAK pernah mengembalikan api_key.
-- RPC usage dipakai Edge Function (service_role) untuk rate limit.

-- 1. Daftar outlet + status override AI (ter-mask).
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
    'has_api_key', (c.api_key_enc IS NOT NULL),
    'last_tested_at', c.last_tested_at,
    'last_test_result', c.last_test_result
  ) ORDER BY o.name), '[]'::jsonb) INTO res
  FROM public.outlets o
  LEFT JOIN public.outlet_ai_configs c ON c.outlet_id = o.id;
  RETURN res;
END $$;
GRANT EXECUTE ON FUNCTION public.admin_list_outlet_ai_configs() TO authenticated;

-- 2. Simpan/ubah override provider AI satu outlet. api_key hanya ditimpa bila dikirim.
CREATE OR REPLACE FUNCTION public.admin_set_outlet_ai_config(p_outlet uuid, p_config jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN
    RETURN jsonb_build_object('forbidden', true);
  END IF;
  INSERT INTO public.outlet_ai_configs(
    outlet_id, provider, base_url, api_key_enc, model, temperature, max_tokens, is_active, updated_at)
  VALUES (
    p_outlet,
    nullif(p_config->>'provider', ''),
    nullif(p_config->>'base_url', ''),
    nullif(p_config->>'api_key', ''),
    nullif(p_config->>'model', ''),
    coalesce((p_config->>'temperature')::numeric, 0.7),
    coalesce((p_config->>'max_tokens')::int, 800),
    coalesce((p_config->>'is_active')::boolean, false),
    now())
  ON CONFLICT (outlet_id) DO UPDATE SET
    provider = excluded.provider,
    base_url = excluded.base_url,
    api_key_enc = coalesce(excluded.api_key_enc, public.outlet_ai_configs.api_key_enc),
    model = excluded.model,
    temperature = excluded.temperature,
    max_tokens = excluded.max_tokens,
    is_active = excluded.is_active,
    updated_at = now();
  PERFORM public.log_admin_action('outlet_ai_config.set', p_outlet::text,
    jsonb_build_object('is_active', p_config->>'is_active',
                       'has_key', (p_config->>'api_key') IS NOT NULL));
  RETURN jsonb_build_object('success', true);
END $$;
GRANT EXECUTE ON FUNCTION public.admin_set_outlet_ai_config(uuid, jsonb) TO authenticated;

-- 3. Hapus override (kembali ke provider global).
CREATE OR REPLACE FUNCTION public.admin_delete_outlet_ai_config(p_outlet uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN
    RETURN jsonb_build_object('forbidden', true);
  END IF;
  DELETE FROM public.outlet_ai_configs WHERE outlet_id = p_outlet;
  PERFORM public.log_admin_action('outlet_ai_config.delete', p_outlet::text, '{}'::jsonb);
  RETURN jsonb_build_object('success', true);
END $$;
GRANT EXECUTE ON FUNCTION public.admin_delete_outlet_ai_config(uuid) TO authenticated;

-- 4. Pemakaian 24 jam terakhir (untuk rate limit EF). service_role saja.
CREATE OR REPLACE FUNCTION public.doctor_daily_usage(target_outlet uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object(
    'messages', coalesce(count(*) FILTER (WHERE role = 'user'), 0),
    'tokens', coalesce(sum(tokens) FILTER (WHERE role = 'assistant'), 0)
  )
  FROM public.doctor_messages
  WHERE outlet_id = target_outlet AND created_at >= now() - interval '24 hours';
$$;
GRANT EXECUTE ON FUNCTION public.doctor_daily_usage(uuid) TO service_role;
