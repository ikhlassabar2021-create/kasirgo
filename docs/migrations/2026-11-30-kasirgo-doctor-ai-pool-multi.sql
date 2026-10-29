-- Pool Token AI Dokter Bisnis v2: daftar token BEBAS (bukan 5 slot tetap).
-- Satu token/API key bisa dipakai maksimal 5 outlet (batas akun provider).
-- Untuk melayani ribuan outlet: tambah token baru -> otomatis dibagikan
-- (backfill) ke outlet yang belum punya token. API key hanya service_role.

DROP TABLE IF EXISTS public.doctor_ai_pool_assignments;
DROP TABLE IF EXISTS public.doctor_ai_pool;

CREATE TABLE public.doctor_ai_pool (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  label text,
  provider text,
  base_url text,
  model text,
  api_key text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.doctor_ai_pool_assignments (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  pool_id bigint NOT NULL REFERENCES public.doctor_ai_pool(id) ON DELETE CASCADE,
  outlet_id uuid NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT doctor_ai_pool_assignments_outlet_key UNIQUE (outlet_id)
);
CREATE INDEX IF NOT EXISTS idx_doctor_ai_pool_assignments_pool
  ON public.doctor_ai_pool_assignments(pool_id);

ALTER TABLE public.doctor_ai_pool ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctor_ai_pool_assignments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.doctor_ai_pool FROM anon, authenticated;
REVOKE ALL ON public.doctor_ai_pool_assignments FROM anon, authenticated;

-- Konstanta: satu token maksimal 5 outlet (batas akun provider).
CREATE OR REPLACE FUNCTION public.doctor_ai_pool_max_per_key()
RETURNS int LANGUAGE sql IMMUTABLE AS $$ SELECT 5 $$;
REVOKE ALL ON FUNCTION public.doctor_ai_pool_max_per_key() FROM PUBLIC, anon, authenticated;

-- 1. Daftar token (ter-mask) + kapasitas.
CREATE OR REPLACE FUNCTION public.admin_list_doctor_ai_pool()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE res jsonb;
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  SELECT jsonb_build_object(
    'max_per_key', public.doctor_ai_pool_max_per_key(),
    'tokens', (SELECT count(*) FROM public.doctor_ai_pool
               WHERE api_key IS NOT NULL AND length(btrim(api_key)) > 0),
    'connected_outlets', (SELECT count(*) FROM public.doctor_ai_pool_assignments),
    'capacity_used', (SELECT count(*) FROM public.doctor_ai_pool_assignments),
    'capacity_total', (SELECT count(*) FROM public.doctor_ai_pool
                       WHERE api_key IS NOT NULL AND length(btrim(api_key)) > 0)
                      * public.doctor_ai_pool_max_per_key(),
    'slots', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', p.id,
        'label', p.label, 'provider', p.provider, 'base_url', p.base_url,
        'model', p.model,
        'has_key', (p.api_key IS NOT NULL AND length(btrim(p.api_key)) > 0),
        'key_hint', CASE WHEN p.api_key IS NULL OR length(btrim(p.api_key)) = 0
                         THEN NULL ELSE '****' || right(p.api_key, 4) END,
        'is_active', p.is_active,
        'outlet_count', (SELECT count(*) FROM public.doctor_ai_pool_assignments a
                         WHERE a.pool_id = p.id),
        'full', (SELECT count(*) FROM public.doctor_ai_pool_assignments a
                 WHERE a.pool_id = p.id) >= public.doctor_ai_pool_max_per_key(),
        'outlets', coalesce((
          SELECT jsonb_agg(jsonb_build_object('outlet_id', a.outlet_id, 'outlet_name', o.name))
          FROM public.doctor_ai_pool_assignments a
          LEFT JOIN public.outlets o ON o.id = a.outlet_id
          WHERE a.pool_id = p.id), '[]'::jsonb),
        'updated_at', p.updated_at
      ) ORDER BY p.id::text)
      FROM public.doctor_ai_pool p
    ), '[]'::jsonb)
  ) INTO res;
  RETURN res;
END $$;
GRANT EXECUTE ON FUNCTION public.admin_list_doctor_ai_pool() TO authenticated;

-- 2. Tambah / ubah token. p_id NULL = tambah token baru.
CREATE OR REPLACE FUNCTION public.admin_save_doctor_ai_pool(p_id bigint, p_config jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_key text := nullif(btrim(coalesce(p_config->>'api_key', '')), '');
  v_clear boolean := coalesce((p_config->>'clear_key')::boolean, false);
  v_id bigint := p_id;
  v_tokens int; v_used int; v_cap int; v_backfill jsonb;
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;

  IF v_id IS NULL THEN
    INSERT INTO public.doctor_ai_pool(label, provider, base_url, model, api_key, is_active)
    VALUES (nullif(btrim(coalesce(p_config->>'label','')),''),
            nullif(btrim(coalesce(p_config->>'provider','')),''),
            nullif(btrim(coalesce(p_config->>'base_url','')),''),
            nullif(btrim(coalesce(p_config->>'model','')),''),
            CASE WHEN v_clear THEN NULL ELSE v_key END,
            coalesce((p_config->>'is_active')::boolean, true))
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.doctor_ai_pool SET
      label = nullif(btrim(coalesce(p_config->>'label','')),''),
      provider = nullif(btrim(coalesce(p_config->>'provider','')),''),
      base_url = nullif(btrim(coalesce(p_config->>'base_url','')),''),
      model = nullif(btrim(coalesce(p_config->>'model','')),''),
      api_key = CASE WHEN v_clear THEN NULL
                     WHEN v_key IS NOT NULL THEN v_key
                     ELSE api_key END,
      is_active = coalesce((p_config->>'is_active')::boolean, true),
      updated_at = now()
    WHERE id = v_id;
  END IF;

  -- Token tanpa key / nonaktif: lepas semua outletnya supaya bisa pindah.
  IF EXISTS (SELECT 1 FROM public.doctor_ai_pool
             WHERE id = v_id AND (api_key IS NULL OR length(btrim(api_key)) = 0 OR NOT is_active)) THEN
    DELETE FROM public.doctor_ai_pool_assignments WHERE pool_id = v_id;
  END IF;

  v_backfill := public.doctor_ai_pool_backfill_internal();

  SELECT count(*) INTO v_tokens FROM public.doctor_ai_pool
  WHERE api_key IS NOT NULL AND length(btrim(api_key)) > 0;
  SELECT count(*) INTO v_used FROM public.doctor_ai_pool_assignments;
  v_cap := v_tokens * public.doctor_ai_pool_max_per_key();

  PERFORM public.log_admin_action('doctor_ai_pool.save', v_id::text,
    jsonb_build_object('new_token', (p_id IS NULL), 'has_key', v_key IS NOT NULL,
                       'cleared', v_clear, 'model', p_config->>'model',
                       'backfill', v_backfill->>'assigned'));
  RETURN jsonb_build_object('success', true, 'id', v_id,
                            'tokens', v_tokens, 'connected_outlets', v_used,
                            'capacity_total', v_cap, 'global_full', (v_used >= v_cap));
END $$;
GRANT EXECUTE ON FUNCTION public.admin_save_doctor_ai_pool(bigint, jsonb) TO authenticated;

-- 3. Hapus token (outlet-nya dilepas lalu langsung di-backfill ke token lain).
CREATE OR REPLACE FUNCTION public.admin_delete_doctor_ai_token(p_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_backfill jsonb;
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  DELETE FROM public.doctor_ai_pool WHERE id = p_id;
  v_backfill := public.doctor_ai_pool_backfill_internal();
  PERFORM public.log_admin_action('doctor_ai_pool.delete', p_id::text,
    jsonb_build_object('backfill', v_backfill->>'assigned'));
  RETURN jsonb_build_object('success', true, 'backfill', v_backfill->>'assigned');
END $$;
GRANT EXECUTE ON FUNCTION public.admin_delete_doctor_ai_token(bigint) TO authenticated;

-- 4. Lepas satu outlet (bebas pindah ke token berkapasitas saat dibuka lagi).
CREATE OR REPLACE FUNCTION public.admin_release_doctor_ai_outlet(p_outlet uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  DELETE FROM public.doctor_ai_pool_assignments WHERE outlet_id = p_outlet;
  PERFORM public.log_admin_action('doctor_ai_pool.release_outlet', p_outlet::text, '{}'::jsonb);
  RETURN jsonb_build_object('success', true);
END $$;
GRANT EXECUTE ON FUNCTION public.admin_release_doctor_ai_outlet(uuid) TO authenticated;

-- 5. Backfill publik (admin): bagikan kapasitas kosong ke outlet yang belum dapat.
CREATE OR REPLACE FUNCTION public.doctor_ai_pool_backfill()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  RETURN public.doctor_ai_pool_backfill_internal();
END $$;
GRANT EXECUTE ON FUNCTION public.doctor_ai_pool_backfill() TO authenticated;

-- 5b. Inti backfill: assign outlet ber-profil (pernah buka Dokter) yang belum punya token.
CREATE OR REPLACE FUNCTION public.doctor_ai_pool_backfill_internal()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  tk record; o record; cap int; done int := 0;
BEGIN
  FOR tk IN (SELECT * FROM public.doctor_ai_pool
             WHERE api_key IS NOT NULL AND length(btrim(api_key)) > 0 AND is_active
             ORDER BY id) LOOP
    cap := public.doctor_ai_pool_max_per_key()
           - (SELECT count(*) FROM public.doctor_ai_pool_assignments a WHERE a.pool_id = tk.id);
    IF cap <= 0 THEN CONTINUE; END IF;
    FOR o IN (SELECT p.outlet_id FROM public.doctor_outlet_profile p
              WHERE NOT EXISTS (SELECT 1 FROM public.doctor_ai_pool_assignments a2
                                WHERE a2.outlet_id = p.outlet_id)
              ORDER BY p.updated_at ASC
              LIMIT cap) LOOP
      INSERT INTO public.doctor_ai_pool_assignments(pool_id, outlet_id)
      VALUES (tk.id, o.outlet_id)
      ON CONFLICT (outlet_id) DO NOTHING;
      done := done + 1;
    END LOOP;
  END LOOP;
  RETURN jsonb_build_object('success', true, 'assigned', done);
END $$;
REVOKE ALL ON FUNCTION public.doctor_ai_pool_backfill_internal() FROM PUBLIC, anon, authenticated;

-- 6. Claim internal: outlet -> token (assign on-demand + backfill spot).
CREATE OR REPLACE FUNCTION public.doctor_ai_claim_internal(p_outlet uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.doctor_ai_pool%rowtype;
  v_cap int; v_used int; v_tokens int;
BEGIN
  SELECT p.* INTO v_row
  FROM public.doctor_ai_pool p
  JOIN public.doctor_ai_pool_assignments a ON a.pool_id = p.id
  WHERE a.outlet_id = p_outlet AND p.api_key IS NOT NULL
    AND length(btrim(p.api_key)) > 0 AND p.is_active
  ORDER BY p.id LIMIT 1;
  IF FOUND THEN
    v_used := (SELECT count(*) FROM public.doctor_ai_pool_assignments a WHERE a.pool_id = v_row.id);
    RETURN jsonb_build_object('ok', true, 'id', v_row.id,
      'label', v_row.label, 'provider', v_row.provider, 'base_url', v_row.base_url,
      'model', v_row.model, 'api_key', v_row.api_key,
      'key_hint', '****' || right(v_row.api_key, 4),
      'used', v_used, 'max', public.doctor_ai_pool_max_per_key());
  END IF;

  -- Bersihkan penugasan outlet ini ke token yang kini tak valid.
  DELETE FROM public.doctor_ai_pool_assignments a
  WHERE a.outlet_id = p_outlet
    AND NOT EXISTS (SELECT 1 FROM public.doctor_ai_pool p
                    WHERE p.id = a.pool_id AND p.api_key IS NOT NULL
                      AND length(btrim(p.api_key)) > 0 AND p.is_active);

  SELECT p.* INTO v_row
  FROM public.doctor_ai_pool p
  WHERE p.api_key IS NOT NULL AND length(btrim(p.api_key)) > 0 AND p.is_active
    AND (SELECT count(*) FROM public.doctor_ai_pool_assignments a WHERE a.pool_id = p.id)
        < public.doctor_ai_pool_max_per_key()
  ORDER BY p.id
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF FOUND THEN
    INSERT INTO public.doctor_ai_pool_assignments(pool_id, outlet_id)
    VALUES (v_row.id, p_outlet)
    ON CONFLICT (outlet_id) DO NOTHING;
    v_used := (SELECT count(*) FROM public.doctor_ai_pool_assignments a WHERE a.pool_id = v_row.id);
    RETURN jsonb_build_object('ok', true, 'id', v_row.id,
      'label', v_row.label, 'provider', v_row.provider, 'base_url', v_row.base_url,
      'model', v_row.model, 'api_key', v_row.api_key,
      'key_hint', '****' || right(v_row.api_key, 4),
      'used', v_used, 'max', public.doctor_ai_pool_max_per_key());
  END IF;

  SELECT count(*) INTO v_tokens FROM public.doctor_ai_pool
  WHERE api_key IS NOT NULL AND length(btrim(api_key)) > 0 AND is_active;
  SELECT count(*) INTO v_used FROM public.doctor_ai_pool_assignments;
  IF v_tokens > 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'pool_full',
      'used', v_used, 'max', v_tokens * public.doctor_ai_pool_max_per_key(),
      'message', 'Token AI sudah maksimal (' || v_used || '/' || (v_tokens * public.doctor_ai_pool_max_per_key()) || ' outlet). Tambah token baru di admin.');
  END IF;
  RETURN jsonb_build_object('ok', false, 'reason', 'no_key', 'used', 0,
    'max', 0, 'message', 'Belum ada token AI aktif.');
END $$;
REVOKE ALL ON FUNCTION public.doctor_ai_claim_internal(uuid) FROM PUBLIC, anon, authenticated;

-- 7. Claim publik (service_role / Edge Function) -> mengembalikan API key.
CREATE OR REPLACE FUNCTION public.doctor_ai_claim(p_outlet uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN public.doctor_ai_claim_internal(p_outlet);
END $$;
REVOKE ALL ON FUNCTION public.doctor_ai_claim(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.doctor_ai_claim(uuid) TO service_role;

-- 8. Status untuk owner (otomatis menugaskan token, tanpa membocorkan key).
CREATE OR REPLACE FUNCTION public.doctor_ai_status(p_outlet uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_claim jsonb; v_used int; v_cap int;
BEGIN
  IF NOT (public.is_platform_admin()
          OR public.is_outlet_owner(p_outlet)
          OR EXISTS (SELECT 1 FROM public.user_roles
                     WHERE outlet_id = p_outlet AND user_id = auth.uid())) THEN
    RETURN jsonb_build_object('forbidden', true);
  END IF;
  v_claim := public.doctor_ai_claim_internal(p_outlet);
  SELECT count(*) INTO v_used FROM public.doctor_ai_pool_assignments;
  SELECT count(*) INTO v_cap FROM public.doctor_ai_pool
  WHERE api_key IS NOT NULL AND length(btrim(api_key)) > 0 AND is_active;
  v_cap := v_cap * public.doctor_ai_pool_max_per_key();
  IF coalesce((v_claim->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object(
      'mode', 'pool', 'assigned', true,
      'token_id', v_claim->'id', 'label', v_claim->'label',
      'provider', v_claim->'provider', 'model', v_claim->'model',
      'key_hint', v_claim->'key_hint',
      'used', v_claim->'used', 'max', public.doctor_ai_pool_max_per_key(),
      'capacity_used', v_used, 'capacity_total', v_cap, 'reason', NULL);
  END IF;
  RETURN jsonb_build_object(
    'mode', CASE WHEN v_claim->>'reason' = 'no_key' THEN 'global' ELSE 'none' END,
    'assigned', false, 'used', v_used, 'max', v_cap,
    'capacity_used', v_used, 'capacity_total', v_cap,
    'reason', v_claim->>'reason', 'message', v_claim->>'message');
END $$;
GRANT EXECUTE ON FUNCTION public.doctor_ai_status(uuid) TO authenticated;
