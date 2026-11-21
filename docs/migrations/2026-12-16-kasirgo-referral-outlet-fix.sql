-- ============================================================================
-- KasirGo -- Fix No.5: kode referral harus menempel ke outlet yang tepat
-- Tanggal: 2026-12-16
--
-- Masalah: `set_outlet_referral` lama selalu memakai outlet PERTAMA milik owner
-- (ORDER BY created_at ASC). Untuk owner multi-outlet, kode referral bisa
-- tersimpan di outlet yang salah dan komisi tidak muncul di outlet yang
-- di-upgrade. Fungsi baru menerima `p_outlet` (opsional) dan memvalidasi
-- kepemilikan; tanpa parameter tetap jatuh ke outlet pertama (kompatibel).
-- ============================================================================

DROP FUNCTION IF EXISTS public.set_outlet_referral(TEXT);

CREATE OR REPLACE FUNCTION public.set_outlet_referral(
  p_code TEXT,
  p_outlet UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_outlet UUID;
  v_code TEXT;
  v_profile RECORD;
BEGIN
  IF p_outlet IS NOT NULL THEN
    SELECT o.id INTO v_outlet
    FROM public.outlets o
    WHERE o.id = p_outlet
      AND o.owner_id = auth.uid()
    LIMIT 1;

    IF v_outlet IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'error', 'outlet_forbidden');
    END IF;
  ELSE
    SELECT o.id INTO v_outlet
    FROM public.outlets o
    WHERE o.owner_id = auth.uid()
    ORDER BY o.created_at ASC
    LIMIT 1;
  END IF;

  IF v_outlet IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_outlet');
  END IF;

  v_code := upper(trim(COALESCE(p_code, '')));
  IF v_code = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'empty_code');
  END IF;

  SELECT * INTO v_profile
  FROM public.outlet_affiliate_profiles
  WHERE upper(referral_code) = v_code
    AND outlet_id <> v_outlet
    AND is_active
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'code_not_found');
  END IF;

  UPDATE public.outlets
  SET referred_by_code = v_profile.referral_code
  WHERE id = v_outlet;

  IF EXISTS (
    SELECT 1 FROM public.supporters
    WHERE outlet_id = v_outlet AND status = 'active'
  ) THEN
    PERFORM public.record_affiliate_closing_for(v_outlet, NULL);
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'referral_code', v_profile.referral_code,
    'outlet_id', v_outlet
  );
END;
$$;

REVOKE ALL ON FUNCTION public.set_outlet_referral(TEXT, UUID) FROM anon;
REVOKE ALL ON FUNCTION public.set_outlet_referral(TEXT, UUID) FROM public;
GRANT EXECUTE ON FUNCTION public.set_outlet_referral(TEXT, UUID) TO authenticated;
