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

-- ---------------------------------------------------------------------------
-- 2. ST11-2: impersonate read-only + audit list + backup/restore + intelligence
--    Semua RPC menulis jejak ke audit_logs via log_admin_action().
-- ---------------------------------------------------------------------------

-- 2.1 backup_runs: snapshot data outlet (payload di kolom `data`,
--     TIDAK pernah dikirim oleh platform_backup_list).
CREATE TABLE IF NOT EXISTS public.backup_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
  kind TEXT NOT NULL DEFAULT 'full' CHECK (kind IN ('full','quick')),
  status TEXT NOT NULL DEFAULT 'success' CHECK (status IN ('success','failed','restored')),
  row_count INT DEFAULT 0,
  size_bytes BIGINT DEFAULT 0,
  data JSONB,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.backup_runs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin all backup_runs" ON public.backup_runs;
CREATE POLICY "Admin all backup_runs" ON public.backup_runs
  FOR ALL USING (public.platform_is_admin()) WITH CHECK (public.platform_is_admin());
CREATE INDEX IF NOT EXISTS idx_backup_runs_outlet ON public.backup_runs(outlet_id, created_at DESC);

-- 2.2 backup_schedules: backup terjadwal per outlet (dijalankan saat admin
--     membuka halaman Backup -> platform_backup_run_due; tanpa cron Rp0).
CREATE TABLE IF NOT EXISTS public.backup_schedules (
  outlet_id UUID PRIMARY KEY REFERENCES public.outlets(id) ON DELETE CASCADE,
  enabled BOOLEAN DEFAULT TRUE,
  cadence TEXT NOT NULL DEFAULT 'daily' CHECK (cadence IN ('daily','weekly')),
  last_run_at TIMESTAMPTZ,
  updated_by UUID,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.backup_schedules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin all backup_schedules" ON public.backup_schedules;
CREATE POLICY "Admin all backup_schedules" ON public.backup_schedules
  FOR ALL USING (public.platform_is_admin()) WITH CHECK (public.platform_is_admin());

-- 2.3 Impersonate READ-ONLY: snapshot kondisi outlet milik user (tanpa
--     aksi tulis). Menulis audit 'impersonate_view'.
CREATE OR REPLACE FUNCTION public.platform_impersonate_view(p_user_id uuid)
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
  IF v_outlet IS NULL THEN RAISE EXCEPTION 'outlet_not_found'; END IF;

  PERFORM public.log_admin_action('impersonate_view', p_user_id::text,
    jsonb_build_object('outlet_id', v_outlet, 'mode', 'read-only'));

  RETURN jsonb_build_object(
    'outlet', (
      SELECT to_jsonb(o) FROM public.outlets o WHERE o.id = v_outlet),
    'entitlements', (
      SELECT to_jsonb(e) FROM public.entitlements e WHERE e.outlet_id = v_outlet),
    'summary', jsonb_build_object(
      'product_count', (SELECT count(*) FROM public.products p WHERE p.outlet_id = v_outlet),
      'customer_count', (SELECT count(*) FROM public.customers c WHERE c.outlet_id = v_outlet),
      'staff_count', (SELECT count(*) FROM public.user_roles ur WHERE ur.outlet_id = v_outlet),
      'tx_today', (SELECT count(*) FROM public.transactions t
                   WHERE t.outlet_id = v_outlet AND t.created_at >= date_trunc('day', NOW())),
      'omzet_today', COALESCE((SELECT sum(t.final_amount) FROM public.transactions t
                   WHERE t.outlet_id = v_outlet AND t.created_at >= date_trunc('day', NOW())
                     AND t.order_status <> 'batal'), 0),
      'omzet_30d', COALESCE((SELECT sum(t.final_amount) FROM public.transactions t
                   WHERE t.outlet_id = v_outlet AND t.created_at >= NOW() - interval '30 days'
                     AND t.order_status <> 'batal'), 0)),
    'last7d', COALESCE((
      SELECT jsonb_agg(to_jsonb(d) ORDER BY d.day)
      FROM (
        SELECT date_trunc('day', t.created_at)::date AS day,
               count(*) AS tx, COALESCE(sum(t.final_amount), 0) AS omzet
        FROM public.transactions t
        WHERE t.outlet_id = v_outlet AND t.created_at >= NOW() - interval '7 days'
        GROUP BY 1) d), '[]'::jsonb),
    'top_products', COALESCE((
      SELECT jsonb_agg(to_jsonb(x))
      FROM (
        SELECT ti.product_name, sum(ti.quantity) AS qty, sum(ti.subtotal) AS omzet
        FROM public.transaction_items ti
        JOIN public.transactions t ON t.id = ti.transaction_id
        WHERE t.outlet_id = v_outlet AND t.created_at >= NOW() - interval '30 days'
        GROUP BY ti.product_name ORDER BY qty DESC LIMIT 10) x), '[]'::jsonb),
    'recent_transactions', COALESCE((
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
      FROM (SELECT t.id, t.final_amount, t.payment_method, t.order_status, t.created_at
            FROM public.transactions t
            WHERE t.outlet_id = v_outlet
            ORDER BY t.created_at DESC LIMIT 10) x), '[]'::jsonb),
    'staff', COALESCE((
      SELECT jsonb_agg(to_jsonb(x))
      FROM (
        SELECT u.email, ur.role, ur.is_active
        FROM public.user_roles ur
        LEFT JOIN auth.users u ON u.id = ur.user_id
        WHERE ur.outlet_id = v_outlet) x), '[]'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_impersonate_view(uuid) TO authenticated;

-- 2.4 Audit list (baca jejak aksi admin).
CREATE OR REPLACE FUNCTION public.platform_audit_list(
  p_limit int DEFAULT 25, p_offset int DEFAULT 0)
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
    'total', (SELECT count(*) FROM public.audit_logs),
    'rows', COALESCE((
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
      FROM (SELECT a.id, a.actor_id, a.actor_role, a.action, a.target, a.meta, a.created_at,
                   COALESCE(u.email, '(sistem)') AS actor_email
            FROM public.audit_logs a
            LEFT JOIN auth.users u ON u.id = a.actor_id
            ORDER BY a.created_at DESC
            LIMIT GREATEST(LEAST(p_limit, 100), 1)
            OFFSET GREATEST(p_offset, 0)) x), '[]'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_audit_list(int, int) TO authenticated;

-- 2.5 Buat backup snapshot outlet (full = +transaksi 90 hari, quick = master data saja).
CREATE OR REPLACE FUNCTION public.platform_backup_create(
  p_outlet_id uuid, p_kind text DEFAULT 'full')
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_kind text := CASE WHEN p_kind = 'quick' THEN 'quick' ELSE 'full' END;
  v_payload jsonb;
  v_rows int;
  v_id uuid;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_payload := jsonb_build_object(
    'schema_version', 1,
    'outlet', (SELECT to_jsonb(o) FROM public.outlets o WHERE o.id = p_outlet_id),
    'products', COALESCE((
      SELECT jsonb_agg(to_jsonb(p) ORDER BY p.name)
      FROM public.products p WHERE p.outlet_id = p_outlet_id), '[]'::jsonb),
    'product_variants', COALESCE((
      SELECT jsonb_agg(to_jsonb(v) ORDER BY v.name)
      FROM public.product_variants v
      WHERE v.product_id IN (SELECT id FROM public.products WHERE outlet_id = p_outlet_id)), '[]'::jsonb),
    'customers', COALESCE((
      SELECT jsonb_agg(to_jsonb(c) ORDER BY c.name)
      FROM public.customers c WHERE c.outlet_id = p_outlet_id), '[]'::jsonb),
    'employees', COALESCE((
      SELECT jsonb_agg(to_jsonb(ur))
      FROM public.user_roles ur WHERE ur.outlet_id = p_outlet_id), '[]'::jsonb)
  );

  IF v_kind = 'full' THEN
    v_payload := jsonb_set(v_payload, '{transactions}', COALESCE((
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.created_at)
      FROM public.transactions t
      WHERE t.outlet_id = p_outlet_id
        AND t.created_at >= NOW() - interval '90 days'), '[]'::jsonb));
    v_payload := jsonb_set(v_payload, '{transaction_items}', COALESCE((
      SELECT jsonb_agg(to_jsonb(ti) ORDER BY ti.id)
      FROM public.transaction_items ti
      JOIN public.transactions t ON t.id = ti.transaction_id
      WHERE t.outlet_id = p_outlet_id
        AND t.created_at >= NOW() - interval '90 days'), '[]'::jsonb));
  END IF;

  v_rows := (SELECT (jsonb_array_length(COALESCE(v_payload->'products', '[]'::jsonb))
                   + jsonb_array_length(COALESCE(v_payload->'customers', '[]'::jsonb))
                   + jsonb_array_length(COALESCE(v_payload->'transactions', '[]'::jsonb))));

  INSERT INTO public.backup_runs (outlet_id, kind, status, row_count, size_bytes, data, created_by)
  VALUES (p_outlet_id, v_kind, 'success', v_rows, length(v_payload::text), v_payload, auth.uid())
  RETURNING id INTO v_id;

  PERFORM public.log_admin_action('backup_create', p_outlet_id::text,
    jsonb_build_object('backup_id', v_id, 'kind', v_kind, 'rows', v_rows));

  RETURN jsonb_build_object('id', v_id, 'kind', v_kind, 'row_count', v_rows,
                            'size_bytes', length(v_payload::text), 'created_at', NOW());
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_backup_create(uuid, text) TO authenticated;

-- 2.6 Daftar backup (TANPA payload data).
CREATE OR REPLACE FUNCTION public.platform_backup_list()
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
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
      FROM (SELECT b.id, b.outlet_id, o.name AS outlet_name, b.kind, b.status,
                   b.row_count, b.size_bytes, b.created_at
            FROM public.backup_runs b
            LEFT JOIN public.outlets o ON o.id = b.outlet_id
            ORDER BY b.created_at DESC LIMIT 100) x), '[]'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_backup_list() TO authenticated;

-- 2.7 Ambil payload backup (untuk unduh JSON) + audit.
CREATE OR REPLACE FUNCTION public.platform_backup_get(p_id uuid)
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

  SELECT outlet_id INTO v_outlet FROM public.backup_runs WHERE id = p_id;
  IF v_outlet IS NULL THEN RAISE EXCEPTION 'backup_not_found'; END IF;

  PERFORM public.log_admin_action('backup_download', v_outlet::text,
    jsonb_build_object('backup_id', p_id));

  RETURN to_jsonb(b) FROM public.backup_runs b WHERE b.id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_backup_get(uuid) TO authenticated;

-- 2.8 Pulihkan master data yang HILANG saja (upsert by id, tidak pernah
--     menimpa data yang sudah ada; transaksi TIDAK dipulihkan agar
--     keuangan tidak dobel). Menulis audit.
CREATE OR REPLACE FUNCTION public.platform_backup_restore(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_rec public.backup_runs;
  v_products int := 0;
  v_customers int := 0;
  v_variants int := 0;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT * INTO v_rec FROM public.backup_runs WHERE id = p_id;
  IF v_rec.id IS NULL THEN RAISE EXCEPTION 'backup_not_found'; END IF;
  IF v_rec.data IS NULL THEN RAISE EXCEPTION 'backup_empty'; END IF;

  -- Produk hilang saja (id sama = skip, jangan menimpa).
  -- Kolom sesuai docs/kasirgo-schema.sql (+ has_variants dari migrasi 3.0/8);
  -- products TIDAK punya kolom sku/is_active di Supabase.
  WITH ins AS (
    INSERT INTO public.products (id, outlet_id, name, category, barcode, unit,
                                 base_price, cost_price, stock, image_local_path,
                                 thumb_key, min_stock_alert, has_variants,
                                 expired_date, created_at, updated_at)
    SELECT (e->>'id')::uuid, (e->>'outlet_id')::uuid, e->>'name', e->>'category',
           e->>'barcode', e->>'unit',
           COALESCE((e->>'base_price')::numeric, 0), (e->>'cost_price')::numeric,
           COALESCE((e->>'stock')::int, 0),
           COALESCE(e->>'image_local_path', ''), e->>'thumb_key',
           COALESCE((e->>'min_stock_alert')::int, 0),
           COALESCE((e->>'has_variants')::boolean, false),
           (e->>'expired_date')::timestamptz,
           COALESCE((e->>'created_at')::timestamptz, NOW()), NOW()
    FROM jsonb_array_elements(v_rec.data->'products') e
    ON CONFLICT (id) DO NOTHING
    RETURNING 1)
  SELECT count(*) INTO v_products FROM ins;

  -- Varian hilang saja.
  WITH ins AS (
    INSERT INTO public.product_variants (id, product_id, outlet_id, name, sku, barcode,
                                         price_delta, stock, is_active, created_at)
    SELECT (e->>'id')::uuid, (e->>'product_id')::uuid, (e->>'outlet_id')::uuid,
           e->>'name', e->>'sku', e->>'barcode',
           COALESCE((e->>'price_delta')::numeric, 0), COALESCE((e->>'stock')::int, 0),
           COALESCE((e->>'is_active')::boolean, true),
           COALESCE((e->>'created_at')::timestamptz, NOW())
    FROM jsonb_array_elements(v_rec.data->'product_variants') e
    ON CONFLICT (id) DO NOTHING
    RETURNING 1)
  SELECT count(*) INTO v_variants FROM ins;

  -- Pelanggan hilang saja. Kolom sesuai docs/kasirgo-schema.sql:
  -- phone_wa (bukan phone); email/address/last_visit tidak dijamin ada
  -- di skema live, jadi tidak di-restore.
  WITH ins AS (
    INSERT INTO public.customers (id, outlet_id, name, phone_wa,
                                  loyalty_points, total_spent, created_at)
    SELECT (e->>'id')::uuid, (e->>'outlet_id')::uuid, e->>'name', e->>'phone_wa',
           COALESCE((e->>'loyalty_points')::int, 0),
           COALESCE((e->>'total_spent')::numeric, 0),
           COALESCE((e->>'created_at')::timestamptz, NOW())
    FROM jsonb_array_elements(v_rec.data->'customers') e
    ON CONFLICT (id) DO NOTHING
    RETURNING 1)
  SELECT count(*) INTO v_customers FROM ins;

  UPDATE public.backup_runs SET status = 'restored' WHERE id = p_id;

  PERFORM public.log_admin_action('backup_restore', v_rec.outlet_id::text,
    jsonb_build_object('backup_id', p_id, 'products', v_products,
                       'variants', v_variants, 'customers', v_customers));

  RETURN jsonb_build_object('products', v_products, 'variants', v_variants,
                            'customers', v_customers);
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_backup_restore(uuid) TO authenticated;

-- 2.9 Set/ubah jadwal backup outlet.
CREATE OR REPLACE FUNCTION public.platform_backup_schedule_set(
  p_outlet_id uuid, p_enabled boolean, p_cadence text DEFAULT 'daily')
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

  INSERT INTO public.backup_schedules (outlet_id, enabled, cadence, updated_by, updated_at)
  VALUES (p_outlet_id, p_enabled, CASE WHEN p_cadence = 'weekly' THEN 'weekly' ELSE 'daily' END,
          auth.uid(), NOW())
  ON CONFLICT (outlet_id) DO UPDATE
    SET enabled = EXCLUDED.enabled, cadence = EXCLUDED.cadence,
        updated_by = EXCLUDED.updated_by, updated_at = NOW();

  PERFORM public.log_admin_action('backup_schedule_set', p_outlet_id::text,
    jsonb_build_object('enabled', p_enabled, 'cadence', p_cadence));
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_backup_schedule_set(uuid, boolean, text) TO authenticated;

-- 2.10 Jalankan backup yang jatuh tempo (dipanggil client saat buka halaman).
CREATE OR REPLACE FUNCTION public.platform_backup_run_due()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_count int := 0;
  r RECORD;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  FOR r IN
    SELECT s.outlet_id, s.cadence
    FROM public.backup_schedules s
    WHERE s.enabled
      AND (s.last_run_at IS NULL
           OR (s.cadence = 'daily'  AND s.last_run_at < date_trunc('day', NOW()))
           OR (s.cadence = 'weekly' AND s.last_run_at <  NOW() - interval '7 days'))
  LOOP
    PERFORM public.platform_backup_create(r.outlet_id, 'quick');
    UPDATE public.backup_schedules SET last_run_at = NOW() WHERE outlet_id = r.outlet_id;
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_backup_run_due() TO authenticated;

-- 2.11 Platform intelligence (agregat lintas outlet, tanpa data pribadi).
CREATE OR REPLACE FUNCTION public.platform_intelligence()
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
    'kpis', jsonb_build_object(
      'total_outlets', (SELECT count(*) FROM public.outlets),
      'active_30d', (SELECT count(DISTINCT outlet_id) FROM public.transactions
                     WHERE created_at >= NOW() - interval '30 days'),
      'new_30d', (SELECT count(*) FROM public.outlets
                  WHERE created_at >= NOW() - interval '30 days'),
      'avg_tx_per_outlet_30d', COALESCE((
        SELECT round(avg(c), 1) FROM (
          SELECT count(*) AS c FROM public.transactions
          WHERE created_at >= NOW() - interval '30 days' GROUP BY outlet_id) s), 0)),
    'trend', COALESCE((
      SELECT jsonb_agg(to_jsonb(d) ORDER BY d.day)
      FROM (
        SELECT date_trunc('day', t.created_at)::date AS day,
               count(*) AS tx, COALESCE(sum(t.final_amount), 0) AS omzet
        FROM public.transactions t
        WHERE t.created_at >= NOW() - interval '30 days'
        GROUP BY 1) d), '[]'::jsonb),
    'weekly_active', COALESCE((
      SELECT jsonb_agg(to_jsonb(w) ORDER BY w.week)
      FROM (
        SELECT date_trunc('week', t.created_at)::date AS week,
               count(DISTINCT t.outlet_id) AS outlets,
               count(*) AS tx
        FROM public.transactions t
        WHERE t.created_at >= NOW() - interval '56 days'
        GROUP BY 1) w), '[]'::jsonb),
    'churn_risk', COALESCE((
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.last_tx_at)
      FROM (
        SELECT o.id AS outlet_id, o.name AS outlet_name,
               max(t.created_at) AS last_tx_at,
               count(t.id) AS tx_total
        FROM public.outlets o
        JOIN public.transactions t ON t.outlet_id = o.id
        GROUP BY o.id, o.name
        HAVING count(t.id) >= 3
           AND max(t.created_at) < NOW() - interval '14 days'
        ORDER BY max(t.created_at)
        LIMIT 20) x), '[]'::jsonb),
    'anomaly', COALESCE((
      SELECT jsonb_agg(to_jsonb(a)) FROM (
        SELECT d.day, d.tx,
               round((d.tx - avg_stat.mean) / NULLIF(avg_stat.stddev, 0), 2) AS z
        FROM (
          SELECT date_trunc('day', t.created_at)::date AS day, count(*) AS tx
          FROM public.transactions t
          WHERE t.created_at >= NOW() - interval '30 days'
          GROUP BY 1) d
        CROSS JOIN (
          SELECT avg(c) AS mean, stddev_pop(c) AS stddev FROM (
            SELECT count(*) AS c FROM public.transactions
            WHERE created_at >= NOW() - interval '30 days'
            GROUP BY date_trunc('day', created_at)) q
        ) avg_stat
        WHERE avg_stat.stddev > 0
          AND abs((d.tx - avg_stat.mean) / avg_stat.stddev) > 2.5
      ) a), '[]'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_intelligence() TO authenticated;

-- ============================================================================
