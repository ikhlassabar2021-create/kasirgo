-- ============================================================================
-- KasirGo 3.0 - Item 4: Trial default OFF + toggle superadmin
-- Tanggal: 2026-11-17
--
-- Tujuan: trial otomatis (reverse trial 14 hari) TIDAK lagi diberikan secara
-- default. Superadmin dapat mengaktifkan/mematikan via Control Plane
-- (platform_configs 'billing' -> trial_enabled, default false).
--
-- Perubahan:
--   1. Seed platform_configs 'billing' dengan trial_enabled=false (bila belum ada).
--   2. ensure_supporter_trial() menolak (no-op) bila trial_enabled != true.
--   3. RPC admin_set_trial_enabled(bool) khusus superadmin untuk toggle.
-- ============================================================================

-- 1. Seed/merge config billing (default trial_enabled=false).
INSERT INTO public.platform_configs (key, scope, value, version)
SELECT 'billing', 'global',
       jsonb_build_object(
         'supporter_price', 50000,
         'currency', 'IDR',
         'period', 'monthly',
         'trial_days', 14,
         'auto_renew_default', true,
         'trial_enabled', false
       ),
       1
WHERE NOT EXISTS (
  SELECT 1 FROM public.platform_configs WHERE key = 'billing' AND scope = 'global'
);

-- Pastikan key trial_enabled ada (merge tanpa menimpa nilai lain) bila config
-- sudah ada sebelumnya.
UPDATE public.platform_configs
SET value = jsonb_set(value, '{trial_enabled}',
              COALESCE(value->'trial_enabled', 'false'::jsonb), true),
    updated_at = now()
WHERE key = 'billing' AND scope = 'global'
  AND NOT (value ? 'trial_enabled');

-- 2. ensure_supporter_trial: hormati flag trial_enabled.
CREATE OR REPLACE FUNCTION public.ensure_supporter_trial(p_outlet UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_days INT;
  v_enabled BOOLEAN;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.outlets o WHERE o.id = p_outlet AND o.owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  -- Item 4: trial hanya bila superadmin mengaktifkannya.
  SELECT COALESCE((value->>'trial_enabled')::boolean, false) INTO v_enabled
  FROM (SELECT value FROM public.platform_configs WHERE key = 'billing'
        ORDER BY version DESC LIMIT 1) c;

  IF v_enabled IS NOT TRUE THEN
    RETURN jsonb_build_object('status', 'trial_disabled', 'trial_days', 0);
  END IF;

  SELECT COALESCE((value->>'trial_days')::int, 14) INTO v_days
  FROM (SELECT value FROM public.platform_configs WHERE key = 'billing'
        ORDER BY version DESC LIMIT 1) c;

  INSERT INTO public.entitlements (outlet_id, is_supporter, ad_free, features, trial_ends_at)
  VALUES (p_outlet, false, false, '{}'::jsonb, now() + make_interval(days => v_days))
  ON CONFLICT (outlet_id) DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM public.supporters WHERE outlet_id = p_outlet) THEN
    INSERT INTO public.supporters (
      outlet_id, tier, amount, status, trial_started_at,
      start_date, end_date, auto_renew)
    VALUES (
      p_outlet, 'pendukung', 0, 'trial', now(),
      now(), now() + make_interval(days => v_days), true);
  END IF;

  RETURN jsonb_build_object('status', 'trial', 'trial_days', v_days);
END;
$$;
GRANT EXECUTE ON FUNCTION public.ensure_supporter_trial(UUID) TO authenticated;

-- 3. RPC superadmin: set trial_enabled.
CREATE OR REPLACE FUNCTION public.admin_set_trial_enabled(p_value BOOLEAN)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  UPDATE public.platform_configs
  SET value = jsonb_set(value, '{trial_enabled}', to_jsonb(p_value), true),
      version = version + 1,
      updated_at = now()
  WHERE key = 'billing' AND scope = 'global';

  RETURN jsonb_build_object('success', true, 'trial_enabled', p_value);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_set_trial_enabled(BOOLEAN) TO authenticated;
