-- KasirGo: Upload APK superadmin -> Supabase Storage (bucket privat)
-- -> Edge Function push_apk_to_github -> branch gh-pages /updates/.
-- Bucket privat; hanya superadmin (is_platform_admin) boleh akses.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('app-updates', 'app-updates', false, 104857600,
        ARRAY['application/vnd.android.package-archive','application/octet-stream']::text[])
ON CONFLICT (id) DO UPDATE
  SET public = false, file_size_limit = 104857600;

DROP POLICY IF EXISTS "app_updates_admin_insert" ON storage.objects;
CREATE POLICY "app_updates_admin_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'app-updates' AND public.is_platform_admin());

DROP POLICY IF EXISTS "app_updates_admin_select" ON storage.objects;
CREATE POLICY "app_updates_admin_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'app-updates' AND public.is_platform_admin());

DROP POLICY IF EXISTS "app_updates_admin_update" ON storage.objects;
CREATE POLICY "app_updates_admin_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'app-updates' AND public.is_platform_admin())
  WITH CHECK (bucket_id = 'app-updates' AND public.is_platform_admin());

DROP POLICY IF EXISTS "app_updates_admin_delete" ON storage.objects;
CREATE POLICY "app_updates_admin_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'app-updates' AND public.is_platform_admin());