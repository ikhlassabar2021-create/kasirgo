-- ============================================================================
-- 2026-10-21-kasirgo-fix-owner-affiliate.sql
-- FIX #12 (owner): afiliasi otomatis untuk setiap outlet + RPC portal afiliasi.
--
-- Isi:
--   1. Tabel outlet_affiliate_profiles: 1 baris per outlet (auto via trigger).
--      - kode referral per outlet (KGO + 6 karakter)
--      - link afiliasi dihitung klien (base + ?ref=kode)
--      - rekening pembayaran komisi
--   2. Tabel outlet_affiliate_closings: catatan komisi/closing per outlet.
--      (closing = outlet baru yang mendaftar memakai kode referral outlet ini)
--   3. RPC affiliate_owner_me(): profil + ringkasan + daftar closing.
--   4. RPC affiliate_owner_update(): simpan rekening & info payout.
--   5. RLS: owner kelola miliknya; superadmin full.
--
-- Catatan desain:
--   - Auto-affiliate: trigger AFTER INSERT ON outlets -> INSERT profil
--     (idempotent, ON CONFLICT DO NOTHING) sehingga outlet baru langsung punya
--     kode referral afiliasi tanpa perlu mendaftar manual.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tabel profil afiliasi per outlet.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.outlet_affiliate_profiles (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id           UUID NOT NULL UNIQUE REFERENCES public.outlets(id) ON DELETE CASCADE,
  referral_code       TEXT NOT NULL UNIQUE,
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  commission_percent  NUMERIC(5,2) NOT NULL DEFAULT 5,
  bank_name           TEXT,
  bank_account_name   TEXT,
  bank_account_number TEXT,
  total_earned        NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_oap_outlet ON public.outlet_affiliate_profiles (outlet_id);

-- ----------------------------------------------------------------------------
-- 2. Tabel closing (komisi) per outlet afiliasi.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.outlet_affiliate_closings (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id        UUID NOT NULL REFERENCES public.outlet_affiliate_profiles(id) ON DELETE CASCADE,
  referred_outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL,
  referred_outlet_name TEXT,
  description       TEXT,
  amount            NUMERIC(12,2) NOT NULL DEFAULT 0,
  status            TEXT NOT NULL DEFAULT 'unpaid'
                    CHECK (status IN ('unpaid','paid','cancelled')),
  paid_at           TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_oac_profile ON public.outlet_affiliate_closings (profile_id, created_at DESC);

-- ----------------------------------------------------------------------------
-- 3. Trigger: outlet baru otomatis jadi afiliasi (auto-affiliate).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_auto_outlet_affiliate()
RETURNS TRIGGER AS $$
DECLARE
  v_code TEXT;
BEGIN
  -- Kode unik: KGO + 6 alfanumerik.
  LOOP
    v_code := 'KGO' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.outlet_affiliate_profiles WHERE referral_code = v_code);
  END LOOP;

  INSERT INTO public.outlet_affiliate_profiles
    (outlet_id, referral_code)
  VALUES
    (NEW.id, v_code)
  ON CONFLICT (outlet_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_auto_outlet_affiliate ON public.outlets;
CREATE TRIGGER trg_auto_outlet_affiliate
  AFTER INSERT ON public.outlets
  FOR EACH ROW EXECUTE FUNCTION public.fn_auto_outlet_affiliate();

-- Backfill: outlet lama yang belum punya profil.
INSERT INTO public.outlet_affiliate_profiles (outlet_id, referral_code)
SELECT o.id,
       'KGO' || upper(substr(md5(o.id::text || clock_timestamp()::text), 1, 6))
FROM public.outlets o
WHERE NOT EXISTS (SELECT 1 FROM public.outlet_affiliate_profiles p WHERE p.outlet_id = o.id)
ON CONFLICT (outlet_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. RPC affiliate_owner_me(): profil + ringkasan + closing.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.affiliate_owner_me(p_outlet_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_profile RECORD;
  v_earned NUMERIC;
  v_unpaid NUMERIC;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  IF NOT public.is_outlet_owner(p_outlet_id) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT * INTO v_profile FROM public.outlet_affiliate_profiles
  WHERE outlet_id = p_outlet_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_earned
  FROM public.outlet_affiliate_closings
  WHERE profile_id = v_profile.id AND status IN ('unpaid','paid');
  SELECT COALESCE(SUM(amount), 0) INTO v_unpaid
  FROM public.outlet_affiliate_closings
  WHERE profile_id = v_profile.id AND status = 'unpaid';

  RETURN jsonb_build_object(
    'found', TRUE,
    'profile', jsonb_build_object(
      'id', v_profile.id,
      'outlet_id', v_profile.outlet_id,
      'referral_code', v_profile.referral_code,
      'is_active', v_profile.is_active,
      'commission_percent', v_profile.commission_percent,
      'bank_name', v_profile.bank_name,
      'bank_account_name', v_profile.bank_account_name,
      'bank_account_number', v_profile.bank_account_number,
      'total_earned', v_earned
    ),
    'summary', jsonb_build_object(
      'commission_total', v_earned,
      'unpaid_total', v_unpaid,
      'closing_count', (SELECT COUNT(*) FROM public.outlet_affiliate_closings
                        WHERE profile_id = v_profile.id AND status <> 'cancelled')
    ),
    'closings', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', c.id,
        'referred_outlet_name', c.referred_outlet_name,
        'description', c.description,
        'amount', c.amount,
        'status', c.status,
        'created_at', c.created_at
      ) ORDER BY c.created_at DESC)
      FROM (
        SELECT * FROM public.outlet_affiliate_closings
        WHERE profile_id = v_profile.id
        ORDER BY created_at DESC LIMIT 50
      ) c
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.affiliate_owner_me(UUID) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.affiliate_owner_me(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. RPC affiliate_owner_update(): simpan rekening payout.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.affiliate_owner_update(
  p_outlet_id UUID,
  p_bank_name TEXT,
  p_bank_account_name TEXT,
  p_bank_account_number TEXT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_updated RECORD;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  IF NOT public.is_outlet_owner(p_outlet_id) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.outlet_affiliate_profiles
  SET bank_name = p_bank_name,
      bank_account_name = p_bank_account_name,
      bank_account_number = p_bank_account_number,
      updated_at = NOW()
  WHERE outlet_id = p_outlet_id
  RETURNING * INTO v_updated;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  RETURN jsonb_build_object('ok', TRUE, 'referral_code', v_updated.referral_code);
END;
$$;

REVOKE ALL ON FUNCTION public.affiliate_owner_update(UUID, TEXT, TEXT, TEXT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.affiliate_owner_update(UUID, TEXT, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. RLS.
-- ----------------------------------------------------------------------------
ALTER TABLE public.outlet_affiliate_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner manage own outlet_affiliate_profiles" ON public.outlet_affiliate_profiles;
CREATE POLICY "Owner manage own outlet_affiliate_profiles" ON public.outlet_affiliate_profiles
  FOR ALL TO authenticated
  USING (public.is_outlet_owner(outlet_id))
  WITH CHECK (public.is_outlet_owner(outlet_id));
DROP POLICY IF EXISTS "Superadmin all outlet_affiliate_profiles" ON public.outlet_affiliate_profiles;
CREATE POLICY "Superadmin all outlet_affiliate_profiles" ON public.outlet_affiliate_profiles
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

ALTER TABLE public.outlet_affiliate_closings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner read own outlet_affiliate_closings" ON public.outlet_affiliate_closings;
CREATE POLICY "Owner read own outlet_affiliate_closings" ON public.outlet_affiliate_closings
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.outlet_affiliate_profiles p
      WHERE p.id = outlet_affiliate_closings.profile_id
        AND public.is_outlet_owner(p.outlet_id)
    )
  );
DROP POLICY IF EXISTS "Superadmin all outlet_affiliate_closings" ON public.outlet_affiliate_closings;
CREATE POLICY "Superadmin all outlet_affiliate_closings" ON public.outlet_affiliate_closings
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

GRANT SELECT ON public.outlet_affiliate_profiles TO authenticated;
GRANT SELECT ON public.outlet_affiliate_closings TO authenticated;
