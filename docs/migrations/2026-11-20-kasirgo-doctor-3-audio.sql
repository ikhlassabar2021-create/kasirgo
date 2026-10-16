-- ============================================================================
-- KASIRGO 3.0 - Dokter Bisnis 3.0 (Persona + Dosis Harian + Gamifikasi)
--               + Fitur Suara Interaktif (soundbox POS & teguran)
-- Tanggal: 2026-11-20
--
-- Sifat: ADITIF. Tidak mengubah/menghapus kolom atau tabel stabil yang ada.
--
-- Isi:
--   1. doctor_outlet_profile: preferred_tone, vitals, xp, level, daily_streak,
--      last_dose_at, boss_wa_number.
--   2. Tabel doctor_daily_doses  -> Dosis Harian (checklist harian).
--   3. Tabel doctor_briefings    -> Briefing "Apel Pagi" (cuaca/kalender/stok).
--   4. RLS kedua tabel (owner + superadmin).
--   5. Merge config platform_configs.business_doctor: tone_presets,
--      daily_dose, briefing, audio (soundbox).
-- Idempotent (aman dijalankan berulang).
-- ============================================================================

-- ============================================================================
-- 1. doctor_outlet_profile: persona, vitals, gamifikasi
-- ============================================================================
ALTER TABLE public.doctor_outlet_profile
  ADD COLUMN IF NOT EXISTS preferred_tone TEXT DEFAULT 'hangat',
  ADD COLUMN IF NOT EXISTS vitals JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS xp INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS level INT DEFAULT 1,
  ADD COLUMN IF NOT EXISTS daily_streak INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_dose_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS boss_wa_number TEXT;

-- ============================================================================
-- 2. doctor_daily_doses: Dosis Harian (1 baris per outlet per hari)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.doctor_daily_doses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  dose_date DATE NOT NULL DEFAULT CURRENT_DATE,
  title TEXT DEFAULT 'Dosis Harian',
  items JSONB DEFAULT '[]'::jsonb,
  total_items INT DEFAULT 0,
  done_items INT DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','partial','done')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (outlet_id, dose_date)
);
CREATE INDEX IF NOT EXISTS idx_daily_doses_outlet
  ON public.doctor_daily_doses (outlet_id, dose_date DESC);

-- ============================================================================
-- 3. doctor_briefings: Briefing "Apel Pagi" (1 baris per outlet per hari)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.doctor_briefings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  briefing_date DATE NOT NULL DEFAULT CURRENT_DATE,
  weather JSONB DEFAULT '{}'::jsonb,
  calendar_note TEXT,
  low_stock JSONB DEFAULT '[]'::jsonb,
  summary TEXT,
  items JSONB DEFAULT '[]'::jsonb,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (outlet_id, briefing_date)
);
CREATE INDEX IF NOT EXISTS idx_briefings_outlet
  ON public.doctor_briefings (outlet_id, briefing_date DESC);

-- ============================================================================
-- 4. RLS
-- ============================================================================
ALTER TABLE public.doctor_daily_doses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access doctor_daily_doses" ON public.doctor_daily_doses;
CREATE POLICY "Superadmin full access doctor_daily_doses" ON public.doctor_daily_doses
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Owner access own doctor_daily_doses" ON public.doctor_daily_doses;
CREATE POLICY "Owner access own doctor_daily_doses" ON public.doctor_daily_doses
  FOR ALL TO authenticated
  USING (public.is_outlet_owner(outlet_id))
  WITH CHECK (public.is_outlet_owner(outlet_id));

ALTER TABLE public.doctor_briefings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access doctor_briefings" ON public.doctor_briefings;
CREATE POLICY "Superadmin full access doctor_briefings" ON public.doctor_briefings
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Owner access own doctor_briefings" ON public.doctor_briefings;
CREATE POLICY "Owner access own doctor_briefings" ON public.doctor_briefings
  FOR ALL TO authenticated
  USING (public.is_outlet_owner(outlet_id))
  WITH CHECK (public.is_outlet_owner(outlet_id));

-- ============================================================================
-- 5. Merge config business_doctor: tone_presets / daily_dose / briefing / audio
-- ============================================================================
UPDATE public.platform_configs
SET value = value
  || '{
    "tone_presets": {
      "hangat":  "Ramah, membesarkan hati, bahasa sederhana, pakai sapaan akrab.",
      "tegas":   "Tegas dan disiplin, tunjuk angka, dorong tindakan cepat tanpa menggurui.",
      "singkat": "Sangat ringkas, maksimal 3 poin, langsung ke solusi.",
      "santai":  "Santai dan jenaka ringan, boleh bercanda wajar, tetap fokus solusi."
    },
    "default_tone": "hangat",
    "daily_dose": { "aktif": true, "maks_langkah": 3, "jam_kirim": 7 },
    "briefing": {
      "aktif": true,
      "cuaca": true,
      "kalender": true,
      "stok_minimum": 5,
      "jam_kirim": 6
    },
    "audio": { "aktif": true, "soundbox_pos": true, "teguran": true }
  }'::jsonb,
  version = version + 1,
  effective_from = NOW()
WHERE key = 'business_doctor';

-- Fallback bila baris config belum ada (harusnya sudah ada sejak Phase 14).
INSERT INTO public.platform_configs (key, scope, scope_ref, value, version, effective_from)
SELECT
  'business_doctor', 'global', 'all',
  '{
    "aktif": true,
    "bahasa": "id",
    "tone_presets": {
      "hangat":  "Ramah, membesarkan hati, bahasa sederhana, pakai sapaan akrab.",
      "tegas":   "Tegas dan disiplin, tunjuk angka, dorong tindakan cepat tanpa menggurui.",
      "singkat": "Sangat ringkas, maksimal 3 poin, langsung ke solusi.",
      "santai":  "Santai dan jenaka ringan, boleh bercanda wajar, tetap fokus solusi."
    },
    "default_tone": "hangat",
    "daily_dose": { "aktif": true, "maks_langkah": 3, "jam_kirim": 7 },
    "briefing": { "aktif": true, "cuaca": true, "kalender": true, "stok_minimum": 5, "jam_kirim": 6 },
    "audio": { "aktif": true, "soundbox_pos": true, "teguran": true }
  }'::jsonb,
  1, NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.platform_configs WHERE key = 'business_doctor');
