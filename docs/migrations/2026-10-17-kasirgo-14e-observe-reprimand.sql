-- Phase 14 ST14-11: memori & observasi jangka panjang + teguran otomatis (BAGIAN 13.15/13.21B).
-- 1. doctor_action_logs += status (planned|running|done), due_date, reminder_count, last_reminded_at.
-- 2. doctor_memory kind diperluas: reprimand (teguran) + market/scaling (Phase 15).
-- Semua idempotent.

ALTER TABLE public.doctor_action_logs
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'planned'
    CHECK (status IN ('planned','running','done')),
  ADD COLUMN IF NOT EXISTS due_date DATE,
  ADD COLUMN IF NOT EXISTS reminder_count INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_reminded_at TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'doctor_action_logs_status_check'
  ) THEN
    ALTER TABLE public.doctor_action_logs
      ADD CONSTRAINT doctor_action_logs_status_check
      CHECK (status IN ('planned','running','done'));
  END IF;
END $$;

-- 3. doctor_memory: kolom data (jsonb) + resolved_at (spec BAGIAN 13.7) jika belum ada.
ALTER TABLE public.doctor_memory
  ADD COLUMN IF NOT EXISTS data JSONB,
  ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;

-- Perluas kind doctor_memory (reprimand = teguran; market/scaling untuk Phase 15).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'doctor_memory_kind_check'
      AND conrelid = 'public.doctor_memory'::regclass
  ) THEN
    ALTER TABLE public.doctor_memory DROP CONSTRAINT doctor_memory_kind_check;
  END IF;
END $$;

ALTER TABLE public.doctor_memory
  ADD CONSTRAINT doctor_memory_kind_check
  CHECK (kind IN ('diagnosis','prescription','result','lesson','fact','reprimand','market','scaling'));

CREATE INDEX IF NOT EXISTS idx_doctor_memory_due
  ON public.doctor_memory (outlet_id, status, due_at)
  WHERE kind = 'prescription';
CREATE INDEX IF NOT EXISTS idx_doctor_action_due
  ON public.doctor_action_logs (outlet_id, status, due_date);
