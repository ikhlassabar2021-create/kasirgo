-- ============================================================================
-- KasirGo -- Fix No.5: detail closing afiliasi outlet di dashboard superadmin
-- Tanggal: 2026-12-16
--
-- Masalah: `platform_outlet_affiliates` hanya mengirim agregat
-- (commission_total/closing_count). Halaman admin membaca `closings_preview`
-- yang tidak pernah dikirim, sehingga modal "Riwayat Closing" selalu kosong
-- untuk afiliasi outlet. Fungsi ini menambahkan `closings_preview` (maks 20).
-- ============================================================================

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
