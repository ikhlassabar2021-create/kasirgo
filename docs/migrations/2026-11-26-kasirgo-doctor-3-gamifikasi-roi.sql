-- ============================================================================
-- KASIRGO 3.0 - Dokter Bisnis 3.0 (Gamifikasi & Rapor ROI)
-- Tanggal: 2026-11-26
--
-- Sifat: ADITIF. Tidak mengubah/menghapus kolom atau tabel stabil yang ada.
--
-- Isi:
--   1. Tabel doctor_xp_events -> pencatat XP yang sudah diberikan, supaya
--      aktivitas harian (dosis, resep, laporan bos) TIDAK memberi XP berulang
--      ketika pengguna menandai lalu membatalkan lalu menandai lagi.
--   2. RLS doctor_xp_events (owner baca, superadmin penuh).
--   3. RPC doctor_award_xp_once(outlet, reason, event_key) -> beri XP tepat
--      sekali per event_key; aman dipanggil berulang.
-- Idempotent (aman dijalankan berulang).
-- ============================================================================

-- ============================================================================
-- 1. doctor_xp_events
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.doctor_xp_events (
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  event_key TEXT NOT NULL,
  reason TEXT NOT NULL,
  amount INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (outlet_id, event_key)
);
CREATE INDEX IF NOT EXISTS idx_xp_events_outlet
  ON public.doctor_xp_events (outlet_id, created_at DESC);

-- ============================================================================
-- 2. RLS doctor_xp_events
-- ============================================================================
ALTER TABLE public.doctor_xp_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access doctor_xp_events" ON public.doctor_xp_events;
CREATE POLICY "Superadmin full access doctor_xp_events" ON public.doctor_xp_events
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Owner read own doctor_xp_events" ON public.doctor_xp_events;
CREATE POLICY "Owner read own doctor_xp_events" ON public.doctor_xp_events
  FOR SELECT TO authenticated USING (public.is_outlet_owner(outlet_id));

GRANT SELECT ON public.doctor_xp_events TO authenticated;

-- ============================================================================
-- 3. doctor_award_xp_once(outlet, reason, event_key)
--    Memberi XP hanya bila event_key belum pernah tercatat untuk outlet itu.
--    Mengembalikan {ok, duplicate, gained, xp, level, leveled_up}.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.doctor_award_xp_once(
  p_outlet UUID,
  p_reason TEXT,
  p_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_amount INT;
  v_inserted INT;
  v_award JSONB;
  v_xp INT;
  v_level INT;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  IF NOT public.is_outlet_owner(p_outlet) AND NOT public.is_platform_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_key IS NULL OR length(trim(p_key)) = 0 THEN
    RAISE EXCEPTION 'event_key wajib diisi';
  END IF;

  v_amount := public.doctor_xp_for(p_reason);

  INSERT INTO public.doctor_xp_events (outlet_id, event_key, reason, amount)
  VALUES (p_outlet, trim(p_key), p_reason, v_amount)
  ON CONFLICT (outlet_id, event_key) DO NOTHING;
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  IF v_inserted = 0 THEN
    SELECT xp, level INTO v_xp, v_level
    FROM public.doctor_outlet_profile WHERE outlet_id = p_outlet;
    RETURN jsonb_build_object(
      'ok', TRUE,
      'duplicate', TRUE,
      'gained', 0,
      'xp', COALESCE(v_xp, 0),
      'level', COALESCE(v_level, 1),
      'leveled_up', FALSE
    );
  END IF;

  v_award := public.doctor_award_xp(p_outlet, p_reason);
  RETURN v_award || jsonb_build_object('duplicate', FALSE);
END;
$$;

REVOKE ALL ON FUNCTION public.doctor_award_xp_once(UUID, TEXT, TEXT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.doctor_award_xp_once(UUID, TEXT, TEXT) TO authenticated;
