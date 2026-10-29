-- Pool token AI Dokter Bisnis: maksimal 5 akun/provider key (batas provider AI).
-- Setiap slot berisi API key + model; otomatis ditugaskan ke satu outlet saat
-- outlet membuka Dokter Bisnis AI (1 key = 1 akun/outlet). Bila 5/5 terpakai,
-- outlet baru mendapat status pool_full (notifikasi token sudah maksimal).
-- API key TIDAK pernah dikirim ke klien; hanya service_role (Edge Function).

CREATE TABLE IF NOT EXISTS public.doctor_ai_pool (
  slot_no int PRIMARY KEY,
  label text,
  provider text,
  base_url text,
  model text,
  api_key text,
  is_active boolean NOT NULL DEFAULT true,
  assigned_outlet_id uuid REFERENCES public.outlets(id) ON DELETE SET NULL,
  assigned_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT doctor_ai_pool_slot_check CHECK (slot_no BETWEEN 1 AND 5)
);

ALTER TABLE public.doctor_ai_pool ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.doctor_ai_pool FROM anon, authenticated;

INSERT INTO public.doctor_ai_pool(slot_no)
SELECT generate_series(1, 5)
ON CONFLICT (slot_no) DO NOTHING;

-- 1. Daftar 5 slot (ter-mask, tanpa API key penuh).
CREATE OR REPLACE FUNCTION public.admin_list_doctor_ai_pool()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE res jsonb;
BEGIN
  IF NOT public.is_platform_admin() THEN
    RETURN jsonb_build_object('forbidden', true);
  END IF;
  SELECT jsonb_build_object(
    'max', 5,
    'used', (SELECT count(*) FROM public.doctor_ai_pool
             WHERE api_key IS NOT NULL AND length(btrim(api_key)) > 0),
    'active', (SELECT count(*) FROM public.doctor_ai_pool
               WHERE api_key IS NOT NULL AND length(btrim(api_key)) > 0 AND is_active),
    'assigned', (SELECT count(*) FROM public.doctor_ai_pool
                 WHERE assigned_outlet_id IS NOT NULL),
    'slots', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'slot_no', p.slot_no,
        'label', p.label,
        'provider', p.provider,
        'base_url', p.base_url,
        'model', p.model,
        'has_key', (p.api_key IS NOT NULL AND length(btrim(p.api_key)) > 0),
        'key_hint', CASE WHEN p.api_key IS NULL OR length(btrim(p.api_key)) = 0
                         THEN NULL ELSE '****' || right(p.api_key, 4) END,
        'is_active', p.is_active,
        'assigned_outlet_id', p.assigned_outlet_id,
        'assigned_outlet_name', o.name,
        'assigned_at', p.assigned_at,
        'updated_at', p.updated_at
      ) ORDER BY p.slot_no)
      FROM public.doctor_ai_pool p
      LEFT JOIN public.outlets o ON o.id = p.assigned_outlet_id
    ), '[]'::jsonb)
  ) INTO res;
  RETURN res;
END $$;
GRANT EXECUTE ON FUNCTION public.admin_list_doctor_ai_pool() TO authenticated;

-- 2. Simpan satu slot (api_key hanya ditimpa bila dikirim; clear_key=true menghapus).
CREATE OR REPLACE FUNCTION public.admin_save_doctor_ai_pool(p_slot int, p_config jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_key text := nullif(btrim(coalesce(p_config->>'api_key', '')), '');
  v_clear boolean := coalesce((p_config->>'clear_key')::boolean, false);
  v_used int;
BEGIN
  IF NOT public.is_platform_admin() THEN
    RETURN jsonb_build_object('forbidden', true);
  END IF;
  IF p_slot IS NULL OR p_slot < 1 OR p_slot > 5 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Slot harus 1 sampai 5.');
  END IF;
  INSERT INTO public.doctor_ai_pool(slot_no) VALUES (p_slot)
  ON CONFLICT (slot_no) DO NOTHING;

  UPDATE public.doctor_ai_pool SET
    label = nullif(btrim(coalesce(p_config->>'label', '')), ''),
    provider = nullif(btrim(coalesce(p_config->>'provider', '')), ''),
    base_url = nullif(btrim(coalesce(p_config->>'base_url', '')), ''),
    model = nullif(btrim(coalesce(p_config->>'model', '')), ''),
    api_key = CASE WHEN v_clear THEN NULL
                   WHEN v_key IS NOT NULL THEN v_key
                   ELSE api_key END,
    is_active = coalesce((p_config->>'is_active')::boolean, true),
    updated_at = now()
  WHERE slot_no = p_slot;

  -- Slot tanpa key / nonaktif tidak boleh memegang outlet.
  IF EXISTS (SELECT 1 FROM public.doctor_ai_pool
             WHERE slot_no = p_slot
               AND (api_key IS NULL OR length(btrim(api_key)) = 0 OR NOT is_active)) THEN
    UPDATE public.doctor_ai_pool
    SET assigned_outlet_id = NULL, assigned_at = NULL
    WHERE slot_no = p_slot;
  END IF;

  SELECT count(*) INTO v_used FROM public.doctor_ai_pool
  WHERE api_key IS NOT NULL AND length(btrim(api_key)) > 0;

  PERFORM public.log_admin_action('doctor_ai_pool.save', p_slot::text,
    jsonb_build_object('has_key', v_key IS NOT NULL, 'cleared', v_clear,
                       'model', p_config->>'model', 'used', v_used));
  RETURN jsonb_build_object('success', true, 'used', v_used, 'max', 5,
                            'full', (v_used >= 5));
END $$;
GRANT EXECUTE ON FUNCTION public.admin_save_doctor_ai_pool(int, jsonb) TO authenticated;

-- 3. Lepas outlet dari slot (token tetap disimpan, siap dipakai akun lain).
CREATE OR REPLACE FUNCTION public.admin_release_doctor_ai_slot(p_slot int)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN
    RETURN jsonb_build_object('forbidden', true);
  END IF;
  UPDATE public.doctor_ai_pool
  SET assigned_outlet_id = NULL, assigned_at = NULL, updated_at = now()
  WHERE slot_no = p_slot;
  PERFORM public.log_admin_action('doctor_ai_pool.release', p_slot::text, '{}'::jsonb);
  RETURN jsonb_build_object('success', true);
END $$;
GRANT EXECUTE ON FUNCTION public.admin_release_doctor_ai_slot(int) TO authenticated;

-- 4. Tugaskan slot ke outlet tertentu (opsional, admin).
CREATE OR REPLACE FUNCTION public.admin_assign_doctor_ai_slot(p_slot int, p_outlet uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN
    RETURN jsonb_build_object('forbidden', true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.doctor_ai_pool
                 WHERE slot_no = p_slot AND api_key IS NOT NULL
                   AND length(btrim(api_key)) > 0 AND is_active) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Slot belum berisi token aktif.');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.outlets WHERE id = p_outlet) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Outlet tidak ditemukan.');
  END IF;
  UPDATE public.doctor_ai_pool
  SET assigned_outlet_id = NULL, assigned_at = NULL
  WHERE assigned_outlet_id = p_outlet AND slot_no <> p_slot;
  UPDATE public.doctor_ai_pool
  SET assigned_outlet_id = p_outlet, assigned_at = now(), updated_at = now()
  WHERE slot_no = p_slot;
  PERFORM public.log_admin_action('doctor_ai_pool.assign', p_slot::text,
    jsonb_build_object('outlet', p_outlet));
  RETURN jsonb_build_object('success', true);
END $$;
GRANT EXECUTE ON FUNCTION public.admin_assign_doctor_ai_slot(int, uuid) TO authenticated;

-- 5. Internal claim: outlet -> slot (buat penugasan otomatis bila masih ada).
CREATE OR REPLACE FUNCTION public.doctor_ai_claim_internal(p_outlet uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.doctor_ai_pool%rowtype;
  v_used int;
  v_max int := 5;
BEGIN
  SELECT * INTO v_row FROM public.doctor_ai_pool
  WHERE assigned_outlet_id = p_outlet
    AND api_key IS NOT NULL AND length(btrim(api_key)) > 0 AND is_active
  ORDER BY slot_no LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'slot_no', v_row.slot_no,
      'label', v_row.label, 'provider', v_row.provider, 'base_url', v_row.base_url,
      'model', v_row.model, 'api_key', v_row.api_key,
      'key_hint', '****' || right(v_row.api_key, 4), 'max', v_max);
  END IF;

  -- Bersihkan penugasan lama yang tidak valid untuk outlet ini.
  UPDATE public.doctor_ai_pool
  SET assigned_outlet_id = NULL, assigned_at = NULL
  WHERE assigned_outlet_id = p_outlet
    AND (api_key IS NULL OR length(btrim(api_key)) = 0 OR NOT is_active);

  UPDATE public.doctor_ai_pool p
  SET assigned_outlet_id = p_outlet, assigned_at = now(), updated_at = now()
  WHERE p.slot_no = (
    SELECT slot_no FROM public.doctor_ai_pool
    WHERE api_key IS NOT NULL AND length(btrim(api_key)) > 0
      AND is_active AND assigned_outlet_id IS NULL
    ORDER BY slot_no
    FOR UPDATE SKIP LOCKED
    LIMIT 1
  )
  RETURNING p.* INTO v_row;

  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'slot_no', v_row.slot_no,
      'label', v_row.label, 'provider', v_row.provider, 'base_url', v_row.base_url,
      'model', v_row.model, 'api_key', v_row.api_key,
      'key_hint', '****' || right(v_row.api_key, 4), 'max', v_max);
  END IF;

  SELECT count(*) INTO v_used FROM public.doctor_ai_pool
  WHERE api_key IS NOT NULL AND length(btrim(api_key)) > 0 AND is_active;

  IF v_used >= v_max THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'pool_full',
      'used', v_used, 'max', v_max,
      'message', 'Token AI sudah maksimal (5/5 akun).');
  END IF;
  RETURN jsonb_build_object('ok', false, 'reason', 'no_key',
    'used', v_used, 'max', v_max,
    'message', 'Belum ada token AI aktif.');
END $$;
REVOKE ALL ON FUNCTION public.doctor_ai_claim_internal(uuid) FROM PUBLIC, anon, authenticated;

-- 6. Claim publik (hanya service_role / Edge Function) -> mengembalikan API key.
CREATE OR REPLACE FUNCTION public.doctor_ai_claim(p_outlet uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN public.doctor_ai_claim_internal(p_outlet);
END $$;
REVOKE ALL ON FUNCTION public.doctor_ai_claim(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.doctor_ai_claim(uuid) TO service_role;

-- 7. Status untuk owner (otomatis menugaskan slot, tanpa membocorkan API key).
CREATE OR REPLACE FUNCTION public.doctor_ai_status(p_outlet uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_claim jsonb;
  v_used int;
BEGIN
  IF NOT (public.is_platform_admin()
          OR public.is_outlet_owner(p_outlet)
          OR EXISTS (SELECT 1 FROM public.user_roles
                     WHERE outlet_id = p_outlet AND user_id = auth.uid())) THEN
    RETURN jsonb_build_object('forbidden', true);
  END IF;
  v_claim := public.doctor_ai_claim_internal(p_outlet);
  SELECT count(*) INTO v_used FROM public.doctor_ai_pool
  WHERE api_key IS NOT NULL AND length(btrim(api_key)) > 0 AND is_active;
  IF coalesce((v_claim->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object(
      'mode', 'pool', 'assigned', true,
      'slot_no', v_claim->'slot_no', 'label', v_claim->'label',
      'provider', v_claim->'provider', 'model', v_claim->'model',
      'key_hint', v_claim->'key_hint',
      'used', v_used, 'max', 5, 'reason', NULL);
  END IF;
  RETURN jsonb_build_object(
    'mode', CASE WHEN v_claim->>'reason' = 'no_key' THEN 'global' ELSE 'none' END,
    'assigned', false, 'used', v_used, 'max', 5,
    'reason', v_claim->>'reason',
    'message', v_claim->>'message');
END $$;
GRANT EXECUTE ON FUNCTION public.doctor_ai_status(uuid) TO authenticated;
