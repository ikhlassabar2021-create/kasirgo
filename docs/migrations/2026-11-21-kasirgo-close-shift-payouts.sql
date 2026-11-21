-- ============================================================================
-- KasirGo -- Tutup Shift Kasir + Pembayaran Closing Afiliasi Outlet
-- Tanggal: 2026-11-21
-- Jalankan di Supabase Dashboard -> SQL Editor (idempotent).
--
-- Isi:
--   1. RPC close_shift(): menutup shift outlet oleh kasir/admin/owner.
--      Sebelumnya policy UPDATE hanya mengizinkan shift milik sendiri sehingga
--      kasir tidak bisa menutup shift yang dibuka owner di outlet yang sama.
--   2. Kolom outlet_affiliate_closings.scheduled_at & paid_note.
--   3. RPC daftar closing per profil + bayar langsung / jadwalkan pembayaran
--      (superadmin), plus preview status pada daftar afiliasi outlet.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tutup shift oleh anggota outlet (owner/admin/kasir).
--    Perhitungan kas/qris/transfer/tip dilakukan di server agar konsisten
--    dengan data transaction_payments dan tips.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.close_shift(
  p_shift_id UUID,
  p_closing_cash NUMERIC,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_shift public.shifts%ROWTYPE;
  v_cash NUMERIC := 0;
  v_qris NUMERIC := 0;
  v_transfer NUMERIC := 0;
  v_tip NUMERIC := 0;
  v_expected NUMERIC := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  SELECT * INTO v_shift FROM public.shifts WHERE id = p_shift_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  IF v_shift.status <> 'open' THEN
    RAISE EXCEPTION 'shift_already_closed';
  END IF;

  IF NOT public.is_outlet_member(v_shift.outlet_id) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT
    COALESCE(SUM(CASE WHEN method = 'cash' THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN method = 'qris' THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN method = 'bank_transfer' THEN amount ELSE 0 END), 0)
  INTO v_cash, v_qris, v_transfer
  FROM public.transaction_payments
  WHERE shift_id = p_shift_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_tip
  FROM public.tips
  WHERE shift_id = p_shift_id;

  v_expected := COALESCE(v_shift.opening_cash, 0) + v_cash;

  UPDATE public.shifts SET
    status = 'closed',
    closed_at = NOW(),
    closing_cash = COALESCE(p_closing_cash, 0),
    expected_cash = v_expected,
    difference = COALESCE(p_closing_cash, 0) - v_expected,
    total_cash = v_cash,
    total_qris = v_qris,
    total_transfer = v_transfer,
    total_tip = v_tip,
    note = CASE
      WHEN p_note IS NOT NULL AND btrim(p_note) <> '' THEN btrim(p_note)
      ELSE note
    END
  WHERE id = p_shift_id
  RETURNING * INTO v_shift;

  RETURN to_jsonb(v_shift);
END;
$$;

REVOKE ALL ON FUNCTION public.close_shift(UUID, NUMERIC, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.close_shift(UUID, NUMERIC, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. Kolom jadwal pembayaran closing afiliasi outlet.
-- ----------------------------------------------------------------------------
ALTER TABLE public.outlet_affiliate_closings
  ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS paid_note TEXT;

-- ----------------------------------------------------------------------------
-- 3a. Daftar afiliasi outlet + preview closing lengkap (status & jadwal).
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
        'closings_preview', COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
            'id', x.id,
            'referred_outlet_name', x.referred_outlet_name,
            'description', x.description,
            'amount', x.amount,
            'status', x.status,
            'paid_at', x.paid_at,
            'scheduled_at', x.scheduled_at,
            'paid_note', x.paid_note,
            'created_at', x.created_at
          ) ORDER BY x.created_at DESC)
          FROM (
            SELECT * FROM public.outlet_affiliate_closings
            WHERE profile_id = p.id
            ORDER BY created_at DESC
            LIMIT 20
          ) x
        ), '[]'::jsonb),
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
-- 3b. Daftar closing satu profil (untuk refresh modal setelah aksi).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_outlet_affiliate_closings(p_profile_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN jsonb_build_object(
    'rows', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', c.id,
        'referred_outlet_id', c.referred_outlet_id,
        'referred_outlet_name', c.referred_outlet_name,
        'description', c.description,
        'amount', c.amount,
        'status', c.status,
        'paid_at', c.paid_at,
        'scheduled_at', c.scheduled_at,
        'paid_note', c.paid_note,
        'created_at', c.created_at
      ) ORDER BY c.created_at DESC)
      FROM (
        SELECT * FROM public.outlet_affiliate_closings
        WHERE profile_id = p_profile_id
        ORDER BY created_at DESC
        LIMIT 100
      ) c
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.platform_outlet_affiliate_closings(UUID) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.platform_outlet_affiliate_closings(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3c. Bayar langsung atau jadwalkan pembayaran closing afiliasi outlet.
--     mode: 'now' | 'schedule' | 'unschedule'
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_outlet_affiliate_closing_pay(
  p_closing_id UUID,
  p_mode TEXT,
  p_scheduled_at TIMESTAMPTZ DEFAULT NULL,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ok boolean;
  v_mode TEXT := lower(btrim(COALESCE(p_mode, '')));
  v_row public.outlet_affiliate_closings%ROWTYPE;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF v_mode NOT IN ('now', 'schedule', 'unschedule') THEN
    RAISE EXCEPTION 'bad_mode';
  END IF;

  SELECT * INTO v_row
  FROM public.outlet_affiliate_closings
  WHERE id = p_closing_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found';
  END IF;
  IF v_row.status = 'cancelled' THEN
    RAISE EXCEPTION 'closing_cancelled';
  END IF;

  IF v_mode = 'now' THEN
    IF v_row.status = 'paid' THEN
      RETURN jsonb_build_object(
        'ok', TRUE, 'already_paid', TRUE, 'id', v_row.id,
        'status', v_row.status, 'paid_at', v_row.paid_at,
        'scheduled_at', v_row.scheduled_at, 'amount', v_row.amount
      );
    END IF;
    UPDATE public.outlet_affiliate_closings
    SET status = 'paid',
        paid_at = NOW(),
        scheduled_at = NULL,
        paid_note = COALESCE(NULLIF(btrim(COALESCE(p_note, '')), ''), paid_note)
    WHERE id = p_closing_id
    RETURNING * INTO v_row;
  ELSIF v_mode = 'schedule' THEN
    IF v_row.status = 'paid' THEN
      RAISE EXCEPTION 'closing_already_paid';
    END IF;
    IF p_scheduled_at IS NULL THEN
      RAISE EXCEPTION 'scheduled_at_required';
    END IF;
    UPDATE public.outlet_affiliate_closings
    SET scheduled_at = p_scheduled_at,
        paid_note = COALESCE(NULLIF(btrim(COALESCE(p_note, '')), ''), paid_note)
    WHERE id = p_closing_id
    RETURNING * INTO v_row;
  ELSE
    IF v_row.status = 'paid' THEN
      RAISE EXCEPTION 'closing_already_paid';
    END IF;
    UPDATE public.outlet_affiliate_closings
    SET scheduled_at = NULL
    WHERE id = p_closing_id
    RETURNING * INTO v_row;
  END IF;

  PERFORM public.log_admin_action(
    'affiliate.outlet_closing_pay',
    v_row.id::text,
    jsonb_build_object(
      'mode', v_mode,
      'status', v_row.status,
      'amount', v_row.amount,
      'scheduled_at', v_row.scheduled_at,
      'paid_at', v_row.paid_at
    )
  );

  RETURN jsonb_build_object(
    'ok', TRUE,
    'id', v_row.id,
    'status', v_row.status,
    'paid_at', v_row.paid_at,
    'scheduled_at', v_row.scheduled_at,
    'amount', v_row.amount
  );
END;
$$;

REVOKE ALL ON FUNCTION public.platform_outlet_affiliate_closing_pay(UUID, TEXT, TIMESTAMPTZ, TEXT)
  FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.platform_outlet_affiliate_closing_pay(UUID, TEXT, TIMESTAMPTZ, TEXT)
  TO authenticated;
