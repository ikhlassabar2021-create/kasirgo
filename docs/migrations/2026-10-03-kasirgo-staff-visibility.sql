-- FIX: Owner tidak bisa melihat/mengelola baris user_roles stafnya.
-- Gejala: daftar karyawan selalu kosong; createEmployee upsert gagal 42501
-- (jalur UPDATE butuh visibility via USING), updateEmployeeRole gagal diam-diam.
--
-- PENTING: policy SELECT outlets ("Admin/Cashier can view own outlet")
-- merujuk user_roles, jadi policy user_roles TIDAK BOLEH merujuk outlets
-- secara langsung (infinite recursion 42P17). Solusi: fungsi
-- SECURITY DEFINER is_outlet_owner() yang bypass RLS untuk memutus rantai.
BEGIN;

CREATE OR REPLACE FUNCTION public.is_outlet_owner(target_outlet uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = target_outlet AND o.owner_id = auth.uid()
  );
$$;

DROP POLICY IF EXISTS "Users can see own roles" ON public.user_roles;
CREATE POLICY "Users can see own roles" ON public.user_roles
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_outlet_owner(user_roles.outlet_id)
  );

COMMIT;
