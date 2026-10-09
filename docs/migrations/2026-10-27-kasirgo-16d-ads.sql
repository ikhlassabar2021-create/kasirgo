-- ============================================================================
-- KASIRGO 3.0 - PHASE 16D / ST16-4
-- Team Iklan + Hardening + Tes (BAGIAN 13.28.1-5, 13.28.6)
--   - dm_campaigns: kolom geofence radius + jejak approval own-er + alasan pause
--   - Config global: roas_target (ambang pause otomatis)
--   - RPC owner: dm_owner_guardrails (budget limit + global cap + roas target)
--   - RPC owner: dm_channel_status (status koneksi kanal TANPA token)
--   - RPC owner: dm_log_action (tulis audit_logs aksi owner)
--   - HARDENING: platform_configs client SELECT tidak lagi memaparkan baris
--     yang memuat kredensial LLM (business_doctor, digital_marketing_llm).
--     Dibaca HANYA service_role (Edge Function) + superadmin.
-- Idempotent, aman dijalankan ulang.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) dm_campaigns: kolom tambahan (draft -> approval -> active/paused)
-- ---------------------------------------------------------------------------
ALTER TABLE public.dm_campaigns ADD COLUMN IF NOT EXISTS radius_km NUMERIC DEFAULT 5;
ALTER TABLE public.dm_campaigns ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;
ALTER TABLE public.dm_campaigns ADD COLUMN IF NOT EXISTS approved_by UUID;
ALTER TABLE public.dm_campaigns ADD COLUMN IF NOT EXISTS paused_reason TEXT;

-- ---------------------------------------------------------------------------
-- 2) Config global: tambah roas_target (ambang pause otomatis) bila belum ada
-- ---------------------------------------------------------------------------
UPDATE public.platform_configs
   SET value = COALESCE(value, '{}'::jsonb) || jsonb_build_object(
         'roas_target', COALESCE((value->>'roas_target')::numeric, 3)
       )
 WHERE key = 'digital_marketing_llm' AND scope = 'global';

-- ---------------------------------------------------------------------------
-- 3) RPC - Guardrail iklan owner (tanpa rahasia)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dm_owner_guardrails(p_outlet UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_cfg JSONB;
  v_limit NUMERIC := 0;
  v_spend NUMERIC := 0;
BEGIN
  IF NOT (public.is_outlet_owner(p_outlet) OR public.is_platform_admin()) THEN
    RETURN jsonb_build_object('forbidden', true);
  END IF;
  SELECT value INTO v_cfg FROM public.platform_configs
    WHERE key = 'digital_marketing_llm' AND scope = 'global' AND scope_ref = 'all' LIMIT 1;
  SELECT COALESCE(budget_daily_limit, 0) INTO v_limit
    FROM public.dm_settings WHERE outlet_id = p_outlet;
  SELECT COALESCE(SUM(COALESCE(budget_daily, 0)), 0) INTO v_spend
    FROM public.dm_campaigns
    WHERE outlet_id = p_outlet AND status IN ('approved','active');
  RETURN jsonb_build_object(
    'forbidden', false,
    'owner_daily_limit', COALESCE(v_limit, 0),
    'global_daily_cap', COALESCE((v_cfg->>'budget_global_daily')::numeric, 0),
    'roas_target', COALESCE((v_cfg->>'roas_target')::numeric, 3),
    'committed_daily_budget', v_spend
  );
END; $$;

-- ---------------------------------------------------------------------------
-- 4) RPC - Status koneksi kanal (owner; TANPA token)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dm_channel_status(p_outlet UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_out JSONB;
BEGIN
  IF NOT (public.is_outlet_owner(p_outlet) OR public.is_platform_admin()) THEN
    RETURN jsonb_build_object('forbidden', true);
  END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'channel', channel,
           'is_connected', is_connected,
           'account_name', account_name
         ) ORDER BY channel), '[]'::jsonb) INTO v_out
    FROM public.dm_channel_accounts WHERE outlet_id = p_outlet;
  RETURN jsonb_build_object('forbidden', false, 'accounts', v_out);
END; $$;

-- ---------------------------------------------------------------------------
-- 5) RPC - Catat aksi owner ke audit_logs (owner tidak punya akses tabel)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dm_log_action(
  p_outlet UUID, p_action TEXT, p_meta JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_outlet_owner(p_outlet) THEN
    RETURN jsonb_build_object('forbidden', true);
  END IF;
  INSERT INTO public.audit_logs (actor_id, actor_role, action, target, meta)
  VALUES (auth.uid(), 'owner', 'dm.' || COALESCE(p_action, 'action'),
          p_outlet::text, COALESCE(p_meta, '{}'::jsonb));
  RETURN jsonb_build_object('success', true);
END; $$;

GRANT EXECUTE ON FUNCTION public.dm_owner_guardrails(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dm_channel_status(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dm_log_action(UUID, TEXT, JSONB) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6) HARDENING - platform_configs: client hanya boleh baca config NON-rahasia.
--    Kredensial LLM (business_doctor, digital_marketing_llm) hanya
--    service_role/superadmin. Edge Function memakai service key (bypass RLS).
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Client read platform_configs" ON public.platform_configs;
CREATE POLICY "Client read platform_configs" ON public.platform_configs
  FOR SELECT
  USING (key NOT IN ('business_doctor', 'digital_marketing_llm'));

-- ============================================================================
-- VERIFIKASI:
--   SELECT public.dm_owner_guardrails('<outlet>'::uuid);
--   SELECT public.dm_channel_status('<outlet>'::uuid);
--   -- Klien (anon/authenticated) TIDAK boleh baca kunci rahasia:
--   SELECT value FROM public.platform_configs WHERE key='digital_marketing_llm'; -- 0 baris
-- ============================================================================
