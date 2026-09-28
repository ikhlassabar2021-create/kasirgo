-- ============================================================================
-- Migrasi Perbaikan KasirGo — Auth Staf & Trigger Onboarding
-- Tanggal: 2026-09-28
-- Jalankan di: Supabase Dashboard -> SQL Editor
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Pastikan CHECK constraint role mencakup 'owner', 'admin', 'cashier'.
--    (Kalau DB live hanya punya 'admin','cashier', signup OWNER akan gagal.)
-- ----------------------------------------------------------------------------
ALTER TABLE public.user_roles DROP CONSTRAINT IF EXISTS user_roles_role_check;
ALTER TABLE public.user_roles
  ADD CONSTRAINT user_roles_role_check
  CHECK (role IN ('admin', 'cashier', 'owner'));

-- ----------------------------------------------------------------------------
-- 2. Perbaiki trigger handle_new_user:
--    - Hanya buat outlet + role 'owner' bila user BUKAN staf.
--    - Bila user punya metadata staff_role/outlet_id -> JANGAN buat outlet baru,
--      cukup daftarkan user_roles sesuai staff_role di outlet yang ditunjuk.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  new_outlet_id UUID;
  staff_role TEXT;
  staff_outlet UUID;
BEGIN
  staff_role := NEW.raw_user_meta_data->>'staff_role';
  staff_outlet := NULLIF(NEW.raw_user_meta_data->>'outlet_id', '')::UUID;

  -- Kasus STAF: jangan buat outlet, langsung pasang role di outlet owner.
  IF staff_role IS NOT NULL AND staff_role IN ('admin', 'cashier') AND staff_outlet IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, outlet_id, role)
    VALUES (NEW.id, staff_outlet, staff_role)
    ON CONFLICT (user_id, outlet_id) DO UPDATE SET role = EXCLUDED.role;
    RETURN NEW;
  END IF;

  -- Kasus OWNER / pendaftar biasa: buat outlet + role owner.
  INSERT INTO public.outlets (owner_id, name, type)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'business_name', 'Toko Baru'),
    COALESCE(NEW.raw_user_meta_data->>'business_type', 'warung')
  )
  RETURNING id INTO new_outlet_id;

  INSERT INTO public.user_roles (user_id, outlet_id, role)
  VALUES (NEW.id, new_outlet_id, 'owner')
  ON CONFLICT (user_id, outlet_id) DO UPDATE SET role = EXCLUDED.role;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public';

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ----------------------------------------------------------------------------
-- 3. (Opsional) Bersihkan outlet "orphan" yang dibuat trigger lama untuk staf.
--    Outlet tanpa produk & tanpa owner aktif dianggap sampah.
--    HATI-HATI: jalankan hanya bila yakin. Di-comment default.
-- ----------------------------------------------------------------------------
-- DELETE FROM public.outlets o
-- WHERE NOT EXISTS (SELECT 1 FROM public.products p WHERE p.outlet_id = o.id)
--   AND NOT EXISTS (SELECT 1 FROM public.transactions t WHERE t.outlet_id = o.id)
--   AND EXISTS (
--     SELECT 1 FROM public.user_roles r
--     WHERE r.outlet_id = o.id AND r.role IN ('admin', 'cashier')
--   );

-- ============================================================================
-- SELESAI
-- ============================================================================
