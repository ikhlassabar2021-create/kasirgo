-- ============================================================================
-- KASIRGO 3.0 - Dokter Bisnis 3.0 (Delegasi Tugas ke Staf)
-- Tanggal: 2026-11-25
--
-- Sifat: ADITIF. Tidak mengubah/menghapus kolom atau tabel stabil yang ada.
--
-- Isi:
--   1. Tabel doctor_delegations -> tugas dari owner (hasil resep / dosis /
--      briefing / manual) yang ditugaskan ke Admin, Kasir, atau Koki.
--   2. Index + RLS (owner penuh, staf hanya baca tugas miliknya,
--      superadmin penuh).
--   3. RPC delegation_set_status(id, status, catatan) -> staf mengubah status
--      tugasnya sendiri tanpa bisa mengubah isi/judul/penerima.
--   4. RPC delegation_summary(outlet) -> ringkasan jumlah per status (owner).
--   5. doctor_xp_for: tambah alasan 'delegasi_selesai' = 8 XP.
--   6. Merge config platform_configs.business_doctor.delegation.
-- Idempotent (aman dijalankan berulang).
-- ============================================================================

-- ============================================================================
-- 1. doctor_delegations
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.doctor_delegations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT,
  category TEXT NOT NULL DEFAULT 'lainnya',
  source TEXT NOT NULL DEFAULT 'manual',
  source_ref UUID,
  step_index INT,
  assigned_user_id UUID,
  assigned_name TEXT,
  assigned_role TEXT,
  priority TEXT NOT NULL DEFAULT 'normal',
  status TEXT NOT NULL DEFAULT 'pending',
  due_at TIMESTAMPTZ,
  done_at TIMESTAMPTZ,
  done_note TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.doctor_delegations
  DROP CONSTRAINT IF EXISTS doctor_delegations_category_check;
ALTER TABLE public.doctor_delegations
  ADD CONSTRAINT doctor_delegations_category_check
  CHECK (category IN ('operasional','promosi','stok','keuangan','layanan','lainnya'));

ALTER TABLE public.doctor_delegations
  DROP CONSTRAINT IF EXISTS doctor_delegations_source_check;
ALTER TABLE public.doctor_delegations
  ADD CONSTRAINT doctor_delegations_source_check
  CHECK (source IN ('manual','prescription','dose','briefing'));

ALTER TABLE public.doctor_delegations
  DROP CONSTRAINT IF EXISTS doctor_delegations_priority_check;
ALTER TABLE public.doctor_delegations
  ADD CONSTRAINT doctor_delegations_priority_check
  CHECK (priority IN ('rendah','normal','tinggi'));

ALTER TABLE public.doctor_delegations
  DROP CONSTRAINT IF EXISTS doctor_delegations_status_check;
ALTER TABLE public.doctor_delegations
  ADD CONSTRAINT doctor_delegations_status_check
  CHECK (status IN ('pending','dikerjakan','selesai','dilewati'));

CREATE INDEX IF NOT EXISTS idx_delegations_outlet
  ON public.doctor_delegations (outlet_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_delegations_assignee
  ON public.doctor_delegations (assigned_user_id, status, due_at);

-- ============================================================================
-- 2. RLS
-- ============================================================================
ALTER TABLE public.doctor_delegations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access doctor_delegations" ON public.doctor_delegations;
CREATE POLICY "Superadmin full access doctor_delegations" ON public.doctor_delegations
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Owner access own doctor_delegations" ON public.doctor_delegations;
CREATE POLICY "Owner access own doctor_delegations" ON public.doctor_delegations
  FOR ALL TO authenticated
  USING (public.is_outlet_owner(outlet_id))
  WITH CHECK (public.is_outlet_owner(outlet_id));

DROP POLICY IF EXISTS "Staff read own doctor_delegations" ON public.doctor_delegations;
CREATE POLICY "Staff read own doctor_delegations" ON public.doctor_delegations
  FOR SELECT TO authenticated
  USING (assigned_user_id = auth.uid() AND public.is_outlet_member(outlet_id));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.doctor_delegations TO authenticated;

-- ============================================================================
-- 3. delegation_set_status: staf menandai tugasnya sendiri
--    (hanya kolom status / done_at / done_note yang boleh berubah)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.delegation_set_status(
  p_id UUID,
  p_status TEXT,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_row public.doctor_delegations;
  v_xp JSONB := NULL;
  v_amount INT := 0;
  v_xp_total INT := 0;
  v_level INT := 1;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  IF p_status NOT IN ('pending','dikerjakan','selesai','dilewati') THEN
    RAISE EXCEPTION 'status_tidak_valid';
  END IF;

  SELECT * INTO v_row FROM public.doctor_delegations WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'tugas_tidak_ditemukan';
  END IF;

  IF v_row.assigned_user_id IS DISTINCT FROM v_caller
     AND NOT public.is_outlet_owner(v_row.outlet_id)
     AND NOT public.is_platform_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.doctor_delegations
  SET status = p_status,
      done_at = CASE WHEN p_status = 'selesai' THEN NOW() ELSE NULL END,
      done_note = COALESCE(NULLIF(trim(p_note), ''), done_note),
      updated_at = NOW()
  WHERE id = p_id;

  IF p_status = 'selesai' AND v_row.status IS DISTINCT FROM 'selesai' THEN
    -- XP diberikan langsung (bukan lewat doctor_award_xp) karena pelakunya
    -- staf, sedangkan doctor_award_xp hanya boleh dipanggil owner/admin.
    BEGIN
      v_amount := public.doctor_xp_for('delegasi_selesai');
      INSERT INTO public.doctor_outlet_profile (outlet_id, xp, level)
      VALUES (v_row.outlet_id, v_amount, 1)
      ON CONFLICT (outlet_id) DO UPDATE
        SET xp = COALESCE(public.doctor_outlet_profile.xp, 0) + v_amount,
            updated_at = NOW()
      RETURNING xp INTO v_xp_total;

      v_level := (v_xp_total / 100) + 1;
      UPDATE public.doctor_outlet_profile
      SET level = v_level, updated_at = NOW()
      WHERE outlet_id = v_row.outlet_id;

      v_xp := jsonb_build_object(
        'ok', TRUE,
        'gained', v_amount,
        'xp', v_xp_total,
        'level', v_level
      );
    EXCEPTION WHEN OTHERS THEN
      v_xp := NULL;
    END;
  END IF;

  RETURN jsonb_build_object(
    'ok', TRUE,
    'status', p_status,
    'xp', v_xp
  );
END;
$$;

REVOKE ALL ON FUNCTION public.delegation_set_status(UUID, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.delegation_set_status(UUID, TEXT, TEXT) TO authenticated;

-- ============================================================================
-- 4. delegation_summary: ringkasan per status untuk satu outlet
-- ============================================================================
CREATE OR REPLACE FUNCTION public.delegation_summary(p_outlet UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_total INT := 0;
  v_pending INT := 0;
  v_working INT := 0;
  v_done INT := 0;
  v_overdue INT := 0;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  IF NOT public.is_outlet_member(p_outlet) AND NOT public.is_platform_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'pending'),
    COUNT(*) FILTER (WHERE status = 'dikerjakan'),
    COUNT(*) FILTER (WHERE status = 'selesai'),
    COUNT(*) FILTER (
      WHERE status IN ('pending','dikerjakan')
        AND due_at IS NOT NULL AND due_at < NOW()
    )
  INTO v_total, v_pending, v_working, v_done, v_overdue
  FROM public.doctor_delegations
  WHERE outlet_id = p_outlet;

  RETURN jsonb_build_object(
    'total', v_total,
    'pending', v_pending,
    'dikerjakan', v_working,
    'selesai', v_done,
    'terlambat', v_overdue
  );
END;
$$;

REVOKE ALL ON FUNCTION public.delegation_summary(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.delegation_summary(UUID) TO authenticated;

-- ============================================================================
-- 5. XP: tambah alasan delegasi_selesai
-- ============================================================================
CREATE OR REPLACE FUNCTION public.doctor_xp_for(p_reason TEXT)
RETURNS INT
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_reason
    WHEN 'dosis_selesai'    THEN 10
    WHEN 'resep_selesai'    THEN 20
    WHEN 'kamera_klinis'    THEN 15
    WHEN 'lapor_bos'        THEN 5
    WHEN 'briefing_dibaca'  THEN 2
    WHEN 'delegasi_selesai' THEN 8
    ELSE 1
  END;
$$;

-- ============================================================================
-- 6. Config: blok delegation
-- ============================================================================
UPDATE public.platform_configs
SET value = value || '{
    "delegation": { "aktif": true, "maks_aktif": 20, "ingatkan_harian": true }
  }'::jsonb,
  version = version + 1,
  effective_from = NOW()
WHERE key = 'business_doctor';
