-- ============================================================================
-- KASIRGO 3.0 - Dokter Bisnis 3.0 (Lanjutan)
--   Master Switch Suara per Outlet + Persona 3 Preset
-- Tanggal: 2026-11-24
--
-- Sifat: ADITIF + idempotent. Tidak menghapus kolom/tabel stabil.
--
-- Isi:
--   1. doctor_outlet_profile.audio_prefs (JSONB) -> master switch suara per
--      outlet. Objek kosong {} = ikut config global Control Plane.
--   2. Backfill preferred_tone lama (hangat/tegas/santai/singkat) ke 3 persona
--      final: bos_tegas | partner_santai | analis_taktis.
--   3. Merge platform_configs.business_doctor:
--        tone_presets (3 persona, key lama dipertahankan untuk kompatibilitas)
--        persona_labels, default_tone = bos_tegas,
--        audio.per_outlet = true (master switch per outlet diizinkan).
-- ============================================================================

-- ============================================================================
-- 1. Kolom audio_prefs
-- ============================================================================
ALTER TABLE public.doctor_outlet_profile
  ADD COLUMN IF NOT EXISTS audio_prefs JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.doctor_outlet_profile.audio_prefs IS
  'Master switch suara per outlet: {"aktif":bool,"soundbox_pos":bool,"teguran":bool}. Kosong = ikut config global.';

-- ============================================================================
-- 2. Backfill persona lama -> 3 persona final
--    (hanya baris yang belum memakai key persona baru)
-- ============================================================================
UPDATE public.doctor_outlet_profile
SET preferred_tone = CASE lower(coalesce(preferred_tone, ''))
      WHEN 'tegas'    THEN 'bos_tegas'
      WHEN 'hangat'   THEN 'partner_santai'
      WHEN 'santai'   THEN 'partner_santai'
      WHEN 'singkat'  THEN 'analis_taktis'
      ELSE preferred_tone
    END,
    updated_at = NOW()
WHERE lower(coalesce(preferred_tone, '')) IN
      ('tegas', 'hangat', 'santai', 'singkat');

ALTER TABLE public.doctor_outlet_profile
  ALTER COLUMN preferred_tone SET DEFAULT 'bos_tegas';

-- ============================================================================
-- 3. Merge config persona + master switch audio
-- ============================================================================
UPDATE public.platform_configs
SET value = value
  || '{
    "tone_presets": {
      "bos_tegas":      "Tegas, disiplin, langsung ke inti. Tunjuk angka dan tenggat, dorong tindakan cepat. Tanpa menggurui dan tanpa menghakimi.",
      "partner_santai": "Ramah seperti partner lama. Bahasa sederhana, membesarkan hati, boleh bercanda wajar, tetap fokus solusi.",
      "analis_taktis":  "Tenang, berbasis data. Selalu sebut angka, bandingkan periode, jelaskan sebab-akibat, lalu beri langkah terukur.",
      "tegas":          "Tegas dan disiplin, tunjuk angka, dorong tindakan cepat tanpa menggurui.",
      "hangat":         "Ramah, membesarkan hati, bahasa sederhana, pakai sapaan akrab.",
      "santai":         "Santai dan jenaka ringan, boleh bercanda wajar, tetap fokus solusi.",
      "singkat":        "Sangat ringkas, maksimal 3 poin, langsung ke solusi."
    },
    "persona_labels": {
      "bos_tegas":      "Bos Tegas",
      "partner_santai": "Partner Santai",
      "analis_taktis":  "Analis Taktis"
    },
    "default_tone": "bos_tegas",
    "audio": { "aktif": true, "soundbox_pos": true, "teguran": true, "per_outlet": true }
  }'::jsonb,
  version = version + 1,
  effective_from = NOW()
WHERE key = 'business_doctor';
