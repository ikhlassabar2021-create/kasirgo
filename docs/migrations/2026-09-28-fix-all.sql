-- ============================================================================
-- KasirGo — FIX PENTING (one-shot)
-- Perbaikan: akun staf, trigger, role, email konfirmasi support
-- Tanggal: 2026-09-28
--
-- CARA PAKAI:
--   Supabase Dashboard -> SQL Editor -> New query
--   Tempel SEMUA isi file ini -> RUN
--
-- Aman dijalankan berulang kali (idempotent).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) CHECK constraint role: pastikan mencakup admin, cashier, owner
-- ----------------------------------------------------------------------------
ALTER TABLE public.user_roles DROP CONSTRAINT IF EXISTS user_roles_role_check;
ALTER TABLE public.user_roles
  ADD CONSTRAINT user_roles_role_check
  CHECK (role IN ('admin', 'cashier', 'owner'));

-- ----------------------------------------------------------------------------
-- 2) Trigger handle_new_user:
--    - User STAF (punya metadata staff_role + outlet_id) -> JANGAN buat outlet.
--      Cukup pasang user_roles di outlet owner.
--    - User biasa/OWNER -> buat outlet + role owner.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  new_outlet_id UUID;
  staff_role TEXT;
  staff_outlet UUID;
BEGIN
  staff_role := NEW.raw_user_meta_data->>'staff_role';
  staff_outlet := NULLIF(NEW.raw_user_meta_data->>'outlet_id', '')::UUID;

  -- Kasus STAF
  IF staff_role IN ('admin', 'cashier') AND staff_outlet IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, outlet_id, role)
    VALUES (NEW.id, staff_outlet, staff_role)
    ON CONFLICT (user_id, outlet_id) DO UPDATE SET role = EXCLUDED.role;
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public';

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 3) Bersihkan DATA LAMA yang salah:
--    a) Hapus baris user_roles 'owner' milik user yang sebenarnya STAFF
--       (ditandai metadata staff_role). Trigger lama membuat ini.
--    b) Hapus outlet sampah yang tidak punya produk/transaksi dan
--       owner-nya adalah staff (bukan owner asli).
-- ----------------------------------------------------------------------------
-- 3a) Hapus role 'owner' palsu untuk user staf
DELETE FROM public.user_roles ur
USING auth.users u
WHERE ur.user_id = u.id
  AND ur.role = 'owner'
  AND (u.raw_user_meta_data->>'staff_role') IN ('admin', 'cashier');

-- 3b) Hapus outlet sampah milik user staf (tanpa produk & transaksi)
DELETE FROM public.outlets o
USING auth.users u
WHERE o.owner_id = u.id
  AND (u.raw_user_meta_data->>'staff_role') IN ('admin', 'cashier')
  AND NOT EXISTS (SELECT 1 FROM public.products p WHERE p.outlet_id = o.id)
  AND NOT EXISTS (SELECT 1 FROM public.transactions t WHERE t.outlet_id = o.id);

-- ----------------------------------------------------------------------------
-- 4) Normalisasi tipe outlet lama (label -> kunci modul)
--    Supaya modul (PPOB/QR Meja) langsung benar tanpa login ulang.
-- ----------------------------------------------------------------------------
UPDATE public.outlets SET type = 'kelontong'
  WHERE lower(trim(type)) IN ('warung sembako','warung madura','kelontong','minimarket','lainnya');
UPDATE public.outlets SET type = 'retail'
  WHERE lower(trim(type)) IN ('retail','toko baju','apotek');
UPDATE public.outlets SET type = 'cafe'
  WHERE lower(trim(type)) IN ('cafe','kedai kopi','restoran');
UPDATE public.outlets SET type = 'warteg'
  WHERE lower(trim(type)) IN ('warteg','warung makan');
UPDATE public.outlets SET type = 'gerobak'
  WHERE lower(trim(type)) IN ('gerobak','gerobak keliling');
-- Sisa 'warung' (default lama) -> perlakukan sebagai kelontong
UPDATE public.outlets SET type = 'kelontong' WHERE lower(trim(type)) = 'warung';

-- ============================================================================
-- 5) VERIFIKASI (lihat hasilnya)
-- ============================================================================
SELECT 'user_roles' AS tabel, count(*) AS jumlah FROM public.user_roles
UNION ALL SELECT 'outlets', count(*) FROM public.outlets
UNION ALL SELECT 'outlets.type', count(DISTINCT type) FROM public.outlets;

-- ============================================================================
-- SELESAI
-- ============================================================================
