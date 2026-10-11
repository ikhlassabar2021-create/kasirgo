-- ============================================================================
-- KASIRGO PHASE 16F - KONEKSI OTOMATIS KANAL (OAuth "Login dengan Facebook" dll)
-- ============================================================================
-- Tujuan: TAMBAHAN opsi bagi owner untuk menghubungkan akun kanal secara
--   OTOMATIS lewat tombol "Hubungkan Otomatis" (alur OAuth resmi platform),
--   TANPA menghapus form manual (nama akun + token) yang sudah ada.
-- Keamanan:
--   - Kredensial aplikasi (App ID/App Secret) HANYA di
--     platform_configs.digital_marketing_llm.oauth -> service_role only
--     (tidak bisa dibaca klien / anon / authenticated).
--   - Token hasil OAuth disimpan server-side ke dm_channel_accounts.token_enc
--     (tabel tetap tanpa policy baca owner) -> token tak pernah sampai ke klien.
--   - dm_oauth_states = tabel anti-CSRF; service_role only (tanpa policy).
-- Idempoten.
-- ============================================================================

-- 1) State OAuth (anti-CSRF). Tanpa policy RLS => hanya service_role (EF).
CREATE TABLE IF NOT EXISTS public.dm_oauth_states (
  state TEXT PRIMARY KEY,
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  channel TEXT NOT NULL,
  provider TEXT NOT NULL,
  user_id UUID NOT NULL,
  redirect_to TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '15 minutes'),
  consumed_at TIMESTAMPTZ
);

ALTER TABLE public.dm_oauth_states ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_dm_oauth_states_outlet
  ON public.dm_oauth_states(outlet_id);
CREATE INDEX IF NOT EXISTS idx_dm_oauth_states_expires
  ON public.dm_oauth_states(expires_at);

-- 2) Seed kunci konfigurasi OAuth (kosong; superadmin mengisi App ID/Secret).
UPDATE public.platform_configs
SET value = jsonb_set(
      value,
      '{oauth}',
      COALESCE(value->'oauth', '{}'::jsonb),
      true
    ),
    updated_at = NOW()
WHERE key = 'digital_marketing_llm'
  AND scope = 'global'
  AND NOT (value ? 'oauth');

-- ============================================================================
-- VERIFIKASI:
--   SELECT value->'oauth' FROM public.platform_configs
--    WHERE key='digital_marketing_llm' AND scope='global';  -- {} sebelum diisi
--   SELECT count(*) FROM public.dm_oauth_states;             -- 0
-- ============================================================================
