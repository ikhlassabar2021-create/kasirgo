-- ============================================================================
-- KasirGo -- Role KOKI + Status Pesanan Pelanggan
-- Tanggal: 2026-10-09
--
-- Tujuan:
--   1) handle_new_user: izinkan staff_role 'kitchen' (khusus cafe/warteg).
--   2) set_order_status: koki (kitchen) boleh update status pesanan.
--   3) RPC get_public_order_status: pelanggan (anon) pantau status pesanan
--      meja-nya via polling (payment_status + order_status hari ini).
--
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

-- 1) handle_new_user: whitelist + 'kitchen' (disalin persis dari live) -------
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  new_outlet_id UUID;
  staff_role TEXT;
  staff_outlet UUID;
  signup_kind TEXT;
  aff_name TEXT;
  aff_phone TEXT;
  aff_email TEXT;
  aff_code TEXT;
  aff_commission numeric;
  aff_status TEXT;
  cfg jsonb;
BEGIN
  signup_kind := COALESCE(NEW.raw_user_meta_data->>'signup_kind', '');
  staff_role := NEW.raw_user_meta_data->>'staff_role';
  staff_outlet := NULLIF(NEW.raw_user_meta_data->>'outlet_id', '')::UUID;

  -- Pendaftaran AFILIASI: buat baris affiliates, jangan buat outlet/user_roles.
  IF signup_kind = 'affiliate' THEN
    aff_name  := COALESCE(NULLIF(trim(NEW.raw_user_meta_data->>'full_name'), ''), split_part(NEW.email, '@', 1));
    aff_phone := NULLIF(trim(NEW.raw_user_meta_data->>'phone'), '');
    aff_email := lower(trim(COALESCE(NEW.email, '')));

    cfg := public.platform_affiliate_config();
    aff_commission := COALESCE((cfg->>'default_commission')::numeric, 10);
    aff_status := CASE
                   WHEN COALESCE((cfg->>'require_approval')::boolean, false)
                     THEN 'pending'   -- superadmin harus setujui
                   ELSE 'active'         -- default: langsung aktif
                 END;
    aff_code := public.affiliate_generate_code();

    INSERT INTO public.affiliates
      (name, email, phone, user_id, referral_code, commission_percent, status)
    VALUES
      (aff_name, NULLIF(aff_email, ''), aff_phone, NEW.id, aff_code, aff_commission, aff_status)
    ON CONFLICT (email) DO UPDATE
      SET user_id    = EXCLUDED.user_id,
          name       = COALESCE(NULLIF(EXCLUDED.name, ''), public.affiliates.name),
          phone      = COALESCE(EXCLUDED.phone, public.affiliates.phone);

    RETURN NEW;
  END IF;

  -- Kasus STAF (kini termasuk 'kitchen' utk cafe/warteg)
  IF staff_role IN ('admin', 'cashier', 'kitchen') AND staff_outlet IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.outlets WHERE id = staff_outlet) THEN
      INSERT INTO public.user_roles (user_id, outlet_id, role)
      VALUES (NEW.id, staff_outlet, staff_role)
      ON CONFLICT (user_id, outlet_id) DO UPDATE SET role = EXCLUDED.role;
    END IF;
    RETURN NEW;
  END IF;

  -- Kasus OWNER / pendaftar biasa
  INSERT INTO public.outlets (owner_id, name, type)
  VALUES (
    NEW.id,
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'business_name', ''), 'Toko Baru'),
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'business_type', ''), 'warung')
  )
  RETURNING id INTO new_outlet_id;

  INSERT INTO public.user_roles (user_id, outlet_id, role)
  VALUES (NEW.id, new_outlet_id, 'owner')
  ON CONFLICT (user_id, outlet_id) DO UPDATE SET role = EXCLUDED.role;

  RETURN NEW;
END;
$function$;

-- 2) set_order_status: koki boleh memproses pesanan --------------------------
CREATE OR REPLACE FUNCTION public.set_order_status(p_tx UUID, p_status TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_status NOT IN ('baru', 'diproses', 'siap', 'selesai') THEN
    RAISE EXCEPTION 'Status tidak valid';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.transactions t
    WHERE t.id = p_tx
      AND (
        EXISTS (SELECT 1 FROM public.outlets o WHERE o.id = t.outlet_id AND o.owner_id = auth.uid())
        OR EXISTS (
          SELECT 1 FROM public.user_roles r
          WHERE r.user_id = auth.uid()
            AND r.outlet_id = t.outlet_id
            AND r.role IN ('admin', 'cashier', 'kitchen')
        )
      )
  ) THEN
    RAISE EXCEPTION 'Tidak berhak mengubah pesanan ini';
  END IF;

  UPDATE public.transactions SET order_status = p_status WHERE id = p_tx;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_order_status(UUID, TEXT) TO authenticated;

-- 3) Status pesanan utk pelanggan (anon, polling per meja) -------------------
-- Hanya kolom status non-sensitif pesanan HARI INI untuk meja tertentu.
-- Nomor meja tersimpan di notes dengan format 'Meja <table>'.
CREATE OR REPLACE FUNCTION public.get_public_order_status(
  p_outlet TEXT,
  p_table TEXT
)
RETURNS TABLE (
  id UUID,
  payment_method TEXT,
  payment_status TEXT,
  order_status TEXT,
  final_amount NUMERIC,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT t.id, t.payment_method, t.payment_status,
         COALESCE(t.order_status, 'baru'), t.final_amount, t.created_at
  FROM public.transactions t
  WHERE t.outlet_id = p_outlet::uuid
    AND t.channel = 'dine_in'
    AND t.notes = 'Meja ' || COALESCE(NULLIF(trim(p_table), ''), '-')
    AND t.created_at >= date_trunc('day', now())
  ORDER BY t.created_at DESC
  LIMIT 5;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_order_status(TEXT, TEXT) TO anon, authenticated;

-- 4) user_roles.role CHECK: izinkan 'kitchen' -------------------------------
ALTER TABLE public.user_roles DROP CONSTRAINT IF EXISTS user_roles_role_check;
ALTER TABLE public.user_roles ADD CONSTRAINT user_roles_role_check
  CHECK (role IN ('owner', 'admin', 'cashier', 'kitchen'));
