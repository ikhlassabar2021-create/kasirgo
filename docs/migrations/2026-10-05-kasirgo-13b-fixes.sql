-- ============================================================================
-- KASIRGO PHASE 13B — Perbaikan dashboard superadmin + Control Plane + Affiliate
-- Tanggal: 2026-10-05
--
-- Isi:
--   1. Riwayat transaksi per outlet (PPOB, Payment Gateway, B2B, Asuransi,
--      Modal Usaha) untuk halaman "Outlet Terdaftar".
--   2. Control Plane: config komisi Modal Usaha + integrasi sistem
--      (WA, Database, Backup/Restore + jadwal, Cloudflare, API key/URL).
--   3. Affiliate: profil + rekening bank, pengaturan jadwal pembayaran komisi
--      (otomatis/manual), kelola user affiliate (tambah/hapus/link),
--      riwayat referral & payout, portal affiliate.
--
-- CARA PAKAI: tempel semua -> RUN. Idempotent.
-- Prasyarat: Phase 11 (platform_is_admin, log_admin_action, platform_config_save)
--            + Phase 13 (platform_outlets_list).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. RIWAYAT TRANSAKSI PER OUTLET (5 sumber)
-- ---------------------------------------------------------------------------

-- 1a. PPOB per outlet
CREATE OR REPLACE FUNCTION public.platform_outlet_ppob_transactions(
  p_outlet_id uuid, p_limit int DEFAULT 100)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN jsonb_build_object(
    'rows', COALESCE((
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
      FROM (
        SELECT id, product_name, customer_ref, amount, cost_amount, profit,
               status, payment_method, provider_ref, created_at
        FROM public.ppob_transactions
        WHERE outlet_id = p_outlet_id
        ORDER BY created_at DESC
        LIMIT GREATEST(LEAST(p_limit, 500), 1)
      ) x), '[]'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_outlet_ppob_transactions(uuid, int) TO authenticated;

-- 1b. Payment Gateway / QRIS margin per outlet (billing_events)
CREATE OR REPLACE FUNCTION public.platform_outlet_pg_transactions(
  p_outlet_id uuid, p_limit int DEFAULT 100)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN jsonb_build_object(
    'rows', COALESCE((
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
      FROM (
        SELECT id, event, amount, status, ref, created_at
        FROM public.billing_events
        WHERE outlet_id = p_outlet_id
        ORDER BY created_at DESC
        LIMIT GREATEST(LEAST(p_limit, 500), 1)
      ) x), '[]'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_outlet_pg_transactions(uuid, int) TO authenticated;

-- 1c. B2B Restock per outlet (komisi)
CREATE OR REPLACE FUNCTION public.platform_outlet_b2b_transactions(
  p_outlet_id uuid, p_limit int DEFAULT 100)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN jsonb_build_object(
    'rows', COALESCE((
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
      FROM (
        SELECT id, distributor, tracking_id, amount, commission, status,
               items_note, created_at
        FROM public.restock_orders
        WHERE outlet_id = p_outlet_id
        ORDER BY created_at DESC
        LIMIT GREATEST(LEAST(p_limit, 500), 1)
      ) x), '[]'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_outlet_b2b_transactions(uuid, int) TO authenticated;

-- 1d. Klaim asuransi per outlet (komisi closing)
CREATE OR REPLACE FUNCTION public.platform_outlet_insurance_leads(
  p_outlet_id uuid, p_limit int DEFAULT 100)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN jsonb_build_object(
    'rows', COALESCE((
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
      FROM (
        SELECT id, product_name, product_type, premi, coverage_amount,
               commission, status, ref, created_at
        FROM public.insurance_leads
        WHERE outlet_id = p_outlet_id
        ORDER BY created_at DESC
        LIMIT GREATEST(LEAST(p_limit, 500), 1)
      ) x), '[]'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_outlet_insurance_leads(uuid, int) TO authenticated;

-- 1e. Pengajuan Modal Usaha per outlet (komisi/plafon)
CREATE OR REPLACE FUNCTION public.platform_outlet_fintech_leads(
  p_outlet_id uuid, p_limit int DEFAULT 100)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN jsonb_build_object(
    'rows', COALESCE((
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
      FROM (
        SELECT id, partner, amount_requested, tenor_months, status, ref,
               eligibility_score, commission, created_at
        FROM (
          SELECT id, partner, amount_requested, tenor_months, status, ref,
                 eligibility_score,
                 COALESCE((payload->>'commission')::numeric, 0) AS commission,
                 created_at
          FROM public.fintech_leads
          WHERE outlet_id = p_outlet_id
        ) base
        ORDER BY created_at DESC
        LIMIT GREATEST(LEAST(p_limit, 500), 1)
      ) x), '[]'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_outlet_fintech_leads(uuid, int) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. AFFILIATE — perluas tabel + rekening bank + jadwal payout
-- ---------------------------------------------------------------------------
ALTER TABLE public.affiliates ADD COLUMN IF NOT EXISTS user_id uuid;
ALTER TABLE public.affiliates ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE public.affiliates ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';
ALTER TABLE public.affiliates ADD COLUMN IF NOT EXISTS bank_name text;
ALTER TABLE public.affiliates ADD COLUMN IF NOT EXISTS bank_account_name text;
ALTER TABLE public.affiliates ADD COLUMN IF NOT EXISTS bank_account_number text;
ALTER TABLE public.affiliates ADD COLUMN IF NOT EXISTS payout_frequency text NOT NULL DEFAULT 'monthly';
ALTER TABLE public.affiliates ADD COLUMN IF NOT EXISTS payout_weekday int DEFAULT 1;      -- 1=Senin .. 7=Minggu
ALTER TABLE public.affiliates ADD COLUMN IF NOT EXISTS payout_day_of_month int DEFAULT 1; -- 1..28
ALTER TABLE public.affiliates ADD COLUMN IF NOT EXISTS payout_mode text NOT NULL DEFAULT 'manual'; -- auto|manual
ALTER TABLE public.affiliates ADD COLUMN IF NOT EXISTS min_payout numeric NOT NULL DEFAULT 0;
CREATE UNIQUE INDEX IF NOT EXISTS idx_affiliates_referral_code ON public.affiliates(referral_code);
CREATE INDEX IF NOT EXISTS idx_affiliates_user ON public.affiliates(user_id);

-- RLS: affiliate hanya baca baris sendiri; superadmin penuh.
ALTER TABLE public.affiliates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin all affiliates" ON public.affiliates;
CREATE POLICY "Admin all affiliates" ON public.affiliates
  FOR ALL USING (public.platform_is_admin()) WITH CHECK (public.platform_is_admin());
DROP POLICY IF EXISTS "Affiliate read self" ON public.affiliates;
CREATE POLICY "Affiliate read self" ON public.affiliates
  FOR SELECT TO authenticated USING (user_id = auth.uid());

ALTER TABLE public.affiliate_referrals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin all affiliate_referrals" ON public.affiliate_referrals;
CREATE POLICY "Admin all affiliate_referrals" ON public.affiliate_referrals
  FOR ALL USING (public.platform_is_admin()) WITH CHECK (public.platform_is_admin());
DROP POLICY IF EXISTS "Affiliate read own referrals" ON public.affiliate_referrals;
CREATE POLICY "Affiliate read own referrals" ON public.affiliate_referrals
  FOR SELECT TO authenticated USING (affiliate_id IN
    (SELECT id FROM public.affiliates WHERE user_id = auth.uid()));

-- Riwayat payout affiliate
CREATE TABLE IF NOT EXISTS public.affiliate_payouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id uuid NOT NULL REFERENCES public.affiliates(id) ON DELETE CASCADE,
  period_start timestamptz,
  period_end timestamptz,
  amount numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending', -- pending|paid|failed
  method text,
  ref text,
  note text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE public.affiliate_payouts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin all affiliate_payouts" ON public.affiliate_payouts;
CREATE POLICY "Admin all affiliate_payouts" ON public.affiliate_payouts
  FOR ALL USING (public.platform_is_admin()) WITH CHECK (public.platform_is_admin());
DROP POLICY IF EXISTS "Affiliate read own payouts" ON public.affiliate_payouts;
CREATE POLICY "Affiliate read own payouts" ON public.affiliate_payouts
  FOR SELECT TO authenticated USING (affiliate_id IN
    (SELECT id FROM public.affiliates WHERE user_id = auth.uid()));

-- ---------------------------------------------------------------------------
-- 3. AFFILIATE — RPC superadmin (list / upsert / hapus / link / payout)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_affiliates_list(
  p_search text DEFAULT NULL, p_limit int DEFAULT 100, p_offset int DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN (
    WITH base AS (
      SELECT a.*,
             COALESCE((SELECT sum(commission_amount) FROM public.affiliate_referrals r
                       WHERE r.affiliate_id = a.id), 0) AS commission_total,
             COALESCE((SELECT count(*) FROM public.affiliate_referrals r
                       WHERE r.affiliate_id = a.id), 0) AS referral_count,
             COALESCE((SELECT sum(commission_amount) FROM public.affiliate_referrals r
                       WHERE r.affiliate_id = a.id AND r.status = 'pending'), 0) AS unpaid_total
      FROM public.affiliates a
    ),
    filtered AS (
      SELECT * FROM base
      WHERE p_search IS NULL OR p_search = ''
        OR name ILIKE '%'||p_search||'%'
        OR COALESCE(email,'') ILIKE '%'||p_search||'%'
        OR referral_code ILIKE '%'||p_search||'%'
    )
    SELECT jsonb_build_object(
      'total', (SELECT count(*) FROM filtered),
      'rows', COALESCE((SELECT jsonb_agg(to_jsonb(f) ORDER BY f.created_at DESC)
        FROM (SELECT * FROM filtered ORDER BY created_at DESC
              LIMIT GREATEST(LEAST(p_limit,200),1) OFFSET GREATEST(p_offset,0)) f), '[]'::jsonb)
    )
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_affiliates_list(text, int, int) TO authenticated;

CREATE OR REPLACE FUNCTION public.platform_affiliate_upsert(
  p_id uuid DEFAULT NULL,
  p_name text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_user_id uuid DEFAULT NULL,
  p_commission_percent numeric DEFAULT 10,
  p_referral_code text DEFAULT NULL,
  p_status text DEFAULT 'active')
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_ok boolean; v_id uuid; v_code text;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_code := COALESCE(NULLIF(trim(p_referral_code), ''),
    'KGD' || upper(substr(md5(random()::text), 1, 6)));

  IF p_id IS NULL THEN
    INSERT INTO public.affiliates (name, email, phone, user_id, referral_code,
                                   commission_percent, status)
    VALUES (COALESCE(p_name,''), p_email, p_phone, p_user_id, v_code,
            COALESCE(p_commission_percent,10), COALESCE(p_status,'active'))
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.affiliates SET
      name = COALESCE(p_name, name),
      email = COALESCE(p_email, email),
      phone = COALESCE(p_phone, phone),
      user_id = COALESCE(p_user_id, user_id),
      referral_code = COALESCE(NULLIF(trim(p_referral_code),''), referral_code),
      commission_percent = COALESCE(p_commission_percent, commission_percent),
      status = COALESCE(p_status, status)
    WHERE id = p_id RETURNING id INTO v_id;
    SELECT referral_code INTO v_code FROM public.affiliates WHERE id = v_id;
  END IF;

  PERFORM public.log_admin_action('affiliate.upsert', v_id::text,
    jsonb_build_object('code', v_code, 'email', p_email));
  RETURN jsonb_build_object('id', v_id, 'referral_code', v_code);
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_affiliate_upsert(uuid, text, text, text, uuid, numeric, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.platform_affiliate_delete(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;
  DELETE FROM public.affiliates WHERE id = p_id;
  PERFORM public.log_admin_action('affiliate.delete', p_id::text, '{}');
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_affiliate_delete(uuid) TO authenticated;

-- Set jadwal + rekening payout affiliate
CREATE OR REPLACE FUNCTION public.platform_affiliate_set_payout(
  p_id uuid, p_frequency text DEFAULT NULL, p_weekday int DEFAULT NULL,
  p_day_of_month int DEFAULT NULL, p_mode text DEFAULT NULL,
  p_min_payout numeric DEFAULT NULL,
  p_bank_name text DEFAULT NULL, p_bank_account_name text DEFAULT NULL,
  p_bank_account_number text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.affiliates SET
    payout_frequency = COALESCE(p_frequency, payout_frequency),
    payout_weekday = COALESCE(p_weekday, payout_weekday),
    payout_day_of_month = COALESCE(p_day_of_month, payout_day_of_month),
    payout_mode = COALESCE(p_mode, payout_mode),
    min_payout = COALESCE(p_min_payout, min_payout),
    bank_name = COALESCE(p_bank_name, bank_name),
    bank_account_name = COALESCE(p_bank_account_name, bank_account_name),
    bank_account_number = COALESCE(p_bank_account_number, bank_account_number)
  WHERE id = p_id;
  PERFORM public.log_admin_action('affiliate.payout_set', p_id::text,
    jsonb_build_object('mode', p_mode, 'frequency', p_frequency));
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_affiliate_set_payout(uuid, text, int, int, text, numeric, text, text, text) TO authenticated;

-- Jalankan pembayaran komisi affiliate (manual per affiliate atau batch auto/manual)
CREATE OR REPLACE FUNCTION public.platform_affiliate_payout_run(
  p_affiliate_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_ok boolean; a RECORD; v_amount numeric; v_payout uuid; v_count int := 0; v_total numeric := 0;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  FOR a IN
    SELECT id, COALESCE(min_payout,0) AS min_payout
    FROM public.affiliates
    WHERE (p_affiliate_id IS NULL OR id = p_affiliate_id)
      AND status = 'active'
  LOOP
    SELECT COALESCE(sum(commission_amount),0) INTO v_amount
    FROM public.affiliate_referrals
    WHERE affiliate_id = a.id AND COALESCE(status,'pending') <> 'paid';

    IF v_amount >= a.min_payout AND v_amount > 0 THEN
      INSERT INTO public.affiliate_payouts
        (affiliate_id, period_start, period_end, amount, status, method, note)
      VALUES (a.id, NULL, now(), v_amount, 'paid', 'manual', 'Payout komisi')
      RETURNING id INTO v_payout;

      UPDATE public.affiliate_referrals
      SET status = 'paid'
      WHERE affiliate_id = a.id AND COALESCE(status,'pending') <> 'paid';

      UPDATE public.affiliates
      SET total_earned = COALESCE(total_earned,0) + v_amount
      WHERE id = a.id;

      v_count := v_count + 1;
      v_total := v_total + v_amount;
    END IF;
  END LOOP;

  PERFORM public.log_admin_action('affiliate.payout_run',
    COALESCE(p_affiliate_id::text,'all'),
    jsonb_build_object('count', v_count, 'total', v_total));
  RETURN jsonb_build_object('paid_affiliates', v_count, 'total_amount', v_total);
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_affiliate_payout_run(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. AFFILIATE — RPC portal (login user affiliate, profil, rekening, histori)
-- ---------------------------------------------------------------------------

-- Ringkasan untuk portal affiliate (dipanggil oleh user yang login).
CREATE OR REPLACE FUNCTION public.affiliate_me()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE a RECORD;
BEGIN
  SELECT * INTO a FROM public.affiliates WHERE user_id = auth.uid() LIMIT 1;
  IF a.id IS NULL THEN
    RETURN jsonb_build_object('found', false);
  END IF;
  RETURN jsonb_build_object(
    'found', true,
    'affiliate', jsonb_build_object(
      'id', a.id, 'name', a.name, 'email', a.email, 'phone', a.phone,
      'referral_code', a.referral_code,
      'commission_percent', a.commission_percent,
      'status', a.status,
      'bank_name', a.bank_name,
      'bank_account_name', a.bank_account_name,
      'bank_account_number', a.bank_account_number,
      'payout_frequency', a.payout_frequency,
      'payout_weekday', a.payout_weekday,
      'payout_day_of_month', a.payout_day_of_month,
      'payout_mode', a.payout_mode,
      'min_payout', a.min_payout
    ),
    'summary', jsonb_build_object(
      'commission_total', COALESCE((SELECT sum(commission_amount) FROM public.affiliate_referrals
                                    WHERE affiliate_id = a.id), 0),
      'unpaid_total', COALESCE((SELECT sum(commission_amount) FROM public.affiliate_referrals
                                WHERE affiliate_id = a.id AND COALESCE(status,'pending') <> 'paid'), 0),
      'paid_total', COALESCE((SELECT sum(amount) FROM public.affiliate_payouts
                              WHERE affiliate_id = a.id AND status = 'paid'), 0),
      'referral_count', (SELECT count(*) FROM public.affiliate_referrals WHERE affiliate_id = a.id)
    ),
    'closings', COALESCE((
      SELECT jsonb_agg(to_jsonb(c) ORDER BY c.created_at DESC)
      FROM (
        SELECT r.id, r.commission_amount, r.status, r.created_at,
               o.name AS outlet_name
        FROM public.affiliate_referrals r
        LEFT JOIN public.outlets o ON o.id = r.outlet_id
        WHERE r.affiliate_id = a.id
        ORDER BY r.created_at DESC LIMIT 200) c), '[]'::jsonb),
    'payouts', COALESCE((
      SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at DESC)
      FROM (SELECT id, amount, status, method, ref, note, created_at,
                   period_start, period_end
            FROM public.affiliate_payouts WHERE affiliate_id = a.id
            ORDER BY created_at DESC LIMIT 200) p), '[]'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.affiliate_me() TO authenticated;

-- Perbarui profil + rekening bank affiliate (diri sendiri).
CREATE OR REPLACE FUNCTION public.affiliate_update_profile(
  p_name text DEFAULT NULL, p_phone text DEFAULT NULL,
  p_bank_name text DEFAULT NULL, p_bank_account_name text DEFAULT NULL,
  p_bank_account_number text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE a_id uuid;
BEGIN
  SELECT id INTO a_id FROM public.affiliates WHERE user_id = auth.uid() LIMIT 1;
  IF a_id IS NULL THEN RAISE EXCEPTION 'not_affiliate'; END IF;
  UPDATE public.affiliates SET
    name = COALESCE(NULLIF(trim(p_name),''), name),
    phone = COALESCE(p_phone, phone),
    bank_name = COALESCE(p_bank_name, bank_name),
    bank_account_name = COALESCE(p_bank_account_name, bank_account_name),
    bank_account_number = COALESCE(p_bank_account_number, bank_account_number)
  WHERE id = a_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.affiliate_update_profile(text, text, text, text, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 5. CONTROL PLANE — config key baru (komisi modal usaha + integrasi sistem)
--    Nilai disimpan via platform_config_save (grup: fintech_partner, system).
-- ---------------------------------------------------------------------------
INSERT INTO public.platform_configs (key, scope, scope_ref, value, version)
VALUES
  ('fintech_partner', 'global', 'all',
   '{"enabled":true,"commission_percent":2,"commission_flat":0,"partners":[]}'::jsonb, 1),
  ('system', 'global', 'all',
   '{"wa_api_url":"","wa_api_key":"","wa_sender":"","database_url":"","database_anon_key":"","database_service_key":"","backup_enabled":true,"backup_frequency":"daily","backup_hour":2,"restore_enabled":true,"cloudflare_account_id":"","cloudflare_api_token":"","cloudflare_r2_bucket":"","cloudflare_r2_public_url":"","cloudflare_zone_id":"","apikey_notes":""}'::jsonb, 1)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- VERIFIKASI:
--   SELECT public.platform_affiliates_list(NULL,10,0);
--   SELECT public.affiliate_me();
-- ============================================================================
