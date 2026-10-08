-- Fix: "Verifikasi gagal" saat submit KYC.
-- Penyebab: migrasi 2026-10-21-kasirgo-fix-kyc-nik-year.sql menulis ulang
-- submit_kyc() dengan INSERT ke kolom yang TIDAK ADA di tabel outlet_kyc:
--   - phone_digits  -> kolom asli = phone
--   - submitted_at  -> kolom asli = verified_at (tidak ada submitted_at)
-- Akibatnya setiap submit outlet yang belum verified (mis. outlet baru /
-- rejected) melempar 42703 undefined_column -> app menampilkan "Verifikasi gagal".
-- Selain itu statusnya 'pending_review' + auto_verified=false padahal spec
-- Phase 7.8 memakai auto-verify on-device + server.
--
-- Perbaikan: submit_kyc() ditulis ulang memakai kolom yang benar
-- (phone, auto_verified, verified_at) + mengembalikan AUTO-VERIFY
-- (v_all_ok -> 'verified' & auto_verified=true), sambil MEMPERTAHANKAN
-- perbaikan NIK dari migrasi 2026-10-21 (tahun lahir 2 digit apa pun valid,
-- hanya tolak bila = tahun berjalan).
CREATE OR REPLACE FUNCTION public.submit_kyc(
  p_outlet UUID,
  p_full_name TEXT,
  p_phone TEXT,
  p_email TEXT,
  p_store_name TEXT,
  p_store_address TEXT,
  p_ktp_path TEXT,
  p_selfie_path TEXT,
  p_nik TEXT DEFAULT NULL,
  p_consent BOOLEAN DEFAULT FALSE
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $fn$
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

  IF NOT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid() AND u.email_confirmed_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'email_unverified';
  END IF;

  v_phone_digits := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  IF length(v_phone_digits) < 10 OR length(v_phone_digits) > 15
     OR NOT (v_phone_digits LIKE '08%' OR v_phone_digits LIKE '628%') THEN
    RAISE EXCEPTION 'invalid_phone';
  END IF;

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
    IF v_dd NOT BETWEEN 1 AND 31 OR v_mm NOT BETWEEN 1 AND 12 THEN
      RAISE EXCEPTION 'invalid_nik';
    END IF;
    -- Tahun lahir 2 digit APA PUN valid (orang bisa lahir 1900-an).
    -- Hanya tolak bila tahun lahir = tahun berjalan (bayi < 1 th).
    IF v_yy = (extract(year FROM now())::int % 100) THEN
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
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    email = EXCLUDED.email,
    store_name = EXCLUDED.store_name,
    store_address = EXCLUDED.store_address,
    ktp_image_path = EXCLUDED.ktp_image_path,
    selfie_ktp_image_path = EXCLUDED.selfie_ktp_image_path,
    status = EXCLUDED.status,
    auto_verified = EXCLUDED.auto_verified,
    nik_hash = EXCLUDED.nik_hash,
    phone_hash = EXCLUDED.phone_hash,
    verified_at = EXCLUDED.verified_at,
    reject_reason = NULL,
    updated_at = NOW();

  RETURN jsonb_build_object(
    'status', v_status,
    'auto_verified', v_all_ok,
    'message', CASE WHEN v_all_ok
      THEN 'Verifikasi berhasil'
      ELSE 'Data perlu ditinjau manual' END
  );
END
$fn$;

REVOKE ALL ON FUNCTION public.submit_kyc(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_kyc(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,BOOLEAN) TO authenticated;
