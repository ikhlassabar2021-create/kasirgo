-- Migrasi: auto-wire slot staf ekstra dari status Program Pendukung / trial.
--
-- Masalah: kolom `outlet_staff_quota.extra_from_supporter` selalu false
-- (default) sehingga outlet yang sedang trial/pendukung tetap dihitung
-- max_staff = 2 -> kartu "Kuota Staff" menampilkan PENUH padahal gate
-- `extra_staff` (client, via entitlements.hasAccess) SUDAH membuka fitur.
-- Keputusan produk: selama pendukung/trial aktif, slot staf = TAK TERBATAS.
--
-- Solusi:
--   1. refresh_staff_quota() menghitung ulang `extra_from_supporter`
--      LANGSUNG dari tabel supporters + entitlements (bukan menumpuk nilai
--      lama) -> otomatis REVOKE saat trial/langganan berakhir.
--   2. max_staff diset sentinel besar (999999) saat extra = TAK TERBATAS.
--   3. Trigger pada supporters + entitlements agar kartu ikut ter-refresh
--      saat status berubah (bukan hanya saat user_roles berubah).
--
-- Idempoten: aman dijalankan ulang.
BEGIN;

-- ---------------------------------------------------------------------------
-- Fungsi: hitung ulang kuota + jumlah staf satu outlet.
-- Slot ekstra TAK TERBATAS bila pendukung/trial aktif (dihitung ulang).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.refresh_staff_quota(target_outlet uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_max_admin int;
  v_max_cashier int;
  v_extra boolean := false;
  v_count int;
  v_supporter boolean := false;
  v_trial boolean := false;
BEGIN
  IF target_outlet IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.outlet_staff_quota (outlet_id)
  VALUES (target_outlet)
  ON CONFLICT (outlet_id) DO NOTHING;

  SELECT max_admin, max_cashier
    INTO v_max_admin, v_max_cashier
  FROM public.outlet_staff_quota
  WHERE outlet_id = target_outlet;

  -- Langganan berbayar aktif.
  SELECT EXISTS (
    SELECT 1 FROM public.supporters s
    WHERE s.outlet_id = target_outlet
      AND s.status = 'active'
      AND (s.end_date IS NULL OR s.end_date > NOW())
  ) INTO v_supporter;

  -- Trial aktif: dari entitlements ATAU baris supporters berstatus trial.
  SELECT EXISTS (
    SELECT 1 FROM public.entitlements e
    WHERE e.outlet_id = target_outlet
      AND e.is_supporter = true
  ) OR EXISTS (
    SELECT 1 FROM public.entitlements e
    WHERE e.outlet_id = target_outlet
      AND e.trial_ends_at IS NOT NULL
      AND e.trial_ends_at > NOW()
  ) OR EXISTS (
    SELECT 1 FROM public.supporters s
    WHERE s.outlet_id = target_outlet
      AND s.status = 'trial'
      AND s.end_date IS NOT NULL
      AND s.end_date > NOW()
  ) INTO v_trial;

  -- Dihitung ulang tiap kali (bukan menumpuk) -> auto-revoke saat berakhir.
  v_extra := COALESCE(v_supporter, false) OR COALESCE(v_trial, false);

  SELECT count(*) INTO v_count
  FROM public.user_roles
  WHERE outlet_id = target_outlet
    AND role IN ('admin', 'cashier', 'kitchen');

  UPDATE public.outlet_staff_quota
     SET extra_from_supporter = v_extra,
         max_staff = CASE WHEN v_extra THEN 999999
                          ELSE COALESCE(v_max_admin, 1)
                               + COALESCE(v_max_cashier, 1) END,
         current_staff_count = COALESCE(v_count, 0),
         updated_at = NOW()
   WHERE outlet_id = target_outlet;
END;
$$;

-- ---------------------------------------------------------------------------
-- Trigger: perubahan user_roles -> refresh kuota outlet terkait.
-- Dibungkus EXCEPTION agar kegagalan tidak membatalkan alur auth.
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
-- Trigger: perubahan status Pendukung / trial -> refresh kuota outlet.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_staff_quota_from_supporter()
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

DROP TRIGGER IF EXISTS trg_staff_quota_from_supporter ON public.supporters;
CREATE TRIGGER trg_staff_quota_from_supporter
AFTER INSERT OR UPDATE OR DELETE ON public.supporters
FOR EACH ROW EXECUTE FUNCTION public.trg_staff_quota_from_supporter();

DROP TRIGGER IF EXISTS trg_staff_quota_from_entitlements ON public.entitlements;
CREATE TRIGGER trg_staff_quota_from_entitlements
AFTER INSERT OR UPDATE OR DELETE ON public.entitlements
FOR EACH ROW EXECUTE FUNCTION public.trg_staff_quota_from_supporter();

-- ---------------------------------------------------------------------------
-- Trigger: komponen kuota berubah -> hitung ulang max_staff + updated_at.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_staff_quota_before_write()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.max_staff := CASE WHEN COALESCE(NEW.extra_from_supporter, false) THEN 999999
                        ELSE COALESCE(NEW.max_admin, 1)
                             + COALESCE(NEW.max_cashier, 1) END;
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_staff_quota_before_write ON public.outlet_staff_quota;
CREATE TRIGGER trg_staff_quota_before_write
BEFORE INSERT OR UPDATE ON public.outlet_staff_quota
FOR EACH ROW EXECUTE FUNCTION public.trg_staff_quota_before_write();

-- ---------------------------------------------------------------------------
-- Backfill: pastikan baris kuota ada untuk semua outlet + hitung ulang.
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

COMMIT;
