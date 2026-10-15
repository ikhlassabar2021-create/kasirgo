-- ============================================================================
-- KasirGo -- Auth Pembeli (email wajib + konfirmasi + OAuth Google)
-- Tanggal: 2026-11-19
--
-- Tujuan:
--   Pendaftar PEMBELI (signup_kind = 'buyer') memakai Supabase Auth dengan
--   email + password (wajib konfirmasi email) atau Google OAuth. Mereka TIDAK
--   boleh membuat outlet / user_roles seperti pendaftar owner. Trigger
--   handle_new_user cukup mengembalikan NEW (baris app_customers dibuat klien
--   setelah sesi aktif via upsert auth_uid).
--
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

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

  -- Pendaftaran PEMBELI: cukup sesi auth, JANGAN buat outlet/user_roles.
  -- Profil pembeli disimpan di tabel app_customers oleh klien.
  IF signup_kind = 'buyer' THEN
    RETURN NEW;
  END IF;

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

  -- Kasus STAF (termasuk 'kitchen' utk cafe/warteg)
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
