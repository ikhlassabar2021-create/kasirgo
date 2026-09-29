-- ============================================================================
-- KasirGo — KYC Wajib (Onboarding) + Anti-duplikat
-- Tanggal: 2026-09-29
--
-- Tujuan (ST7.8-7):
--   - Tabel outlet_kyc (buat bila belum ada) dengan model status:
--     unsubmitted | draft | pending_review | verified | rejected
--   - Data teks & hash saja; FOTO tetap LOKAL di HP (kebijakan foto lokal).
--     Kolom *_image_path hanya menyimpan path lokal / penanda, BUKAN file.
--   - Anti-duplikat: hash NIK & nomor HP unik (SHA-256, dikirim dari klien).
--   - Auto-verify: Edge Function verify_kyc mengisi auto_verified + status.
--   - RLS: owner outlet sendiri; superadmin/Edge full.
--
-- CARA PAKAI:
--   Supabase Dashboard -> SQL Editor -> tempel semua -> RUN.
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.outlet_kyc (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID UNIQUE REFERENCES public.outlets(id) ON DELETE CASCADE,
  full_name TEXT,
  phone TEXT,
  email TEXT,
  store_name TEXT,
  store_address TEXT,
  ktp_image_path TEXT,          -- path LOKAL di HP (kebijakan foto lokal)
  selfie_ktp_image_path TEXT,   -- path LOKAL di HP
  status TEXT NOT NULL DEFAULT 'unsubmitted'
    CHECK (status IN ('unsubmitted','draft','pending_review','verified','rejected')),
  auto_verified BOOLEAN DEFAULT false,
  reject_reason TEXT,
  nik_hash TEXT,                -- SHA-256 NIK (anti-duplikat)
  phone_hash TEXT,              -- SHA-256 nomor HP (anti-duplikat)
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Kolom tambahan bila tabel sudah ada versi lama.
ALTER TABLE public.outlet_kyc ADD COLUMN IF NOT EXISTS status TEXT;
ALTER TABLE public.outlet_kyc ADD COLUMN IF NOT EXISTS auto_verified BOOLEAN DEFAULT false;
ALTER TABLE public.outlet_kyc ADD COLUMN IF NOT EXISTS reject_reason TEXT;
ALTER TABLE public.outlet_kyc ADD COLUMN IF NOT EXISTS nik_hash TEXT;
ALTER TABLE public.outlet_kyc ADD COLUMN IF NOT EXISTS phone_hash TEXT;
ALTER TABLE public.outlet_kyc ADD COLUMN IF NOT EXISTS selfie_ktp_image_path TEXT;
ALTER TABLE public.outlet_kyc ADD COLUMN IF NOT EXISTS ktp_image_path TEXT;
ALTER TABLE public.outlet_kyc ADD COLUMN IF NOT EXISTS store_name TEXT;
ALTER TABLE public.outlet_kyc ADD COLUMN IF NOT EXISTS store_address TEXT;
ALTER TABLE public.outlet_kyc ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Index anti-duplikat.
CREATE INDEX IF NOT EXISTS idx_outlet_kyc_nik_hash ON public.outlet_kyc(nik_hash);
CREATE INDEX IF NOT EXISTS idx_outlet_kyc_phone_hash ON public.outlet_kyc(phone_hash);
CREATE INDEX IF NOT EXISTS idx_outlet_kyc_status ON public.outlet_kyc(status);

-- ----------------------------------------------------------------------------
-- RLS
-- ----------------------------------------------------------------------------
ALTER TABLE public.outlet_kyc ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access outlet_kyc" ON public.outlet_kyc;
CREATE POLICY "Superadmin full access outlet_kyc" ON public.outlet_kyc
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

DROP POLICY IF EXISTS "Owner manage own outlet_kyc" ON public.outlet_kyc;
CREATE POLICY "Owner manage own outlet_kyc" ON public.outlet_kyc
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = outlet_kyc.outlet_id AND o.owner_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = outlet_kyc.outlet_id AND o.owner_id = auth.uid()
  ));

-- ============================================================================
-- VERIFIKASI:
--   SELECT outlet_id, status, auto_verified FROM public.outlet_kyc;
-- ============================================================================

-- ============================================================================
-- RPC submit_kyc: auto-verify 6 field + anti-duplikat (hash NIK/HP)
-- Dipanggil klien saat online. Foto hanya path lokal.
-- ============================================================================
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
  v_nik_hash TEXT;
  v_phone_hash TEXT;
  v_row public.outlet_kyc;
  v_all_ok BOOLEAN;
  v_status TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.outlets o WHERE o.id = p_outlet AND o.owner_id = auth.uid()) THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  SELECT * INTO v_row FROM public.outlet_kyc WHERE outlet_id = p_outlet;
  IF FOUND AND v_row.status = 'verified' THEN
    RETURN jsonb_build_object('status','verified','auto_verified',true,
      'message','Outlet sudah terverifikasi');
  END IF;

  v_nik_hash := CASE WHEN length(regexp_replace(coalesce(p_nik,''),'\D','','g')) >= 16
    THEN encode(digest(regexp_replace(p_nik,'\D','','g'),'sha256'),'hex') ELSE NULL END;
  v_phone_hash := CASE WHEN length(regexp_replace(coalesce(p_phone,''),'\D','','g')) >= 10
    THEN encode(digest(regexp_replace(p_phone,'\D','','g'),'sha256'),'hex') ELSE NULL END;

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
    AND length(regexp_replace(coalesce(p_phone,''),'\D','','g')) >= 10
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

REVOKE ALL ON FUNCTION public.submit_kyc(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_kyc(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,BOOLEAN) TO authenticated;
