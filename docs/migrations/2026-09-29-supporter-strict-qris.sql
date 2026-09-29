-- ============================================================================
-- KasirGo — Hardening ST7.8: QRIS checkout Pendukung, trial otomatis,
-- iklan sponsor, dan peran ketat (anti fake data / self-activate premium)
-- Tanggal: 2026-09-29
--
-- Tujuan:
--   1. supporters: owner HANYA bisa SELECT. Aktivasi premium hanya lewat
--      RPC superadmin (admin_set_supporter_status). Checkout via RPC
--      (create/confirm/cancel) sehingga owner tidak bisa self-activate.
--   2. Trial 14 hari otomatis via RPC ensure_supporter_trial (dipanggil app
--      setelah KYC verified; idempotent).
--   3. submit_kyc diperketat: email harus terverifikasi, NIK 16 digit dengan
--      kode provinsi & tanggal lahir valid, nomor HP format Indonesia.
--   4. Seed config: iklan sponsor demo (objek, bukan string) + QRIS statis /
--      transfer manual untuk halaman pembayaran Program Pendukung.
--   5. Bersihkan aktivasi palsu sisa test (outlet "Toko Baru").
--
-- CARA PAKAI: Supabase Dashboard -> SQL Editor -> tempel semua -> RUN.
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. RLS supporters diperketat
-- ---------------------------------------------------------------------------
ALTER TABLE public.supporters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner manage own supporters" ON public.supporters;
DROP POLICY IF EXISTS "Owner read own supporters" ON public.supporters;
CREATE POLICY "Owner read own supporters" ON public.supporters
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = supporters.outlet_id AND o.owner_id = auth.uid()
  ));

DROP POLICY IF EXISTS "Superadmin full access supporters" ON public.supporters;
CREATE POLICY "Superadmin full access supporters" ON public.supporters
  FOR ALL
  USING (public.is_platform_admin())
  WITH CHECK (public.is_platform_admin());

-- ---------------------------------------------------------------------------
-- 2. RPC trial + checkout + verifikasi admin
-- ---------------------------------------------------------------------------
ALTER TABLE public.supporters DROP CONSTRAINT IF EXISTS supporters_status_check;
ALTER TABLE public.supporters ADD CONSTRAINT supporters_status_check
  CHECK (status = ANY (ARRAY['trial'::text, 'active'::text, 'expired'::text,
                             'cancelled'::text, 'pending'::text,
                             'pending_verification'::text]));

CREATE OR REPLACE FUNCTION public.ensure_supporter_trial(p_outlet UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_days INT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.outlets o WHERE o.id = p_outlet AND o.owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  SELECT COALESCE((value->>'trial_days')::int, 14) INTO v_days
  FROM (SELECT value FROM public.platform_configs WHERE key = 'billing'
        ORDER BY version DESC LIMIT 1) c;

  INSERT INTO public.entitlements (outlet_id, is_supporter, ad_free, features, trial_ends_at)
  VALUES (p_outlet, false, false, '{}'::jsonb, now() + make_interval(days => v_days))
  ON CONFLICT (outlet_id) DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM public.supporters WHERE outlet_id = p_outlet) THEN
    INSERT INTO public.supporters (
      outlet_id, tier, amount, status, trial_started_at,
      start_date, end_date, auto_renew)
    VALUES (
      p_outlet, 'pendukung', 0, 'trial', now(),
      now(), now() + make_interval(days => v_days), true);
  END IF;

  RETURN jsonb_build_object('status', 'trial', 'trial_days', v_days);
END;
$$;
GRANT EXECUTE ON FUNCTION public.ensure_supporter_trial(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.create_supporter_checkout(
  p_outlet UUID, p_order_id TEXT, p_amount NUMERIC DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_price NUMERIC;
  v_period INT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.outlets o WHERE o.id = p_outlet AND o.owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  SELECT COALESCE((value->>'supporter_price')::numeric, 50000),
         COALESCE((value->>'period_days')::int, 30)
    INTO v_price, v_period
  FROM (SELECT value FROM public.platform_configs WHERE key = 'billing'
        ORDER BY version DESC LIMIT 1) c;

  -- Harga selalu dari config server-side (client amount diabaikan).
  UPDATE public.supporters
     SET status = 'cancelled', updated_at = now()
   WHERE outlet_id = p_outlet AND status IN ('pending', 'pending_verification');

  INSERT INTO public.supporters (
    outlet_id, tier, amount, status, start_date, auto_renew, pg_reference_id)
  VALUES (p_outlet, 'pendukung', v_price, 'pending', now(), true, p_order_id);

  RETURN jsonb_build_object(
    'order_id', p_order_id, 'amount', v_price,
    'period_days', v_period, 'status', 'pending');
END;
$$;
GRANT EXECUTE ON FUNCTION public.create_supporter_checkout(UUID, TEXT, NUMERIC) TO authenticated;

CREATE OR REPLACE FUNCTION public.confirm_supporter_payment(p_outlet UUID, p_order_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id UUID;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.outlets o WHERE o.id = p_outlet AND o.owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  UPDATE public.supporters
     SET status = 'pending_verification', updated_at = now()
   WHERE outlet_id = p_outlet AND pg_reference_id = p_order_id AND status = 'pending'
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'not_pending';
  END IF;

  RETURN jsonb_build_object('status', 'pending_verification');
END;
$$;
GRANT EXECUTE ON FUNCTION public.confirm_supporter_payment(UUID, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.cancel_supporter_checkout(p_outlet UUID, p_order_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.outlets o WHERE o.id = p_outlet AND o.owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  UPDATE public.supporters
     SET status = 'cancelled', updated_at = now()
   WHERE outlet_id = p_outlet AND pg_reference_id = p_order_id AND status = 'pending';

  RETURN jsonb_build_object('status', 'cancelled');
END;
$$;
GRANT EXECUTE ON FUNCTION public.cancel_supporter_checkout(UUID, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_supporter_auto_renew(p_outlet UUID, p_value BOOLEAN)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.outlets o WHERE o.id = p_outlet AND o.owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  UPDATE public.supporters
     SET auto_renew = p_value, updated_at = now()
   WHERE outlet_id = p_outlet AND status = 'active';

  RETURN jsonb_build_object('auto_renew', p_value);
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_supporter_auto_renew(UUID, BOOLEAN) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_supporter_status(
  p_supporter_id UUID, p_approve BOOLEAN
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_outlet UUID;
BEGIN
  IF NOT public.is_platform_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_approve THEN
    UPDATE public.supporters
       SET status = 'active', start_date = now(),
           end_date = now() + INTERVAL '30 days', updated_at = now()
     WHERE id = p_supporter_id AND status IN ('pending', 'pending_verification', 'trial')
    RETURNING outlet_id INTO v_outlet;

    IF v_outlet IS NULL THEN
      RAISE EXCEPTION 'not_found';
    END IF;

    INSERT INTO public.entitlements (outlet_id, is_supporter, ad_free, features)
    VALUES (v_outlet, true, true, '{}'::jsonb)
    ON CONFLICT (outlet_id) DO UPDATE
      SET is_supporter = true, ad_free = true, updated_at = now();

    INSERT INTO public.billing_events (outlet_id, event, amount, status, ref)
    SELECT outlet_id, 'supporter_activated', amount, 'active', pg_reference_id
      FROM public.supporters WHERE id = p_supporter_id;
  ELSE
    UPDATE public.supporters
       SET status = 'cancelled', updated_at = now()
     WHERE id = p_supporter_id
    RETURNING outlet_id INTO v_outlet;

    IF v_outlet IS NOT NULL THEN
      UPDATE public.entitlements
         SET is_supporter = false, ad_free = false, updated_at = now()
       WHERE outlet_id = v_outlet;
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_set_supporter_status(UUID, BOOLEAN) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. submit_kyc diperketat (email verified + format NIK/HP)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_kyc(
  p_outlet UUID,
  p_full_name TEXT,
  p_phone TEXT,
  p_email TEXT,
  p_store_name TEXT,
  p_store_address TEXT,
  p_ktp_path TEXT,
  p_selfie_path TEXT,
  p_nik TEXT,
  p_consent BOOLEAN
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $$
DECLARE
  v_nik_digits TEXT;
  v_phone_digits TEXT;
  v_nik_hash TEXT;
  v_phone_hash TEXT;
  v_row public.outlet_kyc;
  v_all_ok BOOLEAN;
  v_status TEXT;
  v_dd INT;
  v_mm INT;
  v_yy INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.outlets o WHERE o.id = p_outlet AND o.owner_id = auth.uid()) THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  -- Email akun harus sudah terverifikasi (anti fake akun).
  IF NOT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid() AND u.email_confirmed_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'email_unverified';
  END IF;

  -- Nomor HP: 10-15 digit, format Indonesia (08xx / 628xx).
  v_phone_digits := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  IF length(v_phone_digits) < 10 OR length(v_phone_digits) > 15
     OR NOT (v_phone_digits LIKE '08%' OR v_phone_digits LIKE '628%') THEN
    RAISE EXCEPTION 'invalid_phone';
  END IF;

  -- NIK (opsional): jika diisi harus 16 digit, kode provinsi & tanggal lahir valid.
  v_nik_digits := regexp_replace(coalesce(p_nik, ''), '\D', '', 'g');
  IF length(v_nik_digits) > 0 THEN
    IF length(v_nik_digits) <> 16 THEN
      RAISE EXCEPTION 'invalid_nik';
    END IF;
    IF (substring(v_nik_digits, 1, 2))::int NOT BETWEEN 11 AND 96 THEN
      RAISE EXCEPTION 'invalid_nik';
    END IF;
    v_dd := (substring(v_nik_digits, 7, 2))::int;
    IF v_dd >= 40 THEN v_dd := v_dd - 40; END IF;
    v_mm := (substring(v_nik_digits, 9, 2))::int;
    v_yy := (substring(v_nik_digits, 11, 2))::int;
    IF v_dd NOT BETWEEN 1 AND 31 OR v_mm NOT BETWEEN 1 AND 12
       OR v_yy > (extract(year FROM now())::int % 100) THEN
      RAISE EXCEPTION 'invalid_nik';
    END IF;
  END IF;

  SELECT * INTO v_row FROM public.outlet_kyc WHERE outlet_id = p_outlet;
  IF FOUND AND v_row.status = 'verified' THEN
    RETURN jsonb_build_object('status','verified','auto_verified',true,
      'message','Outlet sudah terverifikasi');
  END IF;

  v_nik_hash := CASE WHEN length(v_nik_digits) >= 16
    THEN encode(digest(v_nik_digits,'sha256'),'hex') ELSE NULL END;
  v_phone_hash := CASE WHEN length(v_phone_digits) >= 10
    THEN encode(digest(v_phone_digits,'sha256'),'hex') ELSE NULL END;

  IF v_nik_hash IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.outlet_kyc WHERE nik_hash = v_nik_hash AND outlet_id <> p_outlet) THEN
    RAISE EXCEPTION 'duplicate_nik';
  END IF;
  IF v_phone_hash IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.outlet_kyc WHERE phone_hash = v_phone_hash AND outlet_id <> p_outlet) THEN
    RAISE EXCEPTION 'duplicate_phone';
  END IF;

  v_all_ok :=
    p_email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
    AND length(v_phone_digits) >= 10
    AND length(trim(coalesce(p_store_name,''))) >= 3
    AND length(trim(coalesce(p_store_address,''))) >= 5
    AND length(trim(coalesce(p_full_name,''))) >= 3
    AND coalesce(p_consent,false)
    AND p_ktp_path IS NOT NULL
    AND p_selfie_path IS NOT NULL;

  v_status := CASE WHEN v_all_ok THEN 'verified' ELSE 'pending_review' END;

  INSERT INTO public.outlet_kyc (
    outlet_id, full_name, phone, email, store_name, store_address,
    ktp_image_path, selfie_ktp_image_path, status, auto_verified,
    nik_hash, phone_hash, verified_at, updated_at)
  VALUES (
    p_outlet, p_full_name, p_phone, p_email, p_store_name, p_store_address,
    p_ktp_path, p_selfie_path, v_status, v_all_ok,
    v_nik_hash, v_phone_hash,
    CASE WHEN v_all_ok THEN NOW() ELSE NULL END, NOW())
  ON CONFLICT (outlet_id) DO UPDATE SET
    full_name=EXCLUDED.full_name, phone=EXCLUDED.phone, email=EXCLUDED.email,
    store_name=EXCLUDED.store_name, store_address=EXCLUDED.store_address,
    ktp_image_path=EXCLUDED.ktp_image_path, selfie_ktp_image_path=EXCLUDED.selfie_ktp_image_path,
    status=EXCLUDED.status, auto_verified=EXCLUDED.auto_verified,
    nik_hash=EXCLUDED.nik_hash, phone_hash=EXCLUDED.phone_hash,
    verified_at=EXCLUDED.verified_at, reject_reason=NULL, updated_at=NOW();

  RETURN jsonb_build_object('status', v_status, 'auto_verified', v_all_ok,
    'message', CASE WHEN v_all_ok THEN 'Verifikasi berhasil' ELSE 'Data perlu ditinjau manual' END);
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. Seed config: iklan sponsor demo (objek) + QRIS/transfer pembayaran
-- ---------------------------------------------------------------------------
UPDATE public.platform_configs
   SET value = jsonb_set(
         value,
         '{sponsor_local}',
         '[
           {"id":"demo-kopi","title":"Kopi Robusta Lokal","subtitle":"Supplier kopi & teh untuk warung — harga grosir","cta":"Lihat","url":"https://www.detik.com/","category":"umum"},
           {"id":"demo-kulakan","title":"Kulakan Gula & Minyak","subtitle":"Kirim se-kota, bayar tempoe","cta":"Info","url":"https://www.detik.com/","category":"umum"}
         ]'::jsonb,
         true),
       version = version + 1,
       updated_at = now()
 WHERE key = 'ads';

UPDATE public.platform_configs
   SET value = value || jsonb_build_object(
         'qris_static_payload', '00020101021226660014ID.CO.QRIS.WWW0118DEMO-QRIS-KASIRGO5204581253033605802ID5913KasirGoDemo6007JAKARTA6304ABCD',
         'manual_transfer', jsonb_build_object(
           'bank', 'BCA', 'account', '1234567890', 'name', 'KasirGo Demo')),
       version = version + 1,
       updated_at = now()
 WHERE key = 'billing'
   AND value->>'qris_static_payload' IS NULL;

-- ---------------------------------------------------------------------------
-- 5. Bersihkan aktivasi palsu sisa test (outlet "Toko Baru" milik superadmin)
-- ---------------------------------------------------------------------------
UPDATE public.supporters
   SET status = 'cancelled', updated_at = now()
 WHERE status = 'active'
   AND outlet_id = (SELECT id FROM public.outlets WHERE name = 'Toko Baru' LIMIT 1);

UPDATE public.entitlements
   SET is_supporter = false, ad_free = false, updated_at = now()
 WHERE outlet_id = (SELECT id FROM public.outlets WHERE name = 'Toko Baru' LIMIT 1);

-- ============================================================================
-- VERIFIKASI:
--   SELECT policyname FROM pg_policies WHERE tablename='supporters';
--   SELECT value->'sponsor_local' FROM public.platform_configs WHERE key='ads';
--   SELECT routine_name FROM information_schema.routines
--    WHERE routine_name LIKE 'supporter%' OR routine_name LIKE 'admin_set_supporter%';
-- ============================================================================
