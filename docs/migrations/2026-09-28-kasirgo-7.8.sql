-- ============================================================================
-- Migration KasirGo 7.8 (Tahap 7.8-DB):
-- Monetisasi & Program Pendukung (1 harga Rp50.000/bulan) + Entitlement/Trial +
-- Iklan Pelanggan + Laporan ke Bos + Guide + Fondasi Control Plane Skala
-- Tanggal: 2026-09-28
--
-- Cara pakai: Supabase Dashboard -> SQL Editor -> New query -> tempel semua -> RUN.
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

-- ============================================================================
-- 1. ALTER EXISTING TABLES
-- ============================================================================

-- 1.1 outlets: nomor WA owner (diisi dari KYC) untuk wa.me (WA mode pribadi)
ALTER TABLE public.outlets
  ADD COLUMN IF NOT EXISTS owner_wa_number TEXT;

-- 1.2 supporters: REVISI tabel 3.0 -> SATU tier 'pendukung' Rp50.000/bulan
--     + status trial/active/expired/cancelled + reverse trial + auto_renew
CREATE TABLE IF NOT EXISTS public.supporters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
  tier TEXT NOT NULL DEFAULT 'pendukung',
  amount DECIMAL(12,2) DEFAULT 50000,
  status TEXT DEFAULT 'trial' CHECK (status IN ('trial','active','expired','cancelled')),
  trial_started_at TIMESTAMPTZ,
  start_date TIMESTAMPTZ DEFAULT NOW(),
  end_date TIMESTAMPTZ,
  auto_renew BOOLEAN DEFAULT true,
  pg_reference_id TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.supporters
  ADD COLUMN IF NOT EXISTS trial_started_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS auto_renew BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS pg_reference_id TEXT,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS start_date TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS end_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS tier TEXT DEFAULT 'pendukung',
  ADD COLUMN IF NOT EXISTS amount DECIMAL(12,2) DEFAULT 50000,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'trial';

-- Normalisasi baris lama (3 tier -> 1 tier) sebelum memasang ulang CHECK.
UPDATE public.supporters SET tier = 'pendukung' WHERE tier IS NULL OR tier NOT IN ('pendukung');
UPDATE public.supporters SET amount = 50000 WHERE amount IS NULL;
UPDATE public.supporters SET status = 'active' WHERE status IS NULL;

ALTER TABLE public.supporters ALTER COLUMN tier SET DEFAULT 'pendukung';
ALTER TABLE public.supporters ALTER COLUMN tier SET NOT NULL;
ALTER TABLE public.supporters ALTER COLUMN amount SET DEFAULT 50000;
ALTER TABLE public.supporters ALTER COLUMN status SET DEFAULT 'trial';

ALTER TABLE public.supporters DROP CONSTRAINT IF EXISTS supporters_tier_check;
ALTER TABLE public.supporters ADD CONSTRAINT supporters_tier_check CHECK (tier IN ('pendukung'));

ALTER TABLE public.supporters DROP CONSTRAINT IF EXISTS supporters_status_check;
ALTER TABLE public.supporters ADD CONSTRAINT supporters_status_check
  CHECK (status IN ('trial','active','expired','cancelled'));

-- ============================================================================
-- 2. CREATE NEW TABLES
-- ============================================================================

-- 2.1 entitlements: hak akses outlet (supporter / ad-free / fitur per-key / trial)
CREATE TABLE IF NOT EXISTS public.entitlements (
  outlet_id UUID PRIMARY KEY REFERENCES public.outlets(id) ON DELETE CASCADE,
  is_supporter BOOLEAN DEFAULT false,
  ad_free BOOLEAN DEFAULT false,
  features JSONB DEFAULT '{}',
  trial_ends_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.entitlements
  ADD COLUMN IF NOT EXISTS features JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 2.2 billing_events: jejak tagihan/pembayaran Program Pendukung
CREATE TABLE IF NOT EXISTS public.billing_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
  event TEXT, amount NUMERIC DEFAULT 0, status TEXT, ref TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.3 report_schedules: laporan otomatis ke bos (maks 3 penerima)
CREATE TABLE IF NOT EXISTS public.report_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
  period TEXT CHECK (period IN ('daily','weekly','monthly')),
  send_time TIME DEFAULT '21:00',
  day_of_week INT,
  day_of_month INT,
  recipients JSONB DEFAULT '[]',
  channels JSONB DEFAULT '["email"]',
  content_flags JSONB DEFAULT '{}',
  enabled BOOLEAN DEFAULT true,
  last_sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.4 outlet_ad_state: status iklan sisi pelanggan (owner TIDAK melihat iklan)
CREATE TABLE IF NOT EXISTS public.outlet_ad_state (
  outlet_id UUID PRIMARY KEY REFERENCES public.outlets(id) ON DELETE CASCADE,
  ad_enabled BOOLEAN DEFAULT true,
  ad_free BOOLEAN DEFAULT false,
  impressions INT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.5 guide_items: panduan penggunaan PDF/video (dikelola superadmin)
CREATE TABLE IF NOT EXISTS public.guide_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  kind TEXT CHECK (kind IN ('pdf','video')),
  category TEXT, role TEXT,
  url TEXT, file_key TEXT, thumbnail_key TEXT,
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.6 platform_configs: fondasi Control Plane (scope + version + effective_from)
CREATE TABLE IF NOT EXISTS public.platform_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL,
  scope TEXT DEFAULT 'global' CHECK (scope IN ('global','segment','outlet')),
  scope_ref TEXT,
  value JSONB DEFAULT '{}',
  version INT DEFAULT 1,
  effective_from TIMESTAMPTZ,
  updated_by UUID,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (key, scope, scope_ref)
);

-- 2.7 feature_flags: nyala/mati fitur per segmen/outlet_type + rollout persen
CREATE TABLE IF NOT EXISTS public.feature_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  enabled BOOLEAN DEFAULT false,
  rollout_pct INT DEFAULT 100,
  segments JSONB DEFAULT '[]',
  outlet_types JSONB DEFAULT '[]',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.8 automation_rules: otomatisasi dasar (auto-trial/auto-lock/auto-report/auto-KYC)
CREATE TABLE IF NOT EXISTS public.automation_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT, trigger TEXT,
  condition JSONB DEFAULT '{}', action JSONB DEFAULT '{}',
  enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.9 segments + outlet_segments: segmentasi outlet untuk rules/flags
CREATE TABLE IF NOT EXISTS public.segments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  rules JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.outlet_segments (
  outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
  segment_id UUID REFERENCES public.segments(id) ON DELETE CASCADE,
  PRIMARY KEY (outlet_id, segment_id)
);

-- 2.10 announcements: pengumuman in-app (audience: all/owner/admin/...)
CREATE TABLE IF NOT EXISTS public.announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT, body TEXT,
  audience TEXT DEFAULT 'all',
  starts_at TIMESTAMPTZ, ends_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.11 audit_logs: jejak aksi superadmin/Edge (secret di-mask)
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID, actor_role TEXT, action TEXT, target TEXT,
  meta JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.12 admin_users: RBAC superadmin (superadmin/finance/support/ops)
CREATE TABLE IF NOT EXISTS public.admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  role TEXT CHECK (role IN ('superadmin','finance','support','ops')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 3. SEED GRUP CONTROL PLANE (platform_configs, scope global)
--    Grup: ads, guide, report, kyc, quota, flags, billing
-- ============================================================================
INSERT INTO public.platform_configs (key, scope, scope_ref, value, version, effective_from) VALUES
  ('ads', 'global', 'all',
   '{"provider":"sponsor_lokal","adsterra_key":"","sponsor_local":[],"blocked_categories":["judi","dewasa","pinjol"],"placement":["catalog","qr_menu"],"ad_free_for_supporter":true,"consent_required":true}'::jsonb,
   1, NOW()),
  ('guide', 'global', 'all',
   '{"show_in_settings":true,"default_category":"umum"}'::jsonb,
   1, NOW()),
  ('report', 'global', 'all',
   '{"default_period":"daily","default_time":"21:00","max_recipients":3,"channels":["email","wa"]}'::jsonb,
   1, NOW()),
  ('kyc', 'global', 'all',
   '{"required":true,"auto_verify":true,"fields":["email","phone","store_name","store_address","ktp_image","selfie_ktp"]}'::jsonb,
   1, NOW()),
  ('quota', 'global', 'all',
   '{"max_admin":1,"max_cashier":1,"extra_from_supporter":true}'::jsonb,
   1, NOW()),
  ('flags', 'global', 'all',
   '{"enabled":{}}'::jsonb,
   1, NOW()),
  ('billing', 'global', 'all',
   '{"supporter_price":50000,"currency":"IDR","period":"monthly","trial_days":14,"auto_renew_default":true}'::jsonb,
   1, NOW())
ON CONFLICT (key, scope, scope_ref) DO NOTHING;

-- ============================================================================
-- 4. ROW LEVEL SECURITY (Bagian 3.4)
-- ============================================================================
-- Helper pola: superadmin = COALESCE(auth.jwt()->>'role','') IN ('superowner','superadmin')
--              owner outlet = EXISTS (SELECT 1 FROM outlets o WHERE o.id = <t>.outlet_id AND o.owner_id = auth.uid())

-- 4.1 supporters: owner outlet sendiri (read + kelola auto_renew/checkout), superadmin full
ALTER TABLE public.supporters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access supporters" ON public.supporters;
CREATE POLICY "Superadmin full access supporters" ON public.supporters
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

DROP POLICY IF EXISTS "Owner manage own supporters" ON public.supporters;
CREATE POLICY "Owner manage own supporters" ON public.supporters
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = supporters.outlet_id AND o.owner_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = supporters.outlet_id AND o.owner_id = auth.uid()
  ));

-- 4.2 entitlements: owner outlet sendiri (read/update terbatas), superadmin full
ALTER TABLE public.entitlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access entitlements" ON public.entitlements;
CREATE POLICY "Superadmin full access entitlements" ON public.entitlements
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

DROP POLICY IF EXISTS "Owner read own entitlements" ON public.entitlements;
CREATE POLICY "Owner read own entitlements" ON public.entitlements
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = entitlements.outlet_id AND o.owner_id = auth.uid()
  ));

-- 4.3 billing_events: owner outlet sendiri (read-only), superadmin full
ALTER TABLE public.billing_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access billing_events" ON public.billing_events;
CREATE POLICY "Superadmin full access billing_events" ON public.billing_events
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

DROP POLICY IF EXISTS "Owner read own billing_events" ON public.billing_events;
CREATE POLICY "Owner read own billing_events" ON public.billing_events
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = billing_events.outlet_id AND o.owner_id = auth.uid()
  ));

-- 4.4 report_schedules: owner outlet sendiri (kelola penuh), superadmin full
ALTER TABLE public.report_schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access report_schedules" ON public.report_schedules;
CREATE POLICY "Superadmin full access report_schedules" ON public.report_schedules
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

DROP POLICY IF EXISTS "Owner manage own report_schedules" ON public.report_schedules;
CREATE POLICY "Owner manage own report_schedules" ON public.report_schedules
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = report_schedules.outlet_id AND o.owner_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = report_schedules.outlet_id AND o.owner_id = auth.uid()
  ));

-- 4.5 outlet_ad_state: owner outlet sendiri (read/update), superadmin full
ALTER TABLE public.outlet_ad_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access outlet_ad_state" ON public.outlet_ad_state;
CREATE POLICY "Superadmin full access outlet_ad_state" ON public.outlet_ad_state
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

DROP POLICY IF EXISTS "Owner manage own outlet_ad_state" ON public.outlet_ad_state;
CREATE POLICY "Owner manage own outlet_ad_state" ON public.outlet_ad_state
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = outlet_ad_state.outlet_id AND o.owner_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = outlet_ad_state.outlet_id AND o.owner_id = auth.uid()
  ));

-- 4.6 guide_items: superadmin full CRUD; app client SELECT yang is_active
ALTER TABLE public.guide_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access guide_items" ON public.guide_items;
CREATE POLICY "Superadmin full access guide_items" ON public.guide_items
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

DROP POLICY IF EXISTS "Client read active guide_items" ON public.guide_items;
CREATE POLICY "Client read active guide_items" ON public.guide_items
  FOR SELECT
  USING (is_active = true);

-- 4.7 announcements: superadmin full CRUD; client SELECT yang is_active
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access announcements" ON public.announcements;
CREATE POLICY "Superadmin full access announcements" ON public.announcements
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

DROP POLICY IF EXISTS "Client read active announcements" ON public.announcements;
CREATE POLICY "Client read active announcements" ON public.announcements
  FOR SELECT
  USING (is_active = true);

-- 4.8 platform_configs: superadmin full; client SELECT (config publik non-secret)
ALTER TABLE public.platform_configs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access platform_configs" ON public.platform_configs;
CREATE POLICY "Superadmin full access platform_configs" ON public.platform_configs
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

DROP POLICY IF EXISTS "Client read platform_configs" ON public.platform_configs;
CREATE POLICY "Client read platform_configs" ON public.platform_configs
  FOR SELECT
  USING (true);

-- 4.9 feature_flags: superadmin full; client SELECT
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access feature_flags" ON public.feature_flags;
CREATE POLICY "Superadmin full access feature_flags" ON public.feature_flags
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

DROP POLICY IF EXISTS "Client read feature_flags" ON public.feature_flags;
CREATE POLICY "Client read feature_flags" ON public.feature_flags
  FOR SELECT
  USING (true);

-- 4.10 segments / outlet_segments / automation_rules / audit_logs / admin_users:
--      Superadmin/Edge only (RLS aktif tanpa policy client = ditolak untuk client).
ALTER TABLE public.segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.outlet_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.automation_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access segments" ON public.segments;
CREATE POLICY "Superadmin full access segments" ON public.segments
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

DROP POLICY IF EXISTS "Superadmin full access outlet_segments" ON public.outlet_segments;
CREATE POLICY "Superadmin full access outlet_segments" ON public.outlet_segments
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

DROP POLICY IF EXISTS "Superadmin full access automation_rules" ON public.automation_rules;
CREATE POLICY "Superadmin full access automation_rules" ON public.automation_rules
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

DROP POLICY IF EXISTS "Superadmin full access audit_logs" ON public.audit_logs;
CREATE POLICY "Superadmin full access audit_logs" ON public.audit_logs
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

DROP POLICY IF EXISTS "Superadmin full access admin_users" ON public.admin_users;
CREATE POLICY "Superadmin full access admin_users" ON public.admin_users
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner','superadmin'));

-- ============================================================================
-- 5. INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_supporters_outlet_id ON public.supporters(outlet_id);
CREATE INDEX IF NOT EXISTS idx_supporters_status ON public.supporters(status);
CREATE INDEX IF NOT EXISTS idx_billing_events_outlet_id ON public.billing_events(outlet_id);
CREATE INDEX IF NOT EXISTS idx_report_schedules_outlet_id ON public.report_schedules(outlet_id);
CREATE INDEX IF NOT EXISTS idx_guide_items_active ON public.guide_items(is_active, sort_order);
CREATE INDEX IF NOT EXISTS idx_platform_configs_key ON public.platform_configs(key);
CREATE INDEX IF NOT EXISTS idx_platform_configs_scope ON public.platform_configs(scope, scope_ref);
CREATE INDEX IF NOT EXISTS idx_feature_flags_key ON public.feature_flags(key);
CREATE INDEX IF NOT EXISTS idx_announcements_active ON public.announcements(is_active);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_users_user_id ON public.admin_users(user_id);

-- ============================================================================
-- VERIFIKASI (opsional, jalankan SELECT untuk cek):
--   SELECT key, scope, scope_ref, version FROM public.platform_configs ORDER BY key;
--   SELECT column_name FROM information_schema.columns
--     WHERE table_name = 'supporters' ORDER BY column_name;
-- ============================================================================
