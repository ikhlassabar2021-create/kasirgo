-- ============================================================================
-- KASIRGO 3.0 - Dokter Bisnis 3.0 (D2a): Kamera Klinis + Gamifikasi (XP/Level)
-- Tanggal: 2026-11-21
--
-- Sifat: ADITIF. Tidak mengubah/menghapus kolom atau tabel stabil yang ada.
--
-- Isi:
--   1. Tabel doctor_vitals_checks -> riwayat "Cek Fisik" (Kamera Klinis).
--      Foto TETAP LOKAL di HP; yang disimpan ke DB hanya SKOR angka per aspek.
--   2. RLS doctor_vitals_checks (owner + superadmin).
--   3. Fungsi doctor_xp_for(reason) -> tabel XP per aktivitas (server-authoritative).
--   4. RPC doctor_award_xp(outlet, reason) -> tambah XP, hitung level (kelipatan 100).
--   5. RPC doctor_save_vitals(outlet, aspects, notes) -> simpan vitals + skor + XP.
--   6. Merge config platform_configs.business_doctor: gamifikasi + kamera_klinis.
-- Idempotent (aman dijalankan berulang).
-- ============================================================================

-- ============================================================================
-- 1. doctor_vitals_checks: riwayat Cek Fisik (Kamera Klinis)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.doctor_vitals_checks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  check_date DATE NOT NULL DEFAULT CURRENT_DATE,
  aspects JSONB DEFAULT '[]'::jsonb,
  score INT DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_vitals_checks_outlet
  ON public.doctor_vitals_checks (outlet_id, check_date DESC);

-- ============================================================================
-- 2. RLS doctor_vitals_checks
-- ============================================================================
ALTER TABLE public.doctor_vitals_checks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access doctor_vitals_checks" ON public.doctor_vitals_checks;
CREATE POLICY "Superadmin full access doctor_vitals_checks" ON public.doctor_vitals_checks
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Owner access own doctor_vitals_checks" ON public.doctor_vitals_checks;
CREATE POLICY "Owner access own doctor_vitals_checks" ON public.doctor_vitals_checks
  FOR ALL TO authenticated
  USING (public.is_outlet_owner(outlet_id))
  WITH CHECK (public.is_outlet_owner(outlet_id));

GRANT SELECT ON public.doctor_vitals_checks TO authenticated;

-- ============================================================================
-- 3. doctor_xp_for(reason): tabel XP per aktivitas (server-authoritative)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.doctor_xp_for(p_reason TEXT)
RETURNS INT
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_reason
    WHEN 'dosis_selesai'   THEN 10
    WHEN 'resep_selesai'   THEN 20
    WHEN 'kamera_klinis'   THEN 15
    WHEN 'lapor_bos'       THEN 5
    WHEN 'briefing_dibaca' THEN 2
    ELSE 1
  END;
$$;

-- ============================================================================
-- 4. doctor_award_xp(outlet, reason): tambah XP + hitung level (kelipatan 100)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.doctor_award_xp(
  p_outlet UUID,
  p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_amount INT;
  v_step INT := 100;
  v_xp INT;
  v_level INT;
  v_old_level INT;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  IF NOT public.is_outlet_owner(p_outlet) AND NOT public.is_platform_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_amount := public.doctor_xp_for(p_reason);

  INSERT INTO public.doctor_outlet_profile (outlet_id, xp, level)
  VALUES (p_outlet, v_amount, 1)
  ON CONFLICT (outlet_id) DO UPDATE
    SET xp = COALESCE(public.doctor_outlet_profile.xp, 0) + v_amount,
        updated_at = NOW()
  RETURNING xp, level INTO v_xp, v_old_level;

  v_level := (v_xp / v_step) + 1;

  UPDATE public.doctor_outlet_profile
  SET level = v_level, updated_at = NOW()
  WHERE outlet_id = p_outlet;

  RETURN jsonb_build_object(
    'ok', TRUE,
    'gained', v_amount,
    'xp', v_xp,
    'level', v_level,
    'leveled_up', v_level > COALESCE(v_old_level, 1)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.doctor_award_xp(UUID, TEXT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.doctor_award_xp(UUID, TEXT) TO authenticated;

-- ============================================================================
-- 5. doctor_save_vitals(outlet, aspects, notes): simpan Cek Fisik + XP
--    aspects: [{"key":"fisik","label":"Kondisi Fisik","rating":4}, ...]
-- ============================================================================
CREATE OR REPLACE FUNCTION public.doctor_save_vitals(
  p_outlet UUID,
  p_aspects JSONB,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_avg NUMERIC;
  v_score INT;
  v_award JSONB;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  IF NOT public.is_outlet_owner(p_outlet) AND NOT public.is_platform_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COALESCE(AVG((a->>'rating')::numeric), 0)
  INTO v_avg
  FROM jsonb_array_elements(COALESCE(p_aspects, '[]'::jsonb)) a
  WHERE (a->>'rating') IS NOT NULL;

  v_score := ROUND(v_avg / 5 * 100);

  INSERT INTO public.doctor_vitals_checks (outlet_id, aspects, score, notes)
  VALUES (p_outlet, COALESCE(p_aspects, '[]'::jsonb), v_score, p_notes);

  UPDATE public.doctor_outlet_profile
  SET vitals = jsonb_build_object(
        'score', v_score,
        'checked_at', NOW(),
        'aspects', COALESCE(p_aspects, '[]'::jsonb)
      ),
      updated_at = NOW()
  WHERE outlet_id = p_outlet;

  v_award := public.doctor_award_xp(p_outlet, 'kamera_klinis');

  RETURN jsonb_build_object(
    'ok', TRUE,
    'score', v_score,
    'xp', v_award->'xp',
    'level', v_award->'level',
    'leveled_up', v_award->'leveled_up'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.doctor_save_vitals(UUID, JSONB, TEXT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.doctor_save_vitals(UUID, JSONB, TEXT) TO authenticated;

-- ============================================================================
-- 6. Merge config business_doctor: gamifikasi + kamera_klinis
-- ============================================================================
UPDATE public.platform_configs
SET value = value
  || '{
    "gamifikasi": {
      "level_step": 100,
      "xp": {
        "dosis_selesai": 10,
        "resep_selesai": 20,
        "kamera_klinis": 15,
        "lapor_bos": 5,
        "briefing_dibaca": 2
      }
    },
    "kamera_klinis": {
      "aktif": true,
      "aspek": [
        { "key": "fisik",    "label": "Kondisi Fisik Toko" },
        { "key": "tampilan", "label": "Tampilan & Kerapian" },
        { "key": "perilaku", "label": "Perilaku Pelayanan" }
      ]
    }
  }'::jsonb,
  version = version + 1,
  effective_from = NOW()
WHERE key = 'business_doctor';
