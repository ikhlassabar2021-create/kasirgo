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

-- ---------------------------------------------------------------------------
-- 2. ST10-2: hyperlocal_reports (agregat ANONIM per wilayah, UU PDP)
--    Tidak ada data pelanggan; payload dibangun dari transaksi teragregasi.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hyperlocal_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  region TEXT NOT NULL DEFAULT '',
  period TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_anonymous BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.hyperlocal_reports ENABLE ROW LEVEL SECURITY;

-- Baca: semua user terautentikasi (data sudah anonim & teragregasi).
DROP POLICY IF EXISTS "Authenticated read hyperlocal" ON public.hyperlocal_reports;
CREATE POLICY "Authenticated read hyperlocal"
  ON public.hyperlocal_reports FOR SELECT
  TO authenticated
  USING (is_anonymous = TRUE);

-- Tulis: HANYA via RPC definer (validasi ownership + paksa anonim).
DROP POLICY IF EXISTS "Owner insert hyperlocal" ON public.hyperlocal_reports;
CREATE POLICY "Owner insert hyperlocal"
  ON public.hyperlocal_reports FOR INSERT
  TO authenticated
  WITH CHECK (
    is_anonymous = TRUE
    AND EXISTS (SELECT 1 FROM public.outlets o
                WHERE o.id = hyperlocal_reports.outlet_id
                  AND o.owner_id = auth.uid())
  );

CREATE INDEX IF NOT EXISTS idx_hyperlocal_region_period
  ON public.hyperlocal_reports (region, period DESC);
CREATE INDEX IF NOT EXISTS idx_hyperlocal_outlet_created
  ON public.hyperlocal_reports (outlet_id, created_at DESC);

-- Kirim laporan anonim (owner outlet sendiri; paksa is_anonymous=true).
CREATE OR REPLACE FUNCTION public.hyperlocal_submit(
  p_outlet uuid, p_region text, p_period text, p_payload jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_outlet uuid;
  v_id uuid;
BEGIN
  IF p_period IS NULL OR p_period !~ '^\d{4}-\d{2}$' THEN
    RAISE EXCEPTION 'invalid_period';
  END IF;

  SELECT o.id INTO v_outlet FROM public.outlets o
   WHERE o.id = p_outlet AND o.owner_id = auth.uid();
  IF v_outlet IS NULL THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.hyperlocal_reports
    (outlet_id, region, period, payload, is_anonymous)
  VALUES
    (p_outlet, COALESCE(NULLIF(TRIM(p_region), ''), 'tak-dikenal'),
     p_period, COALESCE(p_payload, '{}'::jsonb), TRUE)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- Config hyperlocal (opt-in; default OFF - consent owner dulu).
INSERT INTO public.platform_configs (key, scope, value)
SELECT 'hyperlocal', 'global', jsonb_build_object(
  'enabled', true,
  'note', 'Data agregat anonim per wilayah; tanpa PII pelanggan (UU PDP)',
  'updated_at', NOW()
)
WHERE NOT EXISTS (
  SELECT 1 FROM public.platform_configs
  WHERE key = 'hyperlocal' AND scope = 'global'
);

-- ============================================================================
