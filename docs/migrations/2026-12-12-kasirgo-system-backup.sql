-- ============================================================================
-- KASIRGO: FULL SYSTEM BACKUP & RESTORE (superadmin web)
-- Snapshot SELURUH skema `public` (semua data aplikasi), bukan per outlet.
-- Restore = isi ulang baris yang HILANG saja (id/unique sama = dilewati),
-- tidak pernah menimpa; trigger sementara dinonaktifkan agar tidak dobel.
-- Auth (auth.users) dikelola Supabase, tidak termasuk (lihat selfhost).
-- Idempotent: aman dijalankan ulang.
-- ============================================================================

-- Tabel snapshot full-system (payload `data` = jsonb {table: [rows]}).
CREATE TABLE IF NOT EXISTS public.system_backups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kind TEXT NOT NULL DEFAULT 'full',
  status TEXT NOT NULL DEFAULT 'success',
  table_count INT DEFAULT 0,
  row_count INT DEFAULT 0,
  size_bytes BIGINT DEFAULT 0,
  data JSONB,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.system_backups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin all system_backups" ON public.system_backups;
CREATE POLICY "Admin all system_backups" ON public.system_backups
  FOR ALL USING (public.platform_is_admin()) WITH CHECK (public.platform_is_admin());
CREATE INDEX IF NOT EXISTS idx_system_backups_created ON public.system_backups(created_at DESC);

-- Urutan tabel yang aman untuk restore (tabel induk sebelum anak, berdasarkan FK).
-- Mengecualikan `system_backups` (diri sendiri) dan `web_cache` (cache sementara).
CREATE OR REPLACE FUNCTION public._system_backup_table_order()
RETURNS text[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  remaining text[];
  ordered text[] := '{}';
  ready text[];
  t text;
  s int := 0;
BEGIN
  SELECT array_agg(c.relname ORDER BY c.relname)
  INTO remaining
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND c.relname <> ALL(ARRAY['system_backups', 'web_cache']);

  WHILE COALESCE(array_length(remaining, 1), 0) > 0 AND s < 1000 LOOP
    s := s + 1;
    ready := '{}';
    FOREACH t IN ARRAY remaining LOOP
      IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint fk
        JOIN pg_class child ON child.oid = fk.conrelid
        JOIN pg_class parent ON parent.oid = fk.confrelid
        WHERE fk.contype = 'f'
          AND child.relname = t
          AND parent.relname <> t
          AND parent.relname = ANY(remaining)
      ) THEN
        ready := array_append(ready, t);
      END IF;
    END LOOP;
    IF COALESCE(array_length(ready, 1), 0) = 0 THEN
      -- Siklus pertahanan: buang sisa tanpa order.
      ready := remaining;
    END IF;
    ordered := ordered || ready;
    remaining := ARRAY(
      SELECT x FROM unnest(remaining) x WHERE NOT x = ANY(ready)
    );
  END LOOP;

  RETURN ordered;
END;
$$;

-- Buat full-system snapshot (semua tabel public).
CREATE OR REPLACE FUNCTION public.platform_system_backup_create(
  p_kind text DEFAULT 'full')
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_order text[];
  t text;
  v_arr jsonb;
  v_data jsonb := '{}'::jsonb;
  v_rows int := 0;
  v_id uuid;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_order := public._system_backup_table_order();
  FOREACH t IN ARRAY v_order LOOP
    BEGIN
      EXECUTE format(
        'SELECT COALESCE(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) FROM public.%I x', t)
      INTO v_arr;
      v_data := jsonb_set(v_data, ARRAY[t], v_arr, true);
      v_rows := v_rows + jsonb_array_length(v_arr);
    EXCEPTION WHEN OTHERS THEN
      v_data := jsonb_set(v_data, ARRAY[t], jsonb_build_array(
        jsonb_build_object('__backup_error__', SQLERRM)), true);
    END;
  END LOOP;

  INSERT INTO public.system_backups
    (kind, status, table_count, row_count, size_bytes, data, created_by)
  VALUES ('full', 'success', array_length(v_order, 1), v_rows,
          length(v_data::text), v_data, auth.uid())
  RETURNING id INTO v_id;

  PERFORM public.log_admin_action('system_backup_create', v_id::text,
    jsonb_build_object('tables', array_length(v_order, 1), 'rows', v_rows));

  RETURN jsonb_build_object('id', v_id, 'table_count', array_length(v_order, 1),
    'row_count', v_rows, 'size_bytes', length(v_data::text), 'created_at', NOW());
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_system_backup_create(text) TO authenticated;

-- Daftar full-system backup (TANPA payload).
CREATE OR REPLACE FUNCTION public.platform_system_backup_list()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN jsonb_build_object(
    'rows', COALESCE((
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
      FROM (SELECT b.id, b.kind, b.status, b.table_count, b.row_count,
                   b.size_bytes, b.created_at,
                   COALESCE(u.email, '(sistem)') AS created_by_email
            FROM public.system_backups b
            LEFT JOIN auth.users u ON u.id = b.created_by
            ORDER BY b.created_at DESC LIMIT 50) x), '[]'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_system_backup_list() TO authenticated;

-- Ambil payload full-snapshot (untuk unduh JSON) + audit.
CREATE OR REPLACE FUNCTION public.platform_system_backup_get(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_data jsonb;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT data INTO v_data FROM public.system_backups WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'backup_not_found'; END IF;

  PERFORM public.log_admin_action('system_backup_download', p_id::text, '{}');

  RETURN v_data;
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_system_backup_get(uuid) TO authenticated;

-- Pulihkan full-system: isi baris yang HILANG saja (id/unique sama = dilewati).
-- FK + trigger dinonaktifkan sementara via session_replication_role=replica
-- (teknik pg_dump) agar siklus FK (mis. transactions <-> orders) tidak gagal.
CREATE OR REPLACE FUNCTION public.platform_system_backup_restore(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_data jsonb;
  v_order text[];
  t text;
  v_count int;
  v_total int := 0;
  v_results jsonb := '[]'::jsonb;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT data INTO v_data FROM public.system_backups WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'backup_not_found'; END IF;
  IF v_data IS NULL OR jsonb_typeof(v_data) <> 'object' THEN
    RAISE EXCEPTION 'backup_empty';
  END IF;

  v_order := public._system_backup_table_order();

  -- Hanya isi baris yang hilang; ON CONFLICT DO NOTHING (id/unique sama dilewati).
  SET LOCAL session_replication_role = replica;

  FOREACH t IN ARRAY v_order LOOP
    CONTINUE WHEN v_data ? t IS FALSE;
    CONTINUE WHEN jsonb_typeof(v_data -> t) <> 'array';

    BEGIN
      EXECUTE format(
        'INSERT INTO public.%I SELECT y.* FROM jsonb_array_elements($1) AS e, jsonb_populate_record(NULL::public.%I, e) AS y ON CONFLICT DO NOTHING',
        t, t) USING (v_data -> t);

      GET DIAGNOSTICS v_count = ROW_COUNT;
      v_total := v_total + v_count;
      IF v_count > 0 THEN
        v_results := v_results || jsonb_build_object('table', t, 'inserted', v_count);
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_results := v_results || jsonb_build_object('table', t, 'error', SQLERRM);
    END;
  END LOOP;

  SET LOCAL session_replication_role = origin;

  UPDATE public.system_backups SET status = 'restored' WHERE id = p_id;

  PERFORM public.log_admin_action('system_backup_restore', p_id::text,
    jsonb_build_object('rows', v_total));

  RETURN jsonb_build_object('restored', v_total, 'tables', v_results);
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_system_backup_restore(uuid) TO authenticated;

-- Hapus full-system backup.
CREATE OR REPLACE FUNCTION public.platform_system_backup_delete(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;
  DELETE FROM public.system_backups WHERE id = p_id;
  PERFORM public.log_admin_action('system_backup_delete', p_id::text, '{}');
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_system_backup_delete(uuid) TO authenticated;