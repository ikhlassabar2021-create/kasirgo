-- ============================================================================
-- KasirGo — Control Plane: Payment Gateway, PPOB, B2B Kulakan, Modal Usaha
-- Tanggal: 2026-10-04  (melengkapi 2026-10-03-kasirgo-13-admin.sql)
--
-- Perubahan:
--  - platform_integrations: baris kanonik 'payment_gateway' & 'ppob'
--    (secret disimpan di secret_config, TIDAK pernah dibaca klien).
--  - platform_configs 'ppob': tambah field callback_url / ip_whitelist /
--    product_codes (non-secret) untuk diatur superadmin.
--  - platform_configs 'ads': pastikan 'creatives' ada (banner lokal base64).
--  - platform_configs 'b2b_restock' & 'fintech_partner': siapkan field embed
--    (html_code / script_code / target_url). Nilai lama TIDAK ditimpa.
--
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Integrasi kanonik Payment Gateway & PPOB
--    (menggantikan seed lama 'pg_duitku' / 'ppob_digiflazz' untuk UI baru)
-- ----------------------------------------------------------------------------
INSERT INTO public.platform_integrations (key, label, is_active, public_config, secret_config) VALUES
  ('payment_gateway', 'Payment Gateway', false, '{}', '{}'),
  ('ppob',            'PPOB',            false, '{}', '{}')
ON CONFLICT (key) DO NOTHING;

-- PENTING: jangan buat policy SELECT untuk client di platform_integrations.
-- Phase 12 (2026-10-02-kasirgo-12-security.sql) sengaja menghapus policy ini
-- karena membocorkan secret_config ke klien. Akses klien hanya lewat view
-- platform_integrations_public (kolom aman, tanpa secret_config).
DROP POLICY IF EXISTS "Client read active integrations" ON public.platform_integrations;
DROP POLICY IF EXISTS "Client read active integrations public view" ON public.platform_integrations;

-- ----------------------------------------------------------------------------
-- 2. platform_configs 'ppob': tambah field non-secret
-- ----------------------------------------------------------------------------
UPDATE public.platform_configs
SET value = jsonb_build_object(
      'provider',       COALESCE(value->>'provider', 'demo'),
      'endpoint',       COALESCE(value->>'endpoint', ''),
      'margin_percent', COALESCE((value->>'margin_percent')::numeric, 5),
      'enabled',        COALESCE((value->>'enabled')::boolean, true),
      'callback_url',   COALESCE(value->>'callback_url', ''),
      'ip_whitelist',   COALESCE(value->'ip_whitelist', '[]'::jsonb),
      'product_codes',  COALESCE(value->'product_codes', '[]'::jsonb)
    ),
    updated_at = NOW()
WHERE key = 'ppob' AND scope = 'global';

-- ----------------------------------------------------------------------------
-- 3. platform_configs 'ads': pastikan 'creatives' ada, buang key lama
-- ----------------------------------------------------------------------------
UPDATE public.platform_configs
SET value = (value
      - 'provider' - 'adsterra_key' - 'sponsor_local')
      || jsonb_build_object('creatives', COALESCE(value->'creatives', '[]'::jsonb)),
    updated_at = NOW()
WHERE key = 'ads' AND scope = 'global';

-- ----------------------------------------------------------------------------
-- 4. platform_configs 'b2b_restock' & 'fintech_partner': field embed opsional
-- ----------------------------------------------------------------------------
UPDATE public.platform_configs
SET value = value
      || jsonb_build_object(
           'html_code',  COALESCE(value->'html_code', '""'::jsonb),
           'script_code', COALESCE(value->'script_code', '""'::jsonb),
           'target_url', COALESCE(value->'target_url', '""'::jsonb)
         ),
    updated_at = NOW()
WHERE key IN ('b2b_restock', 'fintech_partner') AND scope = 'global';

-- ============================================================================
-- VERIFIKASI:
--   SELECT key, label, is_active FROM public.platform_integrations
--     WHERE key IN ('payment_gateway','ppob');
--   SELECT key, value FROM public.platform_configs
--     WHERE key IN ('ads','ppob','b2b_restock','fintech_partner') AND scope='global';
-- ============================================================================