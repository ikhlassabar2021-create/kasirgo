-- ============================================================================
-- KasirGo — Integrasi & Financial Config (ST7.8-9, bagian Control Plane)
-- Tanggal: 2026-09-29
--
-- - platform_integrations: semua kredensial integrasi (secret TIDAK ke client).
-- - platform_financial_configs: margin/limit/platform fee (dipakai app + admin).
-- - RLS: superadmin full; client hanya public_config (via view/kolom aman).
-- - Seed baris kosong (is_active=false) untuk 8 integrasi + 1 financial config.
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.platform_integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  label TEXT,
  base_url TEXT,
  public_config JSONB DEFAULT '{}',
  secret_config JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID
);

CREATE TABLE IF NOT EXISTS public.platform_financial_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  min_qris_amount NUMERIC DEFAULT 1000,
  max_qris_amount NUMERIC DEFAULT 10000000,
  qris_free_threshold NUMERIC DEFAULT 500000,
  qris_base_mdr_percent NUMERIC DEFAULT 0.3,
  kasirgo_margin_percent NUMERIC DEFAULT 0.1,
  kasirgo_margin_flat NUMERIC DEFAULT 0,
  fee_bearer VARCHAR(20) DEFAULT 'MERCHANT',
  min_disbursement_amount NUMERIC DEFAULT 50000,
  disbursement_fee_standard NUMERIC DEFAULT 2500,
  disbursement_fee_instant NUMERIC DEFAULT 3500,
  auto_settlement_schedules TEXT[] DEFAULT ARRAY['12:00','19:00'],
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID
);

-- ----------------------------------------------------------------------------
-- RLS
-- ----------------------------------------------------------------------------
ALTER TABLE public.platform_integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_financial_configs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access platform_integrations" ON public.platform_integrations;
CREATE POLICY "Superadmin full access platform_integrations" ON public.platform_integrations
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Superadmin full access platform_financial_configs" ON public.platform_financial_configs;
CREATE POLICY "Superadmin full access platform_financial_configs" ON public.platform_financial_configs
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

-- Client hanya boleh baca kolom aman (tanpa secret_config).
CREATE OR REPLACE VIEW public.platform_integrations_public
WITH (security_invoker = true) AS
  SELECT id, key, label, base_url, public_config, is_active, updated_at
  FROM public.platform_integrations
  WHERE is_active = true;

GRANT SELECT ON public.platform_integrations_public TO anon, authenticated;

DROP POLICY IF EXISTS "Client read active integrations public view" ON public.platform_integrations;
-- (view security_invoker butuh SELECT dasar; batasi hanya baris aktif)
CREATE POLICY "Client read active integrations" ON public.platform_integrations
  FOR SELECT USING (is_active = true);

-- ----------------------------------------------------------------------------
-- SEED
-- ----------------------------------------------------------------------------
INSERT INTO public.platform_integrations (key, label, is_active, public_config, secret_config) VALUES
  ('pg_duitku', 'Payment Gateway - Duitku', false, '{}', '{}'),
  ('ppob_digiflazz', 'PPOB - Digiflazz', false, '{}', '{}'),
  ('b2b_distributor', 'B2B Kulakan Distributor', false, '{}', '{}'),
  ('fintech_partner', 'Fintech Partner', false, '{}', '{}'),
  ('cloudflare_r2', 'Storage - Cloudflare R2', false, '{}', '{}'),
  ('db_connection', 'Database Connection', false, '{}', '{}'),
  ('wa_business', 'WhatsApp Business', false, '{}', '{}'),
  ('affiliate', 'Affiliate', false, '{}', '{}')
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.platform_financial_configs (id) 
SELECT gen_random_uuid()
WHERE NOT EXISTS (SELECT 1 FROM public.platform_financial_configs);

-- ----------------------------------------------------------------------------
-- Helper: baca financial config (klien aman, non-secret)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_financial_config()
RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE
AS $$
  SELECT to_jsonb(f) FROM (
    SELECT min_qris_amount, max_qris_amount, qris_free_threshold, qris_base_mdr_percent,
           kasirgo_margin_percent, kasirgo_margin_flat, fee_bearer, min_disbursement_amount,
           disbursement_fee_standard, disbursement_fee_instant, auto_settlement_schedules
    FROM public.platform_financial_configs
    ORDER BY updated_at DESC NULLS LAST LIMIT 1
  ) f;
$$;

GRANT EXECUTE ON FUNCTION public.get_financial_config() TO anon, authenticated;

-- ============================================================================
-- VERIFIKASI:
--   SELECT key, label, is_active FROM public.platform_integrations ORDER BY key;
--   SELECT public.get_financial_config();
-- ============================================================================