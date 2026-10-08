-- ============================================================================
-- KASIRGO 3.0 - PHASE 15B / ST15-2
-- Bos Virtual Analitik (BAGIAN 13.25.1/13.25.2/13.25.3):
--   outlet_targets        : target omzet harian/bulanan (13.25.1)
--   doctor_scaling_plans  : roadmap ekspansi 30/60/90 (13.25.2)
--   web_cache             : cache fetch internet (13.19/13.25.3)
-- RLS: owner penuh atas outlet sendiri; superadmin penuh. Idempotent.
-- ============================================================================

-- 1. outlet_targets (13.25.1)
CREATE TABLE IF NOT EXISTS public.outlet_targets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  period TEXT NOT NULL DEFAULT 'day' CHECK (period IN ('day','month')),
  target_amount NUMERIC NOT NULL DEFAULT 0,
  set_by TEXT CHECK (set_by IN ('ai','owner')),
  source TEXT,
  note TEXT,
  effective_from DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (outlet_id, period, effective_from)
);
CREATE INDEX IF NOT EXISTS idx_outlet_targets_outlet
  ON public.outlet_targets (outlet_id, period, effective_from DESC);

-- 2. doctor_scaling_plans (13.25.2)
CREATE TABLE IF NOT EXISTS public.doctor_scaling_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  conversation_id UUID REFERENCES public.doctor_conversations(id) ON DELETE SET NULL,
  goal TEXT,
  readiness JSONB DEFAULT '[]'::jsonb,
  roadmap JSONB DEFAULT '[]'::jsonb,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','on_track','achieved','cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_scaling_plans_outlet
  ON public.doctor_scaling_plans (outlet_id, status);

-- 3. web_cache (13.19) untuk Intelijen Pasar + fetch_url.
CREATE TABLE IF NOT EXISTS public.web_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  url TEXT NOT NULL,
  content TEXT,
  source_label TEXT,
  fetched_at TIMESTAMPTZ DEFAULT NOW(),
  ttl_seconds INT DEFAULT 3600,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (url)
);
CREATE INDEX IF NOT EXISTS idx_web_cache_fetched ON public.web_cache (fetched_at DESC);

-- ============================================================================
-- RLS
-- ============================================================================
ALTER TABLE public.outlet_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctor_scaling_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.web_cache ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access outlet_targets" ON public.outlet_targets;
CREATE POLICY "Superadmin full access outlet_targets" ON public.outlet_targets
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Owner access own outlet_targets" ON public.outlet_targets;
CREATE POLICY "Owner access own outlet_targets" ON public.outlet_targets
  FOR ALL TO authenticated
  USING (public.is_outlet_owner(outlet_id))
  WITH CHECK (public.is_outlet_owner(outlet_id));

DROP POLICY IF EXISTS "Superadmin full access doctor_scaling_plans" ON public.doctor_scaling_plans;
CREATE POLICY "Superadmin full access doctor_scaling_plans" ON public.doctor_scaling_plans
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Owner access own doctor_scaling_plans" ON public.doctor_scaling_plans;
CREATE POLICY "Owner access own doctor_scaling_plans" ON public.doctor_scaling_plans
  FOR ALL TO authenticated
  USING (public.is_outlet_owner(outlet_id))
  WITH CHECK (public.is_outlet_owner(outlet_id));

-- web_cache: tulis hanya service_role (EF); baca service_role + superadmin.
DROP POLICY IF EXISTS "Service role write web_cache" ON public.web_cache;
CREATE POLICY "Service role write web_cache" ON public.web_cache
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Superadmin read web_cache" ON public.web_cache;
CREATE POLICY "Superadmin read web_cache" ON public.web_cache
  FOR SELECT USING (public.is_platform_admin());
