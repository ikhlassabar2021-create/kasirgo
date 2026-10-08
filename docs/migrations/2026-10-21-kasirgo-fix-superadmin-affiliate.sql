-- ============================================================================
-- 2026-10-21-kasirgo-fix-superadmin-affiliate.sql
-- FIX #12 (superadmin): detail closing per afiliasi + daftar afiliasi outlet.
--
-- Isi:
--   1. RPC platform_affiliate_closings(p_affiliate_id): daftar closing
--      (affiliate_referrals + outlet terkait) dengan nama outlet/pelanggan.
--   2. RPC platform_outlet_affiliates(): daftar afiliasi outlet
--      (outlet_affiliate_profiles) + ringkasan komisi utk superadmin.
--   3. RPC platform_outlet_affiliate_closing_add(): catat closing/komisi baru
--      untuk afiliasi outlet (superadmin).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Detail closing afiliasi partner (dari affiliate_referrals).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_affiliate_closings(p_affiliate_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN jsonb_build_object(
    'rows', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', r.id,
        'source', 'partner',
        'referred_name', COALESCE(u.email, o.name, '-'),
        'outlet_name', o.name,
        'status', r.status,
        'commission_amount', r.commission_amount,
        'created_at', r.created_at
      ) ORDER BY r.created_at DESC)
      FROM (
        SELECT * FROM public.affiliate_referrals
        WHERE affiliate_id = p_affiliate_id
        ORDER BY created_at DESC LIMIT 100
      ) r
      LEFT JOIN public.outlets o ON o.id = r.outlet_id
      LEFT JOIN auth.users u ON u.id = r.referred_user_id
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.platform_affiliate_closings(UUID) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.platform_affiliate_closings(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. Daftar afiliasi outlet (outlet_affiliate_profiles) utk superadmin.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_outlet_affiliates(p_search TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN jsonb_build_object(
    'rows', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', p.id,
        'outlet_id', p.outlet_id,
        'outlet_name', o.name,
        'owner_email', ou.email,
        'referral_code', p.referral_code,
        'is_active', p.is_active,
        'commission_percent', p.commission_percent,
        'bank_name', p.bank_name,
        'bank_account_name', p.bank_account_name,
        'bank_account_number', p.bank_account_number,
        'commission_total', COALESCE(c.total, 0),
        'unpaid_total', COALESCE(c.unpaid, 0),
        'closing_count', COALESCE(c.cnt, 0),
        'created_at', p.created_at
      ) ORDER BY p.created_at DESC)
      FROM (
        SELECT * FROM public.outlet_affiliate_profiles
        WHERE p_search IS NULL OR p_search = ''
          OR referral_code ILIKE '%' || p_search || '%'
        LIMIT 200
      ) p
      JOIN public.outlets o ON o.id = p.outlet_id
      LEFT JOIN auth.users ou ON ou.id = o.owner_id
      LEFT JOIN (
        SELECT profile_id,
               SUM(amount) AS total,
               SUM(CASE WHEN status = 'unpaid' THEN amount ELSE 0 END) AS unpaid,
               COUNT(*) AS cnt
        FROM public.outlet_affiliate_closings
        WHERE status <> 'cancelled'
        GROUP BY profile_id
      ) c ON c.profile_id = p.id
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.platform_outlet_affiliates(TEXT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.platform_outlet_affiliates(TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. Tambah closing komisi afiliasi outlet (superadmin).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_outlet_affiliate_closing_add(
  p_profile_id UUID,
  p_amount NUMERIC,
  p_description TEXT,
  p_referred_outlet_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ok boolean;
DECLARE v_id UUID;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.outlet_affiliate_closings
    (profile_id, amount, description, referred_outlet_id, referred_outlet_name)
  SELECT p_profile_id, p_amount, p_description, p_referred_outlet_id, o.name
  FROM public.outlet_affiliate_profiles p
  LEFT JOIN public.outlets o ON o.id = p_referred_outlet_id
  WHERE p.id = p_profile_id
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN RAISE EXCEPTION 'not_found'; END IF;

  RETURN jsonb_build_object('ok', TRUE, 'id', v_id);
END;
$$;

REVOKE ALL ON FUNCTION public.platform_outlet_affiliate_closing_add(UUID, NUMERIC, TEXT, UUID)
  FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.platform_outlet_affiliate_closing_add(UUID, NUMERIC, TEXT, UUID)
  TO authenticated;
