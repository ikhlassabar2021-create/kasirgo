-- FITUR: nama tampil di daftar karyawan.
-- user_roles tidak menyimpan nama -> UI hanya menampilkan 'Staf (ROLE)'.
-- Solusi: kolom display_name + backfill dari metadata auth.users
-- (staff_name dari EF create_staff, name/full_name dari signup owner).
BEGIN;

ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS display_name text;

UPDATE public.user_roles ur
SET display_name = COALESCE(
  u.raw_user_meta_data->>'staff_name',
  u.raw_user_meta_data->>'name',
  u.raw_user_meta_data->>'full_name'
)
FROM auth.users u
WHERE ur.user_id = u.id
  AND (ur.display_name IS NULL OR ur.display_name = '');

COMMIT;
