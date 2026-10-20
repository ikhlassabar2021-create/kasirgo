-- ============================================================================
-- KasirGo 3.0 - Dokter Bisnis: Leaderboard & Badge Staf
-- ============================================================================
-- Tujuan: memberi apresiasi terukur untuk staf (Admin/Kasir/Koki) yang
-- menyelesaikan tugas delegasi dari Dokter Bisnis. Owner melihat peringkat,
-- staf melihat posisi & badge miliknya sendiri.
--
-- Isi:
--   1. Index bantu agregasi per outlet + staf.
--   2. RPC delegation_leaderboard(outlet, hari) -> peringkat + badge.
--      Hanya boleh dibaca anggota outlet (owner/admin/kasir/koki) atau
--      superadmin. Tidak mengembalikan data sensitif (hanya nama + angka).
--   3. Merge config platform_configs.business_doctor.leaderboard.
--
-- Catatan: XP staf dihitung dari jumlah tugas selesai x doctor_xp_for
-- ('delegasi_selesai'). XP outlet (doctor_outlet_profile.xp) tetap
-- diakumulasi oleh delegation_set_status seperti sebelumnya.
-- Idempotent (aman dijalankan berulang).
-- ============================================================================

-- ============================================================================
-- 1. Index bantu
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_doctor_delegations_outlet_assigned
  ON public.doctor_delegations (outlet_id, assigned_user_id, status);

CREATE INDEX IF NOT EXISTS idx_doctor_delegations_outlet_created
  ON public.doctor_delegations (outlet_id, created_at DESC);

-- ============================================================================
-- 2. delegation_leaderboard: peringkat staf + badge
--    p_days = jendela waktu (1..365 hari, default 30)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.delegation_leaderboard(
  p_outlet UUID,
  p_days INT DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_days INT;
  v_since TIMESTAMPTZ;
  v_xp_per_task INT;
  v_items JSONB := '[]'::jsonb;
  v_selesai INT := 0;
  v_aktif INT := 0;
  v_terlambat INT := 0;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  IF NOT public.is_outlet_member(p_outlet)
     AND NOT public.is_platform_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_days := GREATEST(LEAST(COALESCE(p_days, 30), 365), 1);
  v_since := NOW() - make_interval(days => v_days);
  v_xp_per_task := public.doctor_xp_for('delegasi_selesai');

  WITH base AS (
    SELECT
      d.assigned_user_id AS user_id,
      COALESCE(
        MAX(NULLIF(trim(d.assigned_name), '')),
        MAX(ur.display_name),
        'Staf'
      ) AS name,
      COALESCE(
        MAX(NULLIF(trim(d.assigned_role), '')),
        MAX(ur.role),
        ''
      ) AS role,
      COUNT(*) FILTER (WHERE d.status = 'selesai') AS done,
      COUNT(*) FILTER (WHERE d.status IN ('pending', 'dikerjakan')) AS open,
      COUNT(*) FILTER (
        WHERE d.status = 'selesai'
          AND d.due_at IS NOT NULL
          AND d.done_at IS NOT NULL
          AND d.done_at > d.due_at
      ) AS late,
      COUNT(*) FILTER (
        WHERE d.status = 'selesai'
          AND d.due_at IS NOT NULL
          AND d.done_at IS NOT NULL
          AND d.done_at <= d.due_at
      ) AS ontime
    FROM public.doctor_delegations d
    LEFT JOIN public.user_roles ur
      ON ur.user_id = d.assigned_user_id
     AND ur.outlet_id = d.outlet_id
    WHERE d.outlet_id = p_outlet
      AND d.assigned_user_id IS NOT NULL
      AND d.created_at >= v_since
    GROUP BY d.assigned_user_id
  ),
  scored AS (
    SELECT
      b.*,
      (b.done * v_xp_per_task) AS xp,
      CASE
        WHEN (b.done + b.open) > 0
          THEN ROUND(b.done::numeric * 100 / (b.done + b.open))
        ELSE 0
      END AS completion,
      ROW_NUMBER() OVER (
        ORDER BY b.done DESC, b.ontime DESC, b.late ASC, b.name ASC
      ) AS rank
    FROM base b
  )
  SELECT
    COALESCE(jsonb_agg(
      jsonb_build_object(
        'user_id', s.user_id,
        'name', s.name,
        'role', s.role,
        'selesai', s.done,
        'aktif', s.open,
        'terlambat', s.late,
        'tepat_waktu', s.ontime,
        'penyelesaian', s.completion,
        'xp', s.xp,
        'rank', s.rank,
        'badges', to_jsonb(ARRAY_REMOVE(ARRAY[
          CASE WHEN s.rank = 1 AND s.done >= 3 THEN 'juara' END,
          CASE WHEN s.done >= 3 AND s.late = 0 THEN 'selalu_tepat' END,
          CASE WHEN s.done >= 5 THEN 'konsisten' END,
          CASE WHEN s.late >= 2 THEN 'perlu_bantuan' END,
          CASE WHEN s.done >= 1 AND s.rank > 1 AND s.late = 0
               THEN 'pekerja_keras' END
        ]::TEXT[], NULL))
      )
      ORDER BY s.rank
    ), '[]'::jsonb)
  INTO v_items
  FROM scored s;

  SELECT
    COALESCE(SUM((i ->> 'selesai')::INT), 0),
    COALESCE(SUM((i ->> 'aktif')::INT), 0),
    COALESCE(SUM((i ->> 'terlambat')::INT), 0)
  INTO v_selesai, v_aktif, v_terlambat
  FROM jsonb_array_elements(v_items) AS i;

  RETURN jsonb_build_object(
    'ok', TRUE,
    'outlet_id', p_outlet,
    'days', v_days,
    'xp_per_tugas', v_xp_per_task,
    'items', v_items,
    'totals', jsonb_build_object(
      'selesai', v_selesai,
      'aktif', v_aktif,
      'terlambat', v_terlambat
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.delegation_leaderboard(UUID, INT) FROM anon;
GRANT EXECUTE ON FUNCTION public.delegation_leaderboard(UUID, INT)
  TO authenticated;

-- ============================================================================
-- 3. Config: blok leaderboard
-- ============================================================================
UPDATE public.platform_configs
SET value = value || '{
    "leaderboard": { "aktif": true, "periode_hari": 30 }
  }'::jsonb,
  version = version + 1,
  effective_from = NOW()
WHERE key = 'business_doctor';
