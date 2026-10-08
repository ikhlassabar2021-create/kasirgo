-- ============================================================================
-- KASIRGO 3.0 - PHASE 15D / ST15-4
-- Perilaku Addendum + Hardening (BAGIAN 13.26 15D + addendum L/M/N/O):
--   L. Laporan Mingguan Proaktif  -> doctor_memory kind 'weekly_report'
--   M. Guardrail Aksi Otomatis    -> tabel doctor_pending_actions (Setujui/Tolak)
--   N. Benchmark Hyperlocal       -> pakai hyperlocal_reports (anonim) + tandai perlu verifikasi
--   O. Kartu Identitas Bisnis     -> kolom di doctor_outlet_profile (health_score, penyakit aktif)
-- Idempotent.
-- ============================================================================

-- 1) doctor_memory: tambah kind 'weekly_report' (L) & 'market' sudah ada.
ALTER TABLE public.doctor_memory DROP CONSTRAINT IF EXISTS doctor_memory_kind_check;
ALTER TABLE public.doctor_memory ADD CONSTRAINT doctor_memory_kind_check
  CHECK (kind = ANY (ARRAY[
    'diagnosis','prescription','result','lesson','fact',
    'reprimand','market','scaling','weekly_report'
  ]));

-- 2) doctor_outlet_profile: identitas bisnis (O).
ALTER TABLE public.doctor_outlet_profile
  ADD COLUMN IF NOT EXISTS health_score INT,
  ADD COLUMN IF NOT EXISTS active_disease TEXT,
  ADD COLUMN IF NOT EXISTS active_disease_since TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_weekly_report_at TIMESTAMPTZ;

-- 3) doctor_pending_actions (M): usulan aksi yang menunggu persetujuan owner.
CREATE TABLE IF NOT EXISTS public.doctor_pending_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  conversation_id UUID REFERENCES public.doctor_conversations(id) ON DELETE SET NULL,
  action_type TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  body TEXT DEFAULT '',
  payload JSONB DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected')),
  decision_note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  decided_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_pending_actions_outlet
  ON public.doctor_pending_actions (outlet_id, status, created_at DESC);

ALTER TABLE public.doctor_pending_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access doctor_pending_actions" ON public.doctor_pending_actions;
CREATE POLICY "Superadmin full access doctor_pending_actions" ON public.doctor_pending_actions
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Owner access own doctor_pending_actions" ON public.doctor_pending_actions;
CREATE POLICY "Owner access own doctor_pending_actions" ON public.doctor_pending_actions
  FOR ALL TO authenticated
  USING (public.is_outlet_owner(outlet_id))
  WITH CHECK (public.is_outlet_owner(outlet_id));
