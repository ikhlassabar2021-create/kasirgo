-- ============================================================================
-- KasirGo 3.0 — Phase 14: Dokter Bisnis AI (BAGIAN 13.7)
-- Tanggal: 2026-10-06
--
-- Isi:
--   1. Tabel: outlet_ai_configs, doctor_conversations, doctor_messages,
--      doctor_action_logs, doctor_intake, doctor_memory, doctor_outlet_profile.
--   2. Index outlet_id / conversation_id / created_at.
--   3. Seed platform_configs key 'business_doctor' (prompt, guardrails, provider).
--   4. RLS: outlet hanya akses percakapan/aksi outlet sendiri; api_key_enc
--      HANYA service_role (dicabut dari authenticated; hanya via view ter-mask).
--   5. Helper outlet_supporter_active() untuk gating langganan.
-- Idempotent (aman dijalankan berulang).
-- ============================================================================

-- ============================================================================
-- 1. TABEL
-- ============================================================================

-- 1.1 outlet_ai_configs: override provider AI per outlet (api_key terenkripsi).
CREATE TABLE IF NOT EXISTS public.outlet_ai_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID UNIQUE REFERENCES public.outlets(id) ON DELETE CASCADE,
  provider TEXT DEFAULT 'openai',
  base_url TEXT,
  api_key_enc TEXT,
  model TEXT,
  temperature NUMERIC DEFAULT 0.7,
  max_tokens INT DEFAULT 800,
  is_active BOOLEAN DEFAULT false,
  last_tested_at TIMESTAMPTZ,
  last_test_result TEXT,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.2 doctor_conversations: sesi konsultasi.
CREATE TABLE IF NOT EXISTS public.doctor_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
  user_id UUID,
  title TEXT,
  phase TEXT DEFAULT 'A' CHECK (phase IN ('A','B','C')),
  status TEXT DEFAULT 'aktif'
    CHECK (status IN ('aktif','evaluasi_ulang','selesai','kasus_bandel')),
  escalation_level INT DEFAULT 0,
  summary TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.3 doctor_messages: riwayat pesan + blok UI + tool calls + token.
CREATE TABLE IF NOT EXISTS public.doctor_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES public.doctor_conversations(id) ON DELETE CASCADE,
  outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
  role TEXT CHECK (role IN ('user','assistant','system','tool')),
  content TEXT,
  blocks JSONB DEFAULT '[]',
  tool_calls JSONB DEFAULT '[]',
  tokens INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.4 doctor_action_logs: catatan eksekusi resep & hasil promosi.
CREATE TABLE IF NOT EXISTS public.doctor_action_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
  conversation_id UUID REFERENCES public.doctor_conversations(id) ON DELETE SET NULL,
  action_type TEXT,
  channel TEXT,
  cost NUMERIC DEFAULT 0,
  description TEXT,
  action_date DATE,
  result JSONB DEFAULT '{}',
  outcome TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.5 doctor_intake: indikator fisik/visual/perilaku (wizard bergambar).
CREATE TABLE IF NOT EXISTS public.doctor_intake (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
  conversation_id UUID REFERENCES public.doctor_conversations(id) ON DELETE CASCADE,
  physical JSONB DEFAULT '{}',
  visual_notes TEXT,
  visual_refs JSONB DEFAULT '[]',
  behavior JSONB DEFAULT '{}',
  completed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.6 doctor_memory: memori jangka panjang (vonis/resep/lesson).
CREATE TABLE IF NOT EXISTS public.doctor_memory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
  conversation_id UUID REFERENCES public.doctor_conversations(id) ON DELETE SET NULL,
  kind TEXT CHECK (kind IN ('diagnosis','prescription','result','lesson','fact')),
  title TEXT,
  content TEXT,
  status TEXT DEFAULT 'open' CHECK (status IN ('open','achieved','failed')),
  due_at TIMESTAMPTZ,
  lesson TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.7 doctor_outlet_profile: digest memori + fase + umur usaha per outlet.
CREATE TABLE IF NOT EXISTS public.doctor_outlet_profile (
  outlet_id UUID PRIMARY KEY REFERENCES public.outlets(id) ON DELETE CASCADE,
  memory_digest TEXT,
  business_age_days INT,
  phase TEXT DEFAULT 'A',
  total_conversations INT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 2. INDEX
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_doctor_conv_outlet ON public.doctor_conversations (outlet_id);
CREATE INDEX IF NOT EXISTS idx_doctor_conv_created ON public.doctor_conversations (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_doctor_msg_conv ON public.doctor_messages (conversation_id);
CREATE INDEX IF NOT EXISTS idx_doctor_msg_outlet ON public.doctor_messages (outlet_id);
CREATE INDEX IF NOT EXISTS idx_doctor_msg_created ON public.doctor_messages (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_doctor_action_outlet ON public.doctor_action_logs (outlet_id);
CREATE INDEX IF NOT EXISTS idx_doctor_action_created ON public.doctor_action_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_doctor_intake_outlet ON public.doctor_intake (outlet_id);
CREATE INDEX IF NOT EXISTS idx_doctor_memory_outlet ON public.doctor_memory (outlet_id);
CREATE INDEX IF NOT EXISTS idx_doctor_memory_status ON public.doctor_memory (status);
CREATE INDEX IF NOT EXISTS idx_ai_config_outlet ON public.outlet_ai_configs (outlet_id);

-- ============================================================================
-- 3. SEED platform_configs: business_doctor
-- ============================================================================
INSERT INTO public.platform_configs (key, scope, scope_ref, value, version, effective_from)
VALUES (
  'business_doctor',
  'global',
  'all',
  '{
    "aktif": true,
    "bahasa": "id",
    "prompt_utama": "Kamu adalah Dokter Bisnis KasirGo: konsultan UMKM Indonesia yang ramah, jujur, dan praktis. Bantu pemilik warung/toko memperbaiki omzet dengan langkah nyata yang bisa dikerjakan orang gaptek. Selalu beri langkah kecil, hindari istilah teknis, dan akui bila data belum cukup.",
    "role_outlet": {
      "kelontong": "Fokus stok cepat laku, harga ecer vs kulakan, arus kas harian, pelanggan langganan.",
      "warteg": "Fokus porsi, bahan baku, jam ramai, menu andalan, sisa makanan.",
      "cafe": "Fokus pengalaman pelanggan, menu unggulan, jam sepi, promosi media sosial.",
      "retail": "Fokus margin per kategori, perputaran stok, bundling, display produk."
    },
    "guardrails": [
      "Jangan menjanjikan kepastian kenaikan omzet.",
      "Selalu sebut ini saran AI, bukan jaminan.",
      "Tolak topik di luar bisnis/UMKM (politik, agama, SARA, medis, hukum pribadi).",
      "Jangan minta data pribadi sensitif (KTP, password, nomor kartu).",
      "Gunakan bahasa Indonesia sederhana, hindari istilah teknis."
    ],
    "provider_default": {
      "base_url": "",
      "api_key": "",
      "model": "",
      "temperature": 0.7,
      "max_tokens": 800
    },
    "internet_tool": {
      "aktif": false,
      "provider": "",
      "api_key": ""
    }
  }'::jsonb,
  1,
  NOW()
)
ON CONFLICT (key, scope, scope_ref) DO NOTHING;

-- ============================================================================
-- 4. RLS
-- ============================================================================

-- 4.1 outlet_ai_configs: api_key_enc HANYA service_role.
ALTER TABLE public.outlet_ai_configs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access outlet_ai_configs" ON public.outlet_ai_configs;
CREATE POLICY "Superadmin full access outlet_ai_configs" ON public.outlet_ai_configs
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Owner read own outlet_ai_configs" ON public.outlet_ai_configs;
CREATE POLICY "Owner read own outlet_ai_configs" ON public.outlet_ai_configs
  FOR SELECT TO authenticated
  USING (public.is_outlet_owner(outlet_id));

-- Cabut akses kolom api_key_enc dari klien; sisakan kolom non-secret.
REVOKE ALL ON public.outlet_ai_configs FROM anon, authenticated;
GRANT SELECT (
  id, outlet_id, provider, base_url, model, temperature, max_tokens, is_active,
  last_tested_at, last_test_result, updated_by, created_at, updated_at
) ON public.outlet_ai_configs TO authenticated;
GRANT ALL ON public.outlet_ai_configs TO service_role;

-- View publik ter-mask (MENGEcualikan api_key_enc), definer + filter outlet.
CREATE OR REPLACE VIEW public.outlet_ai_configs_public AS
SELECT
  c.id, c.outlet_id, c.provider, c.base_url, c.model, c.temperature, c.max_tokens,
  c.is_active, (c.api_key_enc IS NOT NULL) AS has_api_key,
  c.last_tested_at, c.last_test_result, c.updated_by, c.created_at, c.updated_at
FROM public.outlet_ai_configs c
WHERE public.is_outlet_owner(c.outlet_id) OR public.is_platform_admin();

GRANT SELECT ON public.outlet_ai_configs_public TO authenticated;

-- 4.2 Tabel percakapan/aksi/memori: outlet hanya akses milik sendiri + superadmin.
DO $$
DECLARE
  t TEXT;
  tables TEXT[] := ARRAY[
    'doctor_conversations','doctor_messages','doctor_action_logs',
    'doctor_intake','doctor_memory'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'Superadmin full access ' || t, t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin())',
      'Superadmin full access ' || t, t
    );

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'Owner access own ' || t, t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL TO authenticated USING (public.is_outlet_owner(outlet_id)) WITH CHECK (public.is_outlet_owner(outlet_id))',
      'Owner access own ' || t, t
    );
  END LOOP;
END $$;

-- 4.3 doctor_outlet_profile: kunci PK outlet_id.
ALTER TABLE public.doctor_outlet_profile ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access doctor_outlet_profile" ON public.doctor_outlet_profile;
CREATE POLICY "Superadmin full access doctor_outlet_profile" ON public.doctor_outlet_profile
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Owner access own doctor_outlet_profile" ON public.doctor_outlet_profile;
CREATE POLICY "Owner access own doctor_outlet_profile" ON public.doctor_outlet_profile
  FOR ALL TO authenticated
  USING (public.is_outlet_owner(outlet_id))
  WITH CHECK (public.is_outlet_owner(outlet_id));

-- ============================================================================
-- 5. HELPER: gating langganan Pendukung/trial aktif (dipakai Edge Function)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.outlet_supporter_active(target_outlet uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    EXISTS (
      SELECT 1 FROM public.supporters s
      WHERE s.outlet_id = target_outlet AND s.status = 'active'
        AND (s.end_date IS NULL OR s.end_date > NOW())
    )
    OR EXISTS (
      SELECT 1 FROM public.supporters s
      WHERE s.outlet_id = target_outlet AND s.status = 'trial'
        AND s.end_date IS NOT NULL AND s.end_date > NOW()
    )
    OR EXISTS (
      SELECT 1 FROM public.entitlements e
      WHERE e.outlet_id = target_outlet
        AND (e.is_supporter = true OR (e.trial_ends_at IS NOT NULL AND e.trial_ends_at > NOW()))
    );
$$;

GRANT EXECUTE ON FUNCTION public.outlet_supporter_active(uuid) TO authenticated, service_role;

-- ============================================================================
-- VERIFIKASI:
--   SELECT key, value FROM public.platform_configs WHERE key='business_doctor';
--   SELECT public.outlet_supporter_active('<outlet_id>');
--   SELECT * FROM public.outlet_ai_configs_public;   -- tanpa kolom api_key_enc
-- ============================================================================
