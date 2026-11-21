-- ============================================================================
-- KasirGo -- Perbaikan Dashboard Owner & Kasir (No.1 - No.5)
-- Tanggal: 2026-12-15
-- Jalankan di Supabase Dashboard -> SQL Editor (idempotent).
--
-- Isi:
--   No.1  RPC delete_sample_data(): hapus produk contoh + transaksi contohnya.
--   No.2  RLS shifts: kasir/admin boleh UPDATE (tutup) shift miliknya sendiri.
--   No.4  Kolom outlets.slug + trigger + RPC get_outlet_by_slug() (link pendek).
--   No.5  Kolom outlets.referred_by_code + capture dari metadata + trigger
--         komisi afiliasi saat supporter menjadi 'active' + RPC set_outlet_referral.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- No.1: Hapus produk contoh BESERTA transaksi contohnya.
-- Sebelumnya hanya products yang dihapus, transaksi latihan tetap ada sehingga
-- laporan masih menampilkan omzet contoh. RPC ini menghapus transaksi yang
-- memakai produk kategori 'Contoh' (transaction_items ikut CASCADE) lalu
-- menghapus produknya.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_sample_data(p_outlet UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_products INT := 0;
  v_transactions INT := 0;
BEGIN
  IF NOT public.is_outlet_owner(p_outlet) AND NOT public.is_platform_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  WITH sample AS (
    SELECT id FROM public.products
    WHERE outlet_id = p_outlet AND category = 'Contoh'
  ), deleted AS (
    DELETE FROM public.transactions t
    WHERE t.outlet_id = p_outlet
      AND EXISTS (
        SELECT 1
        FROM public.transaction_items ti
        WHERE ti.transaction_id = t.id
          AND ti.product_id IN (SELECT id FROM sample)
      )
    RETURNING t.id
  )
  SELECT COUNT(*) INTO v_transactions FROM deleted;

  DELETE FROM public.products
  WHERE outlet_id = p_outlet AND category = 'Contoh';
  GET DIAGNOSTICS v_products = ROW_COUNT;

  RETURN jsonb_build_object(
    'products', v_products,
    'transactions', v_transactions
  );
END;
$$;

REVOKE ALL ON FUNCTION public.delete_sample_data(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_sample_data(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- No.2: Kasir dapat menutup shift miliknya sendiri.
-- Policy lama hanya: owner FOR ALL, staff SELECT, cashier INSERT. Tidak ada
-- UPDATE -> closeShift meng-update 0 baris dan app menampilkan "Gagal menutup".
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Cashier close own shifts" ON public.shifts;
CREATE POLICY "Cashier close own shifts" ON public.shifts
  FOR UPDATE
  USING (
    shifts.user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.outlet_id = shifts.outlet_id
        AND ur.role IN ('cashier', 'admin')
    )
  )
  WITH CHECK (
    shifts.user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.outlet_id = shifts.outlet_id
        AND ur.role IN ('cashier', 'admin')
    )
  );

-- ----------------------------------------------------------------------------
-- No.4: Link katalog pendek berbasis nama toko (slug).
-- Contoh: https://dokterbisnis.web.id/#/s/toko-test
-- ----------------------------------------------------------------------------
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS slug TEXT;

CREATE OR REPLACE FUNCTION public.slugify_outlet_name(p_name TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT trim(both '-' from regexp_replace(
    lower(COALESCE(NULLIF(trim(p_name), ''), 'toko')),
    '[^a-z0-9]+', '-', 'g'
  ));
$$;

CREATE OR REPLACE FUNCTION public.ensure_outlet_slug()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_base TEXT;
  v_candidate TEXT;
  v_n INT := 1;
BEGIN
  IF NEW.slug IS NOT NULL AND length(trim(NEW.slug)) > 0 THEN
    RETURN NEW;
  END IF;

  v_base := public.slugify_outlet_name(NEW.name);
  IF v_base IS NULL OR v_base = '' THEN
    v_base := 'toko';
  END IF;

  v_candidate := v_base;
  WHILE EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.slug = v_candidate AND o.id <> NEW.id
  ) LOOP
    v_n := v_n + 1;
    v_candidate := v_base || '-' || v_n::text;
  END LOOP;

  NEW.slug := v_candidate;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_outlet_slug ON public.outlets;
CREATE TRIGGER trg_outlet_slug
  BEFORE INSERT OR UPDATE OF name ON public.outlets
  FOR EACH ROW EXECUTE FUNCTION public.ensure_outlet_slug();

-- Backfill outlet lama yang belum punya slug.
DO $$
DECLARE
  r RECORD;
  v_base TEXT;
  v_candidate TEXT;
  v_n INT;
BEGIN
  FOR r IN
    SELECT id, name FROM public.outlets
    WHERE slug IS NULL OR trim(slug) = ''
  LOOP
    v_base := public.slugify_outlet_name(r.name);
    IF v_base IS NULL OR v_base = '' THEN
      v_base := 'toko';
    END IF;

    v_candidate := v_base;
    v_n := 1;
    WHILE EXISTS (
      SELECT 1 FROM public.outlets o
      WHERE o.slug = v_candidate AND o.id <> r.id
    ) LOOP
      v_n := v_n + 1;
      v_candidate := v_base || '-' || v_n::text;
    END LOOP;

    UPDATE public.outlets SET slug = v_candidate WHERE id = r.id;
  END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_outlets_slug ON public.outlets (slug);

CREATE OR REPLACE FUNCTION public.get_outlet_by_slug(p_slug TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r RECORD;
BEGIN
  SELECT id, name, slug INTO r
  FROM public.outlets
  WHERE slug = lower(trim(p_slug))
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  RETURN jsonb_build_object(
    'found', true,
    'id', r.id,
    'name', r.name,
    'slug', r.slug
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_outlet_by_slug(TEXT) FROM public;
GRANT EXECUTE ON FUNCTION public.get_outlet_by_slug(TEXT) TO anon, authenticated;

-- ----------------------------------------------------------------------------
-- No.5: Kode referral afiliasi terkoneksi saat upgrade Program Pendukung.
-- Alur:
--   1. Pendaftar owner mengirim `referral_code` di metadata signup.
--   2. Trigger outlets menyalinnya ke outlets.referred_by_code.
--   3. Saat supporters.status menjadi 'active', trigger mencatat komisi ke
--      outlet_affiliate_closings milik pemilik kode (muncul di dashboard owner
--      & superadmin).
--   4. Owner lama dapat memasang kode via RPC set_outlet_referral().
-- ----------------------------------------------------------------------------
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS referred_by_code TEXT;

CREATE OR REPLACE FUNCTION public.outlet_capture_referral()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.referred_by_code IS NULL OR trim(NEW.referred_by_code) = '' THEN
    SELECT NULLIF(trim(u.raw_user_meta_data->>'referral_code'), '')
      INTO NEW.referred_by_code
    FROM auth.users u
    WHERE u.id = NEW.owner_id;
  END IF;

  IF NEW.referred_by_code IS NOT NULL THEN
    NEW.referred_by_code := upper(trim(NEW.referred_by_code));
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_outlet_capture_referral ON public.outlets;
CREATE TRIGGER trg_outlet_capture_referral
  BEFORE INSERT ON public.outlets
  FOR EACH ROW EXECUTE FUNCTION public.outlet_capture_referral();

-- Catat satu closing komisi untuk outlet (idempotent).
CREATE OR REPLACE FUNCTION public.record_affiliate_closing_for(
  p_outlet UUID,
  p_amount NUMERIC DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code TEXT;
  v_name TEXT;
  v_profile RECORD;
  v_amount NUMERIC;
  v_base_amount NUMERIC;
BEGIN
  SELECT o.referred_by_code, o.name
    INTO v_code, v_name
  FROM public.outlets o
  WHERE o.id = p_outlet;

  IF v_code IS NULL OR trim(v_code) = '' THEN
    RETURN;
  END IF;

  SELECT * INTO v_profile
  FROM public.outlet_affiliate_profiles
  WHERE referral_code = v_code
    AND outlet_id <> p_outlet
    AND is_active
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Jangan dobel untuk outlet yang sama.
  IF EXISTS (
    SELECT 1 FROM public.outlet_affiliate_closings
    WHERE profile_id = v_profile.id
      AND referred_outlet_id = p_outlet
      AND status <> 'cancelled'
  ) THEN
    RETURN;
  END IF;

  v_base_amount := p_amount;
  IF v_base_amount IS NULL THEN
    SELECT s.amount INTO v_base_amount
    FROM public.supporters s
    WHERE s.outlet_id = p_outlet AND s.status = 'active'
    ORDER BY s.start_date DESC NULLS LAST
    LIMIT 1;
  END IF;

  v_amount := round(
    COALESCE(v_base_amount, 0) * COALESCE(v_profile.commission_percent, 5) / 100.0,
    2
  );

  INSERT INTO public.outlet_affiliate_closings
    (profile_id, referred_outlet_id, referred_outlet_name, description, amount, status)
  VALUES (
    v_profile.id,
    p_outlet,
    v_name,
    'Komisi upgrade Program Pendukung ('
      || COALESCE(v_profile.commission_percent, 5)::text || '%)',
    v_amount,
    'unpaid'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.on_supporter_active_closing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'active'
     AND (TG_OP = 'INSERT' OR COALESCE(OLD.status, '') <> 'active') THEN
    PERFORM public.record_affiliate_closing_for(NEW.outlet_id, NEW.amount);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_supporter_affiliate_closing ON public.supporters;
CREATE TRIGGER trg_supporter_affiliate_closing
  AFTER INSERT OR UPDATE OF status ON public.supporters
  FOR EACH ROW EXECUTE FUNCTION public.on_supporter_active_closing();

-- Owner lama dapat memasang kode referral setelah akunnya ada.
CREATE OR REPLACE FUNCTION public.set_outlet_referral(p_code TEXT)
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
  SELECT o.id INTO v_outlet
  FROM public.outlets o
  WHERE o.owner_id = auth.uid()
  ORDER BY o.created_at ASC
  LIMIT 1;

  IF v_outlet IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_outlet');
  END IF;

  v_code := upper(trim(COALESCE(p_code, '')));
  IF v_code = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'empty_code');
  END IF;

  SELECT * INTO v_profile
  FROM public.outlet_affiliate_profiles
  WHERE referral_code = v_code
    AND outlet_id <> v_outlet
    AND is_active
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'code_not_found');
  END IF;

  UPDATE public.outlets
  SET referred_by_code = v_profile.referral_code
  WHERE id = v_outlet;

  -- Bila sudah aktif sebagai Pendukung, catat komisi sekarang.
  IF EXISTS (
    SELECT 1 FROM public.supporters
    WHERE outlet_id = v_outlet AND status = 'active'
  ) THEN
    PERFORM public.record_affiliate_closing_for(v_outlet, NULL);
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'referral_code', v_profile.referral_code
  );
END;
$$;

REVOKE ALL ON FUNCTION public.set_outlet_referral(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.set_outlet_referral(TEXT) TO authenticated;

-- Backfill komisi untuk supporter aktif yang sudah punya referred_by_code.
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT DISTINCT s.outlet_id
    FROM public.supporters s
    JOIN public.outlets o ON o.id = s.outlet_id
    WHERE s.status = 'active'
      AND o.referred_by_code IS NOT NULL
      AND trim(o.referred_by_code) <> ''
  LOOP
    PERFORM public.record_affiliate_closing_for(r.outlet_id, NULL);
  END LOOP;
END $$;

-- ============================================================================
-- SELESAI
-- ============================================================================
