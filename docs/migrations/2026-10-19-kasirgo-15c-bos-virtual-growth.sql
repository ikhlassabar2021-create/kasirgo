-- ============================================================================
-- KASIRGO 3.0 - PHASE 15C / ST15-3
-- Bos Virtual Growth (BAGIAN 13.25.4/13.25.5/13.25.6):
--   product_bundles + product_bundle_items : paket bundling dijual 1 item POS
--   referral_codes                          : kode referral outlet (pembawa)
--   customer_referrals                      : tracking konversi referral
-- RLS: owner penuh atas outlet sendiri; superadmin penuh. Idempotent.
-- ============================================================================

-- 1. product_bundles (13.25.5)
CREATE TABLE IF NOT EXISTS public.product_bundles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  bundle_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  original_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_product_bundles_outlet
  ON public.product_bundles (outlet_id, is_active);

-- 1b. product_bundle_items: isi paket.
CREATE TABLE IF NOT EXISTS public.product_bundle_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bundle_id UUID NOT NULL REFERENCES public.product_bundles(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity NUMERIC(12,2) NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (bundle_id, product_id)
);
CREATE INDEX IF NOT EXISTS idx_bundle_items_bundle
  ON public.product_bundle_items (bundle_id);

-- 2. referral_codes (13.25.6) - kode outlet (pembawa), berjenjang.
CREATE TABLE IF NOT EXISTS public.referral_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,
  title TEXT DEFAULT '',
  reward_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  reward_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
  friend_reward_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  min_spend NUMERIC(12,2) NOT NULL DEFAULT 0,
  max_redemptions INT NOT NULL DEFAULT 0,
  redeemed_count INT NOT NULL DEFAULT 0,
  starts_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_referral_codes_outlet
  ON public.referral_codes (outlet_id, is_active);

-- 3. customer_referrals: tracking penggunaan kode (diajak).
CREATE TABLE IF NOT EXISTS public.customer_referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  referral_code_id UUID NOT NULL REFERENCES public.referral_codes(id) ON DELETE CASCADE,
  customer_name TEXT,
  customer_phone TEXT,
  transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
  spend_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','converted','rewarded')),
  converted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_customer_referrals_code
  ON public.customer_referrals (referral_code_id, status);

-- ============================================================================
-- RLS (pola sama dengan Phase 14/15B)
-- ============================================================================
DO $$
DECLARE
  t TEXT;
  tables TEXT[] := ARRAY['product_bundles','referral_codes','customer_referrals'];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'Superadmin full access ' || t, t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin())',
      'Superadmin full access ' || t, t
    );

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'Owner access own ' || t, t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL TO authenticated USING (public.is_outlet_owner(outlet_id)) WITH CHECK (public.is_outlet_owner(outlet_id))',
      'Owner access own ' || t, t
    );
  END LOOP;
END $$;

-- product_bundle_items: via bundle_id (owner bundle).
ALTER TABLE public.product_bundle_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access product_bundle_items" ON public.product_bundle_items;
CREATE POLICY "Superadmin full access product_bundle_items" ON public.product_bundle_items
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Owner access own product_bundle_items" ON public.product_bundle_items;
CREATE POLICY "Owner access own product_bundle_items" ON public.product_bundle_items
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.product_bundles b
          WHERE b.id = product_bundle_items.bundle_id
            AND public.is_outlet_owner(b.outlet_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM public.product_bundles b
          WHERE b.id = product_bundle_items.bundle_id
            AND public.is_outlet_owner(b.outlet_id)));

-- ============================================================================
-- Helper RPC: increment redeemed_count (owner outlet sendiri).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.increment_referral_redeemed(p_code_id uuid)
RETURNS void
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.referral_codes
     SET redeemed_count = redeemed_count + 1,
         updated_at = NOW()
   WHERE id = p_code_id
     AND (public.is_outlet_owner(outlet_id) OR public.is_platform_admin());
$$;
GRANT EXECUTE ON FUNCTION public.increment_referral_redeemed(uuid) TO authenticated;

-- ============================================================================
-- RPC publik: paket bundling aktif untuk katalog online (anon).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_public_bundles(p_outlet TEXT)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  bundle_price NUMERIC,
  original_price NUMERIC,
  item_count INT
)
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  SELECT b.id, b.name, COALESCE(b.description, ''), b.bundle_price, b.original_price,
         (SELECT COUNT(*)::int FROM public.product_bundle_items i WHERE i.bundle_id = b.id)
  FROM public.product_bundles b
  WHERE b.outlet_id = p_outlet::uuid
    AND b.is_active = true
    AND EXISTS (SELECT 1 FROM public.product_bundle_items i JOIN public.products p ON p.id = i.product_id
                WHERE i.bundle_id = b.id AND p.is_published = true AND p.stock > 0)
  ORDER BY b.name;
$$;
GRANT EXECUTE ON FUNCTION public.get_public_bundles(TEXT) TO anon, authenticated;
