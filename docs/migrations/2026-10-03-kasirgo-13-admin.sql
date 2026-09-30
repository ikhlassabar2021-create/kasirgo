-- ============================================================================
-- KASIRGO PHASE 13 MIGRATION — Superadmin "Outlet Terdaftar", Fitur Utama,
-- Laporan Utama (manual verification, plan, per-outlet feature toggles,
-- staff/account management, per-outlet + platform reports).
-- Tanggal: 2026-10-03
--
-- CARA PAKAI: Supabase Dashboard -> SQL Editor -> tempel semua -> RUN.
-- Aman dijalankan berulang (idempotent).
--
-- Prasyarat: Phase 7.8 (supporters/entitlements/outlet_kyc), Phase 11
-- (platform_is_admin, log_admin_action, feature_flags_for_outlet).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Per-outlet module overrides (Fitur Utama per outlet dari superadmin).
--    Prioritas TERTINGGI di atas feature_flags global/segment/tipe.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.outlet_module_overrides (
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  module_key TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT FALSE,
  updated_by UUID,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (outlet_id, module_key)
);

ALTER TABLE public.outlet_module_overrides ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin all outlet_module_overrides" ON public.outlet_module_overrides;
CREATE POLICY "Admin all outlet_module_overrides"
  ON public.outlet_module_overrides
  FOR ALL USING (public.is_platform_admin())
  WITH CHECK (public.is_platform_admin());

-- Owner boleh membaca override outlet sendiri (app offline-safe).
DROP POLICY IF EXISTS "Owner read own outlet_module_overrides" ON public.outlet_module_overrides;
CREATE POLICY "Owner read own outlet_module_overrides"
  ON public.outlet_module_overrides FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.outlets o
                 WHERE o.id = outlet_module_overrides.outlet_id
                   AND o.owner_id = auth.uid()));

CREATE INDEX IF NOT EXISTS idx_outlet_module_overrides_outlet
  ON public.outlet_module_overrides(outlet_id);

-- Evaluasi flag efektif per outlet: feature_flags -> overrides per outlet.
CREATE OR REPLACE FUNCTION public.feature_flags_for_outlet(p_outlet_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_type text;
  v_out jsonb := '{}'::jsonb;
  f RECORD;
  ov RECORD;
  v_on boolean;
BEGIN
  SELECT lower(o.type) INTO v_type FROM public.outlets o WHERE o.id = p_outlet_id;

  FOR f IN SELECT * FROM public.feature_flags LOOP
    v_on := f.enabled;
    IF v_on AND COALESCE(f.rollout_pct, 100) < 100 THEN
      v_on := (mod(abs(hashtext(p_outlet_id::text)), 100) < COALESCE(f.rollout_pct, 100));
    END IF;
    IF v_on AND jsonb_array_length(COALESCE(f.outlet_types, '[]'::jsonb)) > 0 THEN
      v_on := v_type IS NOT NULL AND (
        SELECT bool_or(lower(elem) = v_type)
        FROM jsonb_array_elements_text(f.outlet_types) elem);
    END IF;
    IF v_on AND jsonb_array_length(COALESCE(f.segments, '[]'::jsonb)) > 0 THEN
      v_on := EXISTS (
        SELECT 1 FROM public.outlet_segments os
        WHERE os.outlet_id = p_outlet_id
          AND os.segment_id::text IN (
            SELECT jsonb_array_elements_text(f.segments)));
    END IF;
    v_out := v_out || jsonb_build_object(f.key, v_on);
  END LOOP;

  -- Override per-outlet menang (prioritas tertinggi).
  FOR ov IN SELECT module_key, enabled
            FROM public.outlet_module_overrides WHERE outlet_id = p_outlet_id LOOP
    v_out := v_out || jsonb_build_object(ov.module_key, ov.enabled);
  END LOOP;

  RETURN v_out;
END;
$$;
GRANT EXECUTE ON FUNCTION public.feature_flags_for_outlet(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Outlet Terdaftar: daftar outlet (default: KYC verified) + verifikasi manual
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_outlets_list(
  p_search text DEFAULT NULL, p_kyc text DEFAULT 'verified',
  p_plan text DEFAULT 'all', p_limit int DEFAULT 25, p_offset int DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN (
    WITH base AS (
      SELECT
        o.id AS outlet_id, o.name AS outlet_name, o.type AS outlet_type,
        o.address, o.phone, o.created_at,
        o.owner_id AS user_id,
        COALESCE(u.raw_user_meta_data->>'name', u.raw_user_meta_data->>'full_name', '') AS owner_name,
        u.email,
        COALESCE(k.status, 'unsubmitted') AS kyc_status,
        k.auto_verified, k.reject_reason, k.verified_at,
        COALESCE(e.is_supporter, FALSE) AS is_supporter,
        (e.trial_ends_at IS NOT NULL AND e.trial_ends_at > NOW()) AS on_trial,
        e.trial_ends_at,
        COALESCE(s.status, 'free') AS supp_status,
        (SELECT count(*) FROM public.user_roles ur WHERE ur.outlet_id = o.id) AS staff_count,
        (SELECT count(*) FROM public.transactions t WHERE t.outlet_id = o.id) AS tx_count,
        COALESCE((SELECT sum(t.final_amount) FROM public.transactions t
                  WHERE t.outlet_id = o.id AND t.order_status <> 'batal'), 0) AS omzet_total
      FROM public.outlets o
      LEFT JOIN auth.users u ON u.id = o.owner_id
      LEFT JOIN public.outlet_kyc k ON k.outlet_id = o.id
      LEFT JOIN public.entitlements e ON e.outlet_id = o.id
      LEFT JOIN public.supporters s ON s.outlet_id = o.id
        AND s.status IN ('active','trial')
    ),
    filtered AS (
      SELECT * FROM base
      WHERE (p_search IS NULL OR p_search = ''
             OR outlet_name ILIKE '%' || p_search || '%'
             OR owner_name ILIKE '%' || p_search || '%'
             OR COALESCE(email,'') ILIKE '%' || p_search || '%')
        AND (p_kyc = 'all'
             OR (p_kyc = 'verified' AND kyc_status = 'verified')
             OR (p_kyc = 'pending' AND kyc_status IN ('pending_review','draft','unsubmitted','belum'))
             OR (p_kyc = 'rejected' AND kyc_status = 'rejected'))
        AND (p_plan = 'all'
             OR (p_plan = 'supporter' AND is_supporter)
             OR (p_plan = 'trial' AND NOT is_supporter AND on_trial)
             OR (p_plan = 'free' AND NOT is_supporter AND NOT on_trial))
    ),
    paged AS (
      SELECT * FROM filtered ORDER BY created_at DESC
      LIMIT GREATEST(LEAST(p_limit, 100), 1) OFFSET GREATEST(p_offset, 0)
    )
    SELECT jsonb_build_object(
      'total', (SELECT count(*) FROM filtered),
      'rows', COALESCE((SELECT jsonb_agg(to_jsonb(f) ORDER BY f.created_at DESC) FROM paged f), '[]'::jsonb)
    )
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_outlets_list(text, text, text, int, int) TO authenticated;

-- Verifikasi manual KYC per outlet.
CREATE OR REPLACE FUNCTION public.platform_outlet_set_verification(
  p_outlet_id uuid, p_status text, p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_status text := CASE WHEN p_status IN ('verified','rejected','pending_review')
                        THEN p_status ELSE 'pending_review' END;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.outlet_kyc (outlet_id, status, auto_verified, reject_reason,
                                verified_at, updated_at)
  VALUES (p_outlet_id, v_status, v_status = 'verified',
          CASE WHEN v_status = 'rejected' THEN p_reason ELSE NULL END,
          CASE WHEN v_status = 'verified' THEN NOW() ELSE NULL END, NOW())
  ON CONFLICT (outlet_id) DO UPDATE SET
    status = EXCLUDED.status,
    auto_verified = EXCLUDED.auto_verified,
    reject_reason = EXCLUDED.reject_reason,
    verified_at = EXCLUDED.verified_at,
    updated_at = NOW();

  PERFORM public.log_admin_action('outlet.kyc_set', p_outlet_id::text,
    jsonb_build_object('status', v_status, 'reason', p_reason));
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_outlet_set_verification(uuid, text, text) TO authenticated;

-- Paket langganan per outlet: trial | free | pendukung (default otomatis).
CREATE OR REPLACE FUNCTION public.platform_outlet_set_plan(
  p_outlet_id uuid, p_plan text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_plan text := CASE WHEN p_plan IN ('trial','free','pendukung') THEN p_plan ELSE 'free' END;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF v_plan = 'pendukung' THEN
    INSERT INTO public.entitlements (outlet_id, is_supporter, trial_ends_at, updated_at)
    VALUES (p_outlet_id, TRUE, NULL, NOW())
    ON CONFLICT (outlet_id) DO UPDATE SET
      is_supporter = TRUE, trial_ends_at = NULL, updated_at = NOW();

    INSERT INTO public.supporters (outlet_id, tier, amount, status, start_date, end_date, updated_at)
    VALUES (p_outlet_id, 'pendukung', 50000, 'active', NOW(), NOW() + interval '30 days', NOW());
  ELSIF v_plan = 'trial' THEN
    INSERT INTO public.entitlements (outlet_id, is_supporter, trial_ends_at, updated_at)
    VALUES (p_outlet_id, FALSE, NOW() + interval '14 days', NOW())
    ON CONFLICT (outlet_id) DO UPDATE SET
      is_supporter = FALSE, trial_ends_at = NOW() + interval '14 days', updated_at = NOW();

    INSERT INTO public.supporters (outlet_id, tier, amount, status, trial_started_at, updated_at)
    VALUES (p_outlet_id, 'pendukung', 50000, 'trial', NOW(), NOW());
  ELSE
    INSERT INTO public.entitlements (outlet_id, is_supporter, trial_ends_at, updated_at)
    VALUES (p_outlet_id, FALSE, NULL, NOW())
    ON CONFLICT (outlet_id) DO UPDATE SET
      is_supporter = FALSE, trial_ends_at = NULL, updated_at = NOW();

    INSERT INTO public.supporters (outlet_id, tier, amount, status, updated_at)
    VALUES (p_outlet_id, 'pendukung', 50000, 'expired', NOW());
  END IF;

  PERFORM public.log_admin_action('outlet.plan_set', p_outlet_id::text,
    jsonb_build_object('plan', v_plan));
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_outlet_set_plan(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Fitur Utama per outlet: baca & set module_x
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_outlet_features(p_outlet_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN jsonb_build_object(
    'effective', public.feature_flags_for_outlet(p_outlet_id),
    'overrides', COALESCE((
      SELECT jsonb_object_agg(module_key, enabled)
      FROM public.outlet_module_overrides WHERE outlet_id = p_outlet_id), '{}'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_outlet_features(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.platform_outlet_set_feature(
  p_outlet_id uuid, p_key text, p_enabled boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.outlet_module_overrides (outlet_id, module_key, enabled, updated_by, updated_at)
  VALUES (p_outlet_id, p_key, p_enabled, auth.uid(), NOW())
  ON CONFLICT (outlet_id, module_key) DO UPDATE SET
    enabled = EXCLUDED.enabled, updated_by = auth.uid(), updated_at = NOW();

  PERFORM public.log_admin_action('outlet.feature_set', p_outlet_id::text,
    jsonb_build_object('key', p_key, 'enabled', p_enabled));
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_outlet_set_feature(uuid, text, boolean) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Staf & hapus akun per outlet
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_outlet_staff(p_outlet_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN jsonb_build_object(
    'rows', COALESCE((
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.role, x.email)
      FROM (
        SELECT ur.user_id, ur.role, ur.created_at,
               COALESCE(u.email, '(tanpa email)') AS email
        FROM public.user_roles ur
        LEFT JOIN auth.users u ON u.id = ur.user_id
        WHERE ur.outlet_id = p_outlet_id
      ) x), '[]'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_outlet_staff(uuid) TO authenticated;

-- Hapus akun staf (user_roles milik outlet). Bukan hapus auth.users.
CREATE OR REPLACE FUNCTION public.platform_outlet_remove_staff(
  p_outlet_id uuid, p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  DELETE FROM public.user_roles
  WHERE outlet_id = p_outlet_id AND user_id = p_user_id;

  PERFORM public.log_admin_action('outlet.staff_remove', p_outlet_id::text,
    jsonb_build_object('user_id', p_user_id));
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_outlet_remove_staff(uuid, uuid) TO authenticated;

-- Hapus AKUN owner + outlet (cascade). Sangat berbahaya: hanya superadmin.
CREATE OR REPLACE FUNCTION public.platform_outlet_delete_account(p_outlet_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_owner uuid;
  v_name text;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT owner_id, name INTO v_owner, v_name FROM public.outlets WHERE id = p_outlet_id;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'outlet_not_found'; END IF;

  PERFORM public.log_admin_action('outlet.delete_account', p_outlet_id::text,
    jsonb_build_object('owner_id', v_owner, 'outlet_name', v_name,
                       'state', 'deleting'));

  -- Hapus outlet (cascade data terkait) lalu akun auth owner.
  DELETE FROM public.outlets WHERE id = p_outlet_id;
  DELETE FROM auth.users WHERE id = v_owner;
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_outlet_delete_account(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 5. Laporan per outlet (omset/untung/rata2/jumlah) dari POS+PPOB+PG+B2B+
--    komisi asuransi & modal usaha (fintech).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_outlet_report(
  p_outlet_id uuid, p_start timestamptz, p_end timestamptz)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_pos_omzet numeric := 0;
  v_pos_tx int := 0;
  v_ppob_sales numeric := 0;
  v_ppob_profit numeric := 0;
  v_ppob_tx int := 0;
  v_pg_margin numeric := 0;
  v_pg_tx int := 0;
  v_b2b numeric := 0;
  v_b2b_tx int := 0;
  v_ins numeric := 0;
  v_ins_tx int := 0;
  v_fin numeric := 0;
  v_fin_tx int := 0;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COALESCE(sum(final_amount),0), count(*) INTO v_pos_omzet, v_pos_tx
  FROM public.transactions
  WHERE outlet_id = p_outlet_id AND order_status <> 'batal'
    AND created_at >= p_start AND created_at <= p_end;

  SELECT COALESCE(sum(amount),0), COALESCE(sum(profit),0), count(*)
    INTO v_ppob_sales, v_ppob_profit, v_ppob_tx
  FROM public.ppob_transactions
  WHERE outlet_id = p_outlet_id AND status = 'success'
    AND created_at >= p_start AND created_at <= p_end;

  -- Margin Payment Gateway (QRIS) dari billing_events event 'qris_margin'.
  SELECT COALESCE(sum(amount),0), count(*) INTO v_pg_margin, v_pg_tx
  FROM public.billing_events
  WHERE outlet_id = p_outlet_id AND event IN ('qris_margin','ads','sponsored_receipt','other')
    AND created_at >= p_start AND created_at <= p_end;

  SELECT COALESCE(sum(commission),0), count(*) INTO v_b2b, v_b2b_tx
  FROM public.restock_orders
  WHERE outlet_id = p_outlet_id AND status IN ('pending','confirmed','shipped','completed')
    AND created_at >= p_start AND created_at <= p_end;

  SELECT COALESCE(sum(commission),0), count(*) INTO v_ins, v_ins_tx
  FROM public.insurance_leads
  WHERE outlet_id = p_outlet_id AND status IN ('apply','approved')
    AND created_at >= p_start AND created_at <= p_end;

  SELECT COALESCE(sum(amount_requested),0), count(*) INTO v_fin, v_fin_tx
  FROM public.fintech_leads
  WHERE outlet_id = p_outlet_id AND status IN ('apply','approved')
    AND created_at >= p_start AND created_at <= p_end;

  RETURN jsonb_build_object(
    'outlet_id', p_outlet_id,
    'start', p_start, 'end', p_end,
    'pos', jsonb_build_object('omzet', v_pos_omzet, 'count', v_pos_tx),
    'ppob', jsonb_build_object('omzet', v_ppob_sales, 'untung', v_ppob_profit, 'count', v_ppob_tx),
    'pg', jsonb_build_object('untung', v_pg_margin, 'count', v_pg_tx),
    'b2b', jsonb_build_object('komisi', v_b2b, 'count', v_b2b_tx),
    'insurance', jsonb_build_object('komisi', v_ins, 'count', v_ins_tx),
    'fintech', jsonb_build_object('pengajuan', v_fin, 'count', v_fin_tx),
    'omzet_total', v_pos_omzet + v_ppob_sales,
    'untung_total', v_ppob_profit + v_pg_margin + v_b2b + v_ins,
    'count_total', v_pos_tx + v_ppob_tx + v_pg_tx + v_b2b_tx + v_ins_tx
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_outlet_report(uuid, timestamptz, timestamptz) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6. Laporan Utama platform: jumlah plan + keuntungan pendukung + omset/untung
--    PPOB & PG (Payment Gateway/QRIS).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_main_report(
  p_days int DEFAULT 30)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_start timestamptz := NOW() - make_interval(days => GREATEST(p_days, 1));
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN jsonb_build_object(
    'period_days', GREATEST(p_days, 1),
    'plans', jsonb_build_object(
      'trial', (SELECT count(*) FROM public.entitlements
                WHERE trial_ends_at IS NOT NULL AND trial_ends_at > NOW()
                  AND COALESCE(is_supporter, FALSE) = FALSE),
      'free', (SELECT count(*) FROM public.outlets o
               WHERE NOT EXISTS (SELECT 1 FROM public.entitlements e
                                 WHERE e.outlet_id = o.id
                                   AND (COALESCE(e.is_supporter,FALSE) = TRUE
                                        OR (e.trial_ends_at IS NOT NULL AND e.trial_ends_at > NOW())))),
      'pendukung', (SELECT count(*) FROM public.entitlements WHERE COALESCE(is_supporter,FALSE) = TRUE)
    ),
    'pendukung', jsonb_build_object(
      'revenue_period', COALESCE((SELECT sum(amount) FROM public.billing_events
                                  WHERE event = 'supporter' AND created_at >= v_start), 0),
      'mrr', COALESCE((SELECT sum(amount) FROM public.supporters
                       WHERE status = 'active'
                         AND (end_date IS NULL OR end_date >= NOW())), 0),
      'active', (SELECT count(*) FROM public.supporters WHERE status = 'active')
    ),
    'ppob', jsonb_build_object(
      'omzet', COALESCE((SELECT sum(amount) FROM public.ppob_transactions
                         WHERE status = 'success' AND created_at >= v_start), 0),
      'untung', COALESCE((SELECT sum(profit) FROM public.ppob_transactions
                          WHERE status = 'success' AND created_at >= v_start), 0),
      'count', (SELECT count(*) FROM public.ppob_transactions
                WHERE status = 'success' AND created_at >= v_start)
    ),
    'pg', jsonb_build_object(
      'untung', COALESCE((SELECT sum(amount) FROM public.billing_events
                          WHERE event IN ('qris_margin','ads','sponsored_receipt','other')
                            AND created_at >= v_start), 0),
      'count', (SELECT count(*) FROM public.billing_events
                WHERE event IN ('qris_margin','ads','sponsored_receipt','other')
                  AND created_at >= v_start)
    )
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_main_report(int) TO authenticated;

-- ============================================================================
-- VERIFIKASI:
--   SELECT public.platform_main_report(30);
--   SELECT public.platform_outlets_list(NULL,'verified','all',5,0);
-- ============================================================================