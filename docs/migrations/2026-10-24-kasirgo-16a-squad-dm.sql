-- ============================================================================
-- KASIRGO 3.0 - PHASE 16A / ST16-1
-- Squad Digital Marketing AI - Fondasi (BAGIAN 13.28)
--   - dm_assets, dm_posts, dm_campaigns, dm_settings (RLS per outlet)
--   - dm_channel_accounts (token_enc; HANYA service_role)
--   - outlet_dm_configs (override LLM per outlet; api_key_enc HANYA service_role)
--   - dm_usage (kuota/rate limit harian)
--   - RPC admin (list/set/delete) untuk Control Plane + dm_usage_today
--   - Seed platform_configs group 'digital_marketing_llm'
-- Idempotent.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) ASET KREATIF
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.dm_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  kind TEXT NOT NULL DEFAULT 'copy' CHECK (kind IN ('copy','image','video')),
  title TEXT NOT NULL DEFAULT '',
  file_path TEXT,
  content TEXT,
  caption TEXT,
  hashtags TEXT,
  source TEXT NOT NULL DEFAULT 'brief' CHECK (source IN ('brief','product','template','doctor')),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','approved','published')),
  version INT NOT NULL DEFAULT 1,
  meta JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_dm_assets_outlet ON public.dm_assets (outlet_id, created_at DESC);

-- 2) JADWAL POSTING
CREATE TABLE IF NOT EXISTS public.dm_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  asset_id UUID REFERENCES public.dm_assets(id) ON DELETE SET NULL,
  channel TEXT NOT NULL CHECK (channel IN ('fb','fb_group','ig','tiktok','shopee','wa_status','wa_broadcast')),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','queued','posted','failed')),
  caption TEXT,
  scheduled_at TIMESTAMPTZ,
  posted_at TIMESTAMPTZ,
  post_url TEXT,
  error TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_dm_posts_outlet ON public.dm_posts (outlet_id, status, scheduled_at);

-- 3) KAMPANYE IKLAN
CREATE TABLE IF NOT EXISTS public.dm_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  asset_id UUID REFERENCES public.dm_assets(id) ON DELETE SET NULL,
  channel TEXT NOT NULL CHECK (channel IN ('meta','google','tiktok','shopee')),
  objective TEXT,
  budget_daily NUMERIC DEFAULT 0,
  start_date DATE,
  end_date DATE,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','approved','active','paused','done')),
  external_id TEXT,
  metrics JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_dm_campaigns_outlet ON public.dm_campaigns (outlet_id, status);

-- 4) PENGATURAN PER OUTLET (non-rahasia)
CREATE TABLE IF NOT EXISTS public.dm_settings (
  outlet_id UUID PRIMARY KEY REFERENCES public.outlets(id) ON DELETE CASCADE,
  mode_design TEXT NOT NULL DEFAULT 'manual' CHECK (mode_design IN ('manual','auto')),
  mode_promo TEXT NOT NULL DEFAULT 'manual' CHECK (mode_promo IN ('manual','auto')),
  mode_ads TEXT NOT NULL DEFAULT 'manual' CHECK (mode_ads IN ('manual','auto')),
  budget_daily_limit NUMERIC DEFAULT 0,
  quiet_hours JSONB DEFAULT '{"start":"22:00","end":"06:00"}'::jsonb,
  watermark TEXT,
  last_sync TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5) AKUN KANAL (RAHASIA: token_enc HANYA service_role; tanpa policy = tak terbaca klien)
CREATE TABLE IF NOT EXISTS public.dm_channel_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  channel TEXT NOT NULL CHECK (channel IN ('fb','fb_group','ig','tiktok','shopee','meta_ads','google_ads','tiktok_ads','shopee_ads')),
  account_name TEXT,
  external_id TEXT,
  token_enc TEXT,
  is_connected BOOLEAN DEFAULT FALSE,
  last_sync TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (outlet_id, channel)
);
ALTER TABLE public.dm_channel_accounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Superadmin full access dm_channel_accounts" ON public.dm_channel_accounts;
CREATE POLICY "Superadmin full access dm_channel_accounts" ON public.dm_channel_accounts
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

-- 6) OVERRIDE LLM PER OUTLET (api_key_enc HANYA service_role)
CREATE TABLE IF NOT EXISTS public.outlet_dm_configs (
  outlet_id UUID PRIMARY KEY REFERENCES public.outlets(id) ON DELETE CASCADE,
  provider TEXT,
  base_url TEXT,
  api_key_enc TEXT,
  model TEXT,
  temperature NUMERIC DEFAULT 0.7,
  max_tokens INT DEFAULT 2000,
  is_active BOOLEAN DEFAULT TRUE,
  unlimited_tokens BOOLEAN DEFAULT FALSE,
  token_quota INT DEFAULT 0,
  last_tested_at TIMESTAMPTZ,
  last_test_result TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.outlet_dm_configs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Superadmin full access outlet_dm_configs" ON public.outlet_dm_configs;
CREATE POLICY "Superadmin full access outlet_dm_configs" ON public.outlet_dm_configs
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

-- 7) PEMAKAIAN HARIAN (kuota aset + token)
CREATE TABLE IF NOT EXISTS public.dm_usage (
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  day DATE NOT NULL DEFAULT CURRENT_DATE,
  assets INT NOT NULL DEFAULT 0,
  tokens INT NOT NULL DEFAULT 0,
  requests INT NOT NULL DEFAULT 0,
  PRIMARY KEY (outlet_id, day)
);
ALTER TABLE public.dm_usage ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Superadmin full access dm_usage" ON public.dm_usage;
CREATE POLICY "Superadmin full access dm_usage" ON public.dm_usage
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

-- ---------------------------------------------------------------------------
-- 8) RLS tabel aset/jadwal/kampanye/pengaturan (owner + superadmin)
-- ---------------------------------------------------------------------------
ALTER TABLE public.dm_assets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Superadmin full access dm_assets" ON public.dm_assets;
CREATE POLICY "Superadmin full access dm_assets" ON public.dm_assets
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());
DROP POLICY IF EXISTS "Owner access own dm_assets" ON public.dm_assets;
CREATE POLICY "Owner access own dm_assets" ON public.dm_assets
  FOR ALL TO authenticated USING (public.is_outlet_owner(outlet_id)) WITH CHECK (public.is_outlet_owner(outlet_id));

ALTER TABLE public.dm_posts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Superadmin full access dm_posts" ON public.dm_posts;
CREATE POLICY "Superadmin full access dm_posts" ON public.dm_posts
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());
DROP POLICY IF EXISTS "Owner access own dm_posts" ON public.dm_posts;
CREATE POLICY "Owner access own dm_posts" ON public.dm_posts
  FOR ALL TO authenticated USING (public.is_outlet_owner(outlet_id)) WITH CHECK (public.is_outlet_owner(outlet_id));

ALTER TABLE public.dm_campaigns ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Superadmin full access dm_campaigns" ON public.dm_campaigns;
CREATE POLICY "Superadmin full access dm_campaigns" ON public.dm_campaigns
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());
DROP POLICY IF EXISTS "Owner access own dm_campaigns" ON public.dm_campaigns;
CREATE POLICY "Owner access own dm_campaigns" ON public.dm_campaigns
  FOR ALL TO authenticated USING (public.is_outlet_owner(outlet_id)) WITH CHECK (public.is_outlet_owner(outlet_id));

ALTER TABLE public.dm_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Superadmin full access dm_settings" ON public.dm_settings;
CREATE POLICY "Superadmin full access dm_settings" ON public.dm_settings
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());
DROP POLICY IF EXISTS "Owner access own dm_settings" ON public.dm_settings;
CREATE POLICY "Owner access own dm_settings" ON public.dm_settings
  FOR ALL TO authenticated USING (public.is_outlet_owner(outlet_id)) WITH CHECK (public.is_outlet_owner(outlet_id));

-- ---------------------------------------------------------------------------
-- 9) RPC ADMIN - Override LLM per outlet (ter-mask, tanpa api_key)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_outlet_dm_configs()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_out JSONB;
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  SELECT COALESCE(jsonb_agg(x ORDER BY x->>'outlet_name'), '[]'::jsonb) INTO v_out FROM (
    SELECT jsonb_build_object(
      'outlet_id', o.id,
      'outlet_name', o.name,
      'has_config', (c.outlet_id IS NOT NULL),
      'is_active', COALESCE(c.is_active, false),
      'provider', c.provider,
      'base_url', c.base_url,
      'model', c.model,
      'temperature', c.temperature,
      'max_tokens', c.max_tokens,
      'unlimited_tokens', COALESCE(c.unlimited_tokens, false),
      'token_quota', c.token_quota,
      'has_api_key', (c.api_key_enc IS NOT NULL AND length(c.api_key_enc) > 0),
      'last_tested_at', c.last_tested_at,
      'last_test_result', c.last_test_result
    ) AS x
    FROM public.outlets o
    LEFT JOIN public.outlet_dm_configs c ON c.outlet_id = o.id
  ) t;
  RETURN v_out;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_set_outlet_dm_config(p_outlet UUID, p_config JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  INSERT INTO public.outlet_dm_configs AS c (
    outlet_id, provider, base_url, api_key_enc, model, temperature, max_tokens,
    is_active, unlimited_tokens, token_quota, updated_at
  ) VALUES (
    p_outlet,
    NULLIF(p_config->>'provider',''),
    NULLIF(p_config->>'base_url',''),
    NULLIF(p_config->>'api_key',''),
    NULLIF(p_config->>'model',''),
    COALESCE((p_config->>'temperature')::numeric, 0.7),
    COALESCE((p_config->>'max_tokens')::int, 2000),
    COALESCE((p_config->>'is_active')::boolean, true),
    COALESCE((p_config->>'unlimited_tokens')::boolean, false),
    COALESCE((p_config->>'token_quota')::int, 0),
    NOW()
  )
  ON CONFLICT (outlet_id) DO UPDATE SET
    provider = COALESCE(NULLIF(p_config->>'provider',''), c.provider),
    base_url = COALESCE(NULLIF(p_config->>'base_url',''), c.base_url),
    api_key_enc = CASE WHEN NULLIF(p_config->>'api_key','') IS NULL THEN c.api_key_enc ELSE p_config->>'api_key' END,
    model = COALESCE(NULLIF(p_config->>'model',''), c.model),
    temperature = COALESCE((p_config->>'temperature')::numeric, c.temperature),
    max_tokens = COALESCE((p_config->>'max_tokens')::int, c.max_tokens),
    is_active = COALESCE((p_config->>'is_active')::boolean, c.is_active),
    unlimited_tokens = COALESCE((p_config->>'unlimited_tokens')::boolean, c.unlimited_tokens),
    token_quota = COALESCE((p_config->>'token_quota')::int, c.token_quota),
    updated_at = NOW();
  PERFORM public.log_admin_action('outlet_dm_config.set', p_outlet::text, p_config - 'api_key');
  RETURN jsonb_build_object('success', true);
END; $$;

CREATE OR REPLACE FUNCTION public.admin_delete_outlet_dm_config(p_outlet UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  DELETE FROM public.outlet_dm_configs WHERE outlet_id = p_outlet;
  PERFORM public.log_admin_action('outlet_dm_config.delete', p_outlet::text, '{}'::jsonb);
  RETURN jsonb_build_object('success', true);
END; $$;

-- ---------------------------------------------------------------------------
-- 10) RPC ADMIN - Akun kanal (ter-mask, tanpa token)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_dm_channel_accounts()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_out JSONB;
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  SELECT COALESCE(jsonb_agg(x ORDER BY x->>'outlet_name', x->>'channel'), '[]'::jsonb) INTO v_out FROM (
    SELECT jsonb_build_object(
      'outlet_id', a.outlet_id,
      'outlet_name', o.name,
      'channel', a.channel,
      'account_name', a.account_name,
      'external_id', a.external_id,
      'is_connected', a.is_connected,
      'has_token', (a.token_enc IS NOT NULL AND length(a.token_enc) > 0),
      'last_sync', a.last_sync
    ) AS x
    FROM public.dm_channel_accounts a
    JOIN public.outlets o ON o.id = a.outlet_id
  ) t;
  RETURN v_out;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_set_dm_channel_account(
  p_outlet UUID, p_channel TEXT, p_account_name TEXT DEFAULT NULL,
  p_external_id TEXT DEFAULT NULL, p_token TEXT DEFAULT NULL, p_connected BOOLEAN DEFAULT TRUE
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  INSERT INTO public.dm_channel_accounts AS a (outlet_id, channel, account_name, external_id, token_enc, is_connected)
  VALUES (p_outlet, p_channel, p_account_name, p_external_id, NULLIF(p_token,''), p_connected)
  ON CONFLICT (outlet_id, channel) DO UPDATE SET
    account_name = COALESCE(EXCLUDED.account_name, a.account_name),
    external_id = COALESCE(EXCLUDED.external_id, a.external_id),
    token_enc = CASE WHEN EXCLUDED.token_enc IS NULL THEN a.token_enc ELSE EXCLUDED.token_enc END,
    is_connected = EXCLUDED.is_connected;
  PERFORM public.log_admin_action('dm_channel_account.set', p_outlet::text, jsonb_build_object('channel', p_channel));
  RETURN jsonb_build_object('success', true);
END; $$;

CREATE OR REPLACE FUNCTION public.admin_delete_dm_channel_account(p_outlet UUID, p_channel TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  DELETE FROM public.dm_channel_accounts WHERE outlet_id = p_outlet AND channel = p_channel;
  PERFORM public.log_admin_action('dm_channel_account.delete', p_outlet::text, jsonb_build_object('channel', p_channel));
  RETURN jsonb_build_object('success', true);
END; $$;

-- ---------------------------------------------------------------------------
-- 11) RPC - Pemakaian harian (service_role; dipakai EF dm_creative)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dm_usage_today(p_outlet UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v RECORD;
BEGIN
  SELECT * INTO v FROM public.dm_usage WHERE outlet_id = p_outlet AND day = CURRENT_DATE;
  RETURN jsonb_build_object(
    'assets', COALESCE(v.assets, 0),
    'tokens', COALESCE(v.tokens, 0),
    'requests', COALESCE(v.requests, 0)
  );
END; $$;

REVOKE ALL ON FUNCTION public.dm_usage_today(UUID) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 12) Seed config global
-- ---------------------------------------------------------------------------
INSERT INTO public.platform_configs (key, scope, scope_ref, value, version)
VALUES (
  'digital_marketing_llm', 'global', 'all',
  '{"aktif":true,"mode":"central","provider_default":{"provider":"","base_url":"","api_key":"","model":"","temperature":0.7,"max_tokens":2000},"rate_limit":{"assets_per_day":20,"tokens_per_day":150000},"asset_quota_per_month":60,"budget_global_daily":0,"blocked_words":["politik","presiden","pemilu","agama","sara","judi","narkoba","pinjol ilegal"],"watermark_default":""}'::jsonb,
  1
)
ON CONFLICT (key, scope, scope_ref) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 13) Grant EXECUTE RPC admin
-- ---------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.admin_list_outlet_dm_configs() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_outlet_dm_config(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_outlet_dm_config(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_dm_channel_accounts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_dm_channel_account(UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_dm_channel_account(UUID, TEXT) TO authenticated;

-- ============================================================================
-- VERIFIKASI:
--   SELECT public.admin_list_outlet_dm_configs();
--   SELECT public.admin_list_dm_channel_accounts();
--   SELECT value FROM public.platform_configs WHERE key='digital_marketing_llm';
-- ============================================================================
