-- ============================================================================
-- KASIRGO PHASE 10 MIGRATION (ST10-1 fintech_leads, ST10-2 hyperlocal_reports,
-- ST10-3 insurance_leads/insurance_policies + configs)
-- Idempotent: aman dijalankan ulang.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. ST10-1: fintech_leads (pengajuan modal usaha ke partner)
--    payload = agregat arus kas ANONIM (tanpa identitas pelanggan).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.fintech_leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  partner TEXT NOT NULL DEFAULT '',
  amount_requested NUMERIC(14,2) NOT NULL DEFAULT 0,
  tenor_months INT,
  status TEXT NOT NULL DEFAULT 'lead'
    CHECK (status IN ('lead','apply','approved','rejected','cancelled')),
  ref TEXT,
  eligibility_score NUMERIC(5,2),
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.fintech_leads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner full fintech leads" ON public.fintech_leads;
CREATE POLICY "Owner full fintech leads"
  ON public.fintech_leads FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.outlets o
                 WHERE o.id = fintech_leads.outlet_id AND o.owner_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.outlets o
                 WHERE o.id = fintech_leads.outlet_id AND o.owner_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read fintech leads" ON public.fintech_leads;
CREATE POLICY "Staff read fintech leads"
  ON public.fintech_leads FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles ur
                 WHERE ur.user_id = auth.uid()
                   AND ur.outlet_id = fintech_leads.outlet_id));

DROP POLICY IF EXISTS "Staff insert fintech leads" ON public.fintech_leads;
CREATE POLICY "Staff insert fintech leads"
  ON public.fintech_leads FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_roles ur
                 WHERE ur.user_id = auth.uid()
                   AND ur.outlet_id = fintech_leads.outlet_id));

CREATE INDEX IF NOT EXISTS idx_fintech_outlet_created
  ON public.fintech_leads (outlet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fintech_status
  ON public.fintech_leads (status);

-- Config partner pembiayaan (superadmin atur link/WA tanpa ubah koding).
INSERT INTO public.platform_configs (key, scope, value)
SELECT 'fintech_partner', 'global', jsonb_build_object(
  'enabled', true,
  'partner_name', 'Mitra Pembiayaan KasirGo',
  'apply_url', '',
  'wa_number', '',
  'updated_at', NOW()
)
WHERE NOT EXISTS (
  SELECT 1 FROM public.platform_configs
  WHERE key = 'fintech_partner' AND scope = 'global'
);

-- ============================================================================
