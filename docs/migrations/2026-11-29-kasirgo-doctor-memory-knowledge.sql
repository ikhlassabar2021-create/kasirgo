-- ============================================================================
-- KASIRGO 3.0 - DOKTER BISNIS: MEMORI CHAT + PENGETAHUAN MANUAL
-- Tujuan:
--   1) Setiap percakapan punya ringkasan memori (kind 'chat_summary') yang
--      otomatis dibuat Edge Function business_doctor_chat, sehingga Dokter
--      mengingat percakapan sebelumnya walau beda sesi.
--   2) Owner bisa menambah pengetahuan sendiri (kind 'knowledge') dari dalam
--      fitur Dokter Bisnis; ikut disuntik ke prompt AI.
--   3) Memori tetap bisa dihapus (RLS owner ALL sudah ada sejak Phase 14).
-- Idempotent.
-- ============================================================================

-- 1) Perluas kind doctor_memory.
ALTER TABLE public.doctor_memory DROP CONSTRAINT IF EXISTS doctor_memory_kind_check;
ALTER TABLE public.doctor_memory ADD CONSTRAINT doctor_memory_kind_check
  CHECK (kind = ANY (ARRAY[
    'diagnosis','prescription','result','lesson','fact',
    'reprimand','market','scaling','weekly_report',
    'knowledge','chat_summary'
  ]));

-- 2) Satu ringkasan per percakapan (upsert aman, tidak dobel).
CREATE UNIQUE INDEX IF NOT EXISTS uq_doctor_memory_chat_summary
  ON public.doctor_memory (conversation_id)
  WHERE kind = 'chat_summary' AND conversation_id IS NOT NULL;

-- 3) Index baca cepat per jenis memori.
CREATE INDEX IF NOT EXISTS idx_doctor_memory_kind_created
  ON public.doctor_memory (outlet_id, kind, created_at DESC);

-- 4) Asal memori: 'doctor' (AI), 'chat' (ringkasan otomatis), 'manual' (owner).
ALTER TABLE public.doctor_memory
  ADD COLUMN IF NOT EXISTS origin TEXT DEFAULT 'doctor';

-- Backfill: ringkasan chat lama tidak ada; pengetahuan manual default 'manual'
-- hanya untuk baris baru. Baris lama dibiarkan 'doctor'.
