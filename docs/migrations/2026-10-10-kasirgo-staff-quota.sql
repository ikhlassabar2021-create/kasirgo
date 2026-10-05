-- Migrasi: tabel outlet_staff_quota HILANG di DB live (404 PGRST205).
--
-- Gejala: settings_screen.dart ~107 query `.from('outlet_staff_quota')`
-- -> {"code":"PGRST205","message":"Could not find the table
--     'public.outlet_staff_quota' in the schema cache"}.
-- Kartu "Kuota Staff" selalu 0/5 (query ada di dalam try/catch, gagal senyap).
--
-- Spec: docs/KASIRGO-WORKFLOW-LENGKAP.md Bagian 3 (~617) mendefinisikan
-- kolom max_admin, max_cashier, extra_from_supporter. Aplikasi yang SUDAH
-- ter-deploy membaca `max_staff` + `current_staff_count` lewat
-- `.select('*').maybeSingle()`, jadi tabel ini menyediakan kolom spec
-- SEKALIGUS kolom kompat-app yang dijaga trigger (tanpa perlu rebuild app).
--
-- Idempoten: aman dijalankan ulang.
BEGIN;

CREATE TABLE IF NOT EXISTS public.outlet_staff_quota (
  outlet_id UUID PRIMARY KEY REFERENCES public.outlets(id) ON DELETE CASCADE,
  max_admin INT NOT NULL DEFAULT 1,
  max_cashier INT NOT NULL DEFAULT 1,
  extra_from_supporter BOOLEAN NOT NULL DEFAULT false,
  -- Kolom kompat-app (dibaca settings_screen.dart) -- dijaga trigger di bawah.
  max_staff INT NOT NULL DEFAULT 2,
  current_staff_count INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Fungsi: hitung ulang kuota + jumlah staf satu outlet.
-- Slot tambahan saat outlet berstatus pendukung (extra_from_supporter).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.refresh_staff_quota(target_outlet uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_max_admin int;
  v_max_cashier int;
  v_extra boolean;
  v_count int;
BEGIN
  IF target_outlet IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.outlet_staff_quota (outlet_id)
  VALUES (target_outlet)
  ON CONFLICT (outlet_id) DO NOTHING;

  SELECT max_admin, max_cashier, extra_from_supporter
    INTO v_max_admin, v_max_cashier, v_extra
  FROM public.outlet_staff_quota
  WHERE outlet_id = target_outlet;

  SELECT count(*) INTO v_count
  FROM public.user_roles
  WHERE outlet_id = target_outlet
    AND role IN ('admin', 'cashier', 'kitchen');

  UPDATE public.outlet_staff_quota
     SET max_staff = COALESCE(v_max_admin, 1) + COALESCE(v_max_cashier, 1)
                     + CASE WHEN COALESCE(v_extra, false) THEN 8 ELSE 0 END,
         current_staff_count = COALESCE(v_count, 0),
         updated_at = NOW()
   WHERE outlet_id = target_outlet;
END;
$$;

-- ---------------------------------------------------------------------------
-- Trigger: setiap perubahan user_roles -> refresh kuota outlet terkait.
-- Dibungkus EXCEPTION agar kegagalan (mis. saat signup sebelum baris outlet
-- ada) TIDAK membatalkan alur auth.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_staff_quota_from_roles()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  BEGIN
    PERFORM public.refresh_staff_quota(COALESCE(NEW.outlet_id, OLD.outlet_id));
  EXCEPTION WHEN others THEN
    NULL;
  END;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_staff_quota_from_roles ON public.user_roles;
CREATE TRIGGER trg_staff_quota_from_roles
AFTER INSERT OR UPDATE OR DELETE ON public.user_roles
FOR EACH ROW EXECUTE FUNCTION public.trg_staff_quota_from_roles();

-- ---------------------------------------------------------------------------
-- Trigger: perubahan komponen kuota -> hitung ulang max_staff + updated_at.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_staff_quota_before_write()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.max_staff := COALESCE(NEW.max_admin, 1) + COALESCE(NEW.max_cashier, 1)
                   + CASE WHEN COALESCE(NEW.extra_from_supporter, false) THEN 8 ELSE 0 END;
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_staff_quota_before_write ON public.outlet_staff_quota;
CREATE TRIGGER trg_staff_quota_before_write
BEFORE INSERT OR UPDATE ON public.outlet_staff_quota
FOR EACH ROW EXECUTE FUNCTION public.trg_staff_quota_before_write();

-- ---------------------------------------------------------------------------
-- Backfill: buat baris kuota untuk semua outlet + hitung staf existing.
-- ---------------------------------------------------------------------------
INSERT INTO public.outlet_staff_quota (outlet_id)
SELECT id FROM public.outlets
ON CONFLICT (outlet_id) DO NOTHING;

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT outlet_id FROM public.outlet_staff_quota LOOP
    PERFORM public.refresh_staff_quota(r.outlet_id);
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- RLS: Owner read outlet sendiri; Superadmin full; tulis via trigger
-- SECURITY DEFINER (app hanya membaca).
-- ---------------------------------------------------------------------------
ALTER TABLE public.outlet_staff_quota ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmin full access outlet_staff_quota"
  ON public.outlet_staff_quota;
CREATE POLICY "Superadmin full access outlet_staff_quota"
  ON public.outlet_staff_quota
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') IN ('superowner', 'superadmin'))
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') IN ('superowner', 'superadmin'));

DROP POLICY IF EXISTS "Owner read own outlet_staff_quota"
  ON public.outlet_staff_quota;
CREATE POLICY "Owner read own outlet_staff_quota"
  ON public.outlet_staff_quota
  FOR SELECT TO authenticated
  USING (public.is_outlet_owner(outlet_id));

COMMIT;
