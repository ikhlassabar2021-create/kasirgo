-- ============================================================================
-- KASIRGO PHASE 11 MIGRATION (superadmin web: revenue, users, impersonate,
-- audit, backup, intelligence, config inheritance, RBAC, rules, monitoring)
-- Idempotent: aman dijalankan ulang.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. ST11-1: helper admin + RPC dashboard (revenue 12 engine, supporters,
--    users list server-side, user detail)
-- ---------------------------------------------------------------------------

-- Cek apakah user saat ini superadmin/pegawai admin aktif.
CREATE OR REPLACE FUNCTION public.platform_is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = auth.uid() AND is_active = TRUE
  );
$$;

-- Series pendapatan per engine (12 revenue engine) per bucket hari/bulan.
CREATE OR REPLACE FUNCTION public.platform_revenue_series(
  p_days int DEFAULT 30, p_granularity text DEFAULT 'day')
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_start timestamptz := NOW() - make_interval(days => GREATEST(p_days, 1));
  v_trunc text := CASE WHEN p_granularity = 'month' THEN 'month' ELSE 'day' END;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN (
    SELECT jsonb_agg(to_jsonb(x) ORDER BY x.bucket, x.engine)
    FROM (
      WITH buckets AS (
        SELECT generate_series(
                 date_trunc(v_trunc, v_start),
                 date_trunc(v_trunc, NOW()),
                 CASE WHEN v_trunc = 'month'
                      THEN '1 month'::interval ELSE '1 day'::interval END
               ) AS bucket
      ),
      engines(engine) AS (
        VALUES ('pendukung'), ('ppob_margin'), ('restock_b2b'),
               ('affiliate'), ('fintech'), ('insurance'),
               ('qris_margin'), ('ads'), ('sponsored_receipt'),
               ('storage'), ('hyperlocal'), ('other')
      ),
      amounts AS (
        -- Pendukung (langganan Rp50rb/bln)
        SELECT date_trunc(v_trunc, s.start_date) AS bucket, 'pendukung' AS engine,
               COALESCE(sum(s.amount), 0) AS amount
        FROM public.supporters s
        WHERE s.start_date >= v_start
        GROUP BY 1
        UNION ALL
        -- Margin PPOB
        SELECT date_trunc(v_trunc, p.created_at), 'ppob_margin',
               COALESCE(sum(p.profit), 0)
        FROM public.ppob_transactions p
        WHERE p.created_at >= v_start AND p.status = 'success'
        GROUP BY 1
        UNION ALL
        -- Komisi B2B restock
        SELECT date_trunc(v_trunc, r.created_at), 'restock_b2b',
               COALESCE(sum(r.commission), 0)
        FROM public.restock_orders r
        WHERE r.created_at >= v_start
          AND r.status IN ('pending','confirmed','shipped','completed')
        GROUP BY 1
        UNION ALL
        -- Komisi asuransi
        SELECT date_trunc(v_trunc, i.created_at), 'insurance',
               COALESCE(sum(i.commission), 0)
        FROM public.insurance_leads i
        WHERE i.created_at >= v_start
          AND i.status IN ('apply','approved')
        GROUP BY 1
        UNION ALL
        -- Billing events lain (qris_margin, ads, sponsored_receipt,
        -- affiliate, storage, hyperlocal, other)
        SELECT date_trunc(v_trunc, b.created_at), b.event, COALESCE(sum(b.amount), 0)
        FROM public.billing_events b
        WHERE b.created_at >= v_start
          AND b.event IN ('qris_margin','ads','sponsored_receipt',
                          'affiliate','storage','hyperlocal','other')
        GROUP BY 1, 2
      )
      SELECT bu.bucket::text AS bucket,
             e.engine,
             COALESCE(a.amount, 0) AS amount
      FROM buckets bu
      CROSS JOIN engines e
      LEFT JOIN amounts a ON a.bucket = bu.bucket AND a.engine = e.engine
    ) x
  );
END;
$$;

-- Rekap supporter (Program Pendukung Rp50rb/bln).
CREATE OR REPLACE FUNCTION public.platform_supporters_summary()
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
    'active', (SELECT count(*) FROM public.supporters
               WHERE status = 'active'
                 AND (end_date IS NULL OR end_date >= NOW())),
    'trial', (SELECT count(*) FROM public.supporters WHERE status = 'trial'),
    'mrr', COALESCE((SELECT sum(amount) FROM public.supporters
                     WHERE status = 'active'
                       AND (end_date IS NULL OR end_date >= NOW())), 0),
    'revenue_30d', COALESCE((SELECT sum(amount) FROM public.supporters
                             WHERE start_date >= NOW() - interval '30 days'), 0),
    'expired', (SELECT count(*) FROM public.supporters WHERE status = 'expired')
  );
END;
$$;

-- Daftar user+outlet dengan filter SERVER-SIDE (search/tier/status).
CREATE OR REPLACE FUNCTION public.platform_users_list(
  p_search text DEFAULT NULL, p_tier text DEFAULT 'all',
  p_status text DEFAULT 'all', p_limit int DEFAULT 25, p_offset int DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_rows jsonb;
  v_total int;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  WITH base AS (
    SELECT
      u.id AS user_id,
      COALESCE(u.raw_user_meta_data->>'name', u.raw_user_meta_data->>'full_name', '') AS name,
      u.email,
      o.id AS outlet_id,
      o.name AS outlet_name,
      o.type AS outlet_type,
      COALESCE(e.is_supporter, FALSE) AS is_supporter,
      COALESCE(e.ad_free, FALSE) AS ad_free,
      COALESCE(e.trial_ends_at IS NOT NULL AND e.trial_ends_at > NOW(), FALSE) AS on_trial,
      COALESCE(k.status, 'belum') AS kyc_status,
      COALESCE(s.status, 'free') AS payment_status,
      (SELECT count(*) FROM public.transactions t
        WHERE t.outlet_id = o.id) AS tx_count,
      u.created_at
    FROM auth.users u
    LEFT JOIN public.outlets o ON o.owner_id = u.id
    LEFT JOIN public.entitlements e ON e.outlet_id = o.id
    LEFT JOIN public.outlet_kyc k ON k.outlet_id = o.id
    LEFT JOIN public.supporters s ON s.outlet_id = o.id
       AND s.status IN ('active','trial')
    WHERE u.id IN (SELECT owner_id FROM public.outlets WHERE owner_id IS NOT NULL)
  ),
  filtered AS (
    SELECT * FROM base
    WHERE (p_search IS NULL OR p_search = ''
           OR name ILIKE '%' || p_search || '%'
           OR email ILIKE '%' || p_search || '%'
           OR COALESCE(outlet_name, '') ILIKE '%' || p_search || '%')
      AND (p_tier = 'all'
           OR (p_tier = 'supporter' AND is_supporter)
           OR (p_tier = 'trial' AND on_trial)
           OR (p_tier = 'free' AND NOT is_supporter AND NOT on_trial))
      AND (p_status = 'all'
           OR (p_status = 'kyc_verified' AND kyc_status = 'verified')
           OR (p_status = 'kyc_pending' AND kyc_status IN ('pending','belum'))
           OR (p_status = 'kyc_rejected' AND kyc_status = 'rejected')
           OR (p_status = 'paid' AND payment_status = 'active')
           OR (p_status = 'free' AND payment_status = 'free'))
  ),
  paged AS (
    SELECT * FROM filtered
    ORDER BY created_at DESC
    LIMIT GREATEST(LEAST(p_limit, 100), 1)
    OFFSET GREATEST(p_offset, 0)
  )
  SELECT jsonb_build_object(
    'total', (SELECT count(*) FROM filtered),
    'rows', COALESCE((
      SELECT jsonb_agg(to_jsonb(f) ORDER BY f.created_at DESC) FROM paged f
    ), '[]'::jsonb)
  ) INTO v_rows;

  RETURN v_rows;
END;
$$;

-- Detail satu user+outlet (utk halaman UserDetail).
CREATE OR REPLACE FUNCTION public.platform_user_detail(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_outlet uuid;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT o.id INTO v_outlet FROM public.outlets o WHERE o.owner_id = p_user_id;

  RETURN jsonb_build_object(
    'user', (
      SELECT jsonb_build_object(
        'id', u.id, 'email', u.email,
        'name', COALESCE(u.raw_user_meta_data->>'name',
                         u.raw_user_meta_data->>'full_name', ''),
        'created_at', u.created_at)
      FROM auth.users u WHERE u.id = p_user_id),
    'outlet', (
      SELECT jsonb_build_object(
        'id', o.id, 'name', o.name, 'type', o.type, 'address', o.address,
        'phone', o.phone, 'created_at', o.created_at)
      FROM public.outlets o WHERE o.id = v_outlet),
    'kyc', (
      SELECT to_jsonb(k) FROM public.outlet_kyc k WHERE k.outlet_id = v_outlet),
    'entitlements', (
      SELECT to_jsonb(e) FROM public.entitlements e WHERE e.outlet_id = v_outlet),
    'subscription', (
      SELECT to_jsonb(s) FROM public.supporters s
       WHERE s.outlet_id = v_outlet AND s.status IN ('active','trial')
      LIMIT 1),
    'stats', jsonb_build_object(
      'tx_count', (SELECT count(*) FROM public.transactions t WHERE t.outlet_id = v_outlet),
      'tx_30d', (SELECT count(*) FROM public.transactions t
                 WHERE t.outlet_id = v_outlet AND t.created_at >= NOW() - interval '30 days'),
      'omzet_30d', COALESCE((SELECT sum(t.final_amount) FROM public.transactions t
                 WHERE t.outlet_id = v_outlet AND t.created_at >= NOW() - interval '30 days'
                   AND t.order_status <> 'batal'), 0),
      'product_count', (SELECT count(*) FROM public.products p WHERE p.outlet_id = v_outlet),
      'customer_count', (SELECT count(*) FROM public.customers c WHERE c.outlet_id = v_outlet),
      'staff_count', (SELECT count(*) FROM public.user_roles ur WHERE ur.outlet_id = v_outlet)),
    'recent_transactions', COALESCE((
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
      FROM (SELECT t.id, t.final_amount, t.payment_method, t.order_status, t.created_at
            FROM public.transactions t
            WHERE t.outlet_id = v_outlet
            ORDER BY t.created_at DESC LIMIT 5) x), '[]'::jsonb),
    'leads', jsonb_build_object(
      'fintech', (SELECT count(*) FROM public.fintech_leads f WHERE f.outlet_id = v_outlet),
      'insurance', (SELECT count(*) FROM public.insurance_leads i WHERE i.outlet_id = v_outlet),
      'restock', (SELECT count(*) FROM public.restock_orders r WHERE r.outlet_id = v_outlet))
  );
END;
$$;

-- ============================================================================
