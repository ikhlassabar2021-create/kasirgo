-- ============================================================================
-- KASIRGO: FULL SYSTEM BACKUP — tambahkan AUTH (akun login) ke snapshot.
-- Sebelumnya snapshot hanya skema `public`. Kini ikut menyertakan:
--   auth.users      = akun login (email + encrypted_password + metadata)
--   auth.identities = identitas login (wajib agar password login tetap bisa)
-- sehingga create/restore mendekati "Duplicator" penuh (database lengkap).
-- Sensitif: encrypted_password tersimpan; akses tetap superadmin-only
-- (platform_is_admin), setara dengan selfhost/scripts/dump-database.sh.
-- Restore tetap hanya isi baris yang HILANG (id/unique sama = dilewati).
-- Kolom GENERATED (auth.users.confirmed_at, auth.identities.email) TIDAK
-- di-insert (tidak boleh diisi manual) — ditangani helper _system_backup_cols.
-- Idempotent: aman dijalankan ulang.
-- ============================================================================

-- Daftar kolom non-generated untuk sebuah tabel (buat INSERT restore yang aman).
CREATE OR REPLACE FUNCTION public._system_backup_cols(p_schema text, p_table text)
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT array_agg(column_name ORDER BY ordinal_position)
  FROM information_schema.columns
  WHERE table_schema = p_schema
    AND table_name = p_table
    AND is_generated = 'NEVER';
$$;

-- Buat full-system snapshot (semua tabel public + auth users/identities).
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
  v_tables int := 0;
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
  v_tables := array_length(v_order, 1);

  -- Akun login (auth.users).
  BEGIN
    EXECUTE 'SELECT COALESCE(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) FROM auth.users x'
      INTO v_arr;
    v_data := jsonb_set(v_data, ARRAY['auth__users'], v_arr, true);
    v_rows := v_rows + jsonb_array_length(v_arr);
    v_tables := v_tables + 1;
  EXCEPTION WHEN OTHERS THEN
    v_data := jsonb_set(v_data, ARRAY['auth__users'], jsonb_build_array(
      jsonb_build_object('__backup_error__', SQLERRM)), true);
  END;

  -- Identitas login (auth.identities).
  BEGIN
    EXECUTE 'SELECT COALESCE(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) FROM auth.identities x'
      INTO v_arr;
    v_data := jsonb_set(v_data, ARRAY['auth__identities'], v_arr, true);
    v_rows := v_rows + jsonb_array_length(v_arr);
    v_tables := v_tables + 1;
  EXCEPTION WHEN OTHERS THEN
    v_data := jsonb_set(v_data, ARRAY['auth__identities'], jsonb_build_array(
      jsonb_build_object('__backup_error__', SQLERRM)), true);
  END;

  INSERT INTO public.system_backups
    (kind, status, table_count, row_count, size_bytes, data, created_by)
  VALUES ('full', 'success', v_tables, v_rows,
          length(v_data::text), v_data, auth.uid())
  RETURNING id INTO v_id;

  PERFORM public.log_admin_action('system_backup_create', v_id::text,
    jsonb_build_object('tables', v_tables, 'rows', v_rows));

  RETURN jsonb_build_object('id', v_id, 'table_count', v_tables,
    'row_count', v_rows, 'size_bytes', length(v_data::text), 'created_at', NOW());
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_system_backup_create(text) TO authenticated;

-- Pulihkan full-system (public + auth): isi baris yang HILANG saja.
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
  v_cols text[];
  v_collist text := '';
  v_sellist text := '';
  i int;
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
  -- session_replication_role=replica menonaktifkan trigger (mis. handle_new_user)
  -- dan FK agar urutan + siklus tidak gagal.
  SET LOCAL session_replication_role = replica;

  -- Akun login (auth.users) dipulihkan lebih dulu; kolom generated dilewati.
  IF v_data ? 'auth__users' AND jsonb_typeof(v_data -> 'auth__users') = 'array' THEN
    BEGIN
      v_cols := public._system_backup_cols('auth', 'users');
      v_collist := '';
      v_sellist := '';
      FOR i IN 1..array_length(v_cols, 1) LOOP
        v_collist := v_collist || quote_ident(v_cols[i]);
        v_sellist := v_sellist || 'y.' || quote_ident(v_cols[i]);
        IF i < array_length(v_cols, 1) THEN
          v_collist := v_collist || ', ';
          v_sellist := v_sellist || ', ';
        END IF;
      END LOOP;
      EXECUTE format(
        'INSERT INTO auth.users (%s) SELECT %s FROM jsonb_array_elements($1) AS e, jsonb_populate_record(NULL::auth.users, e) AS y ON CONFLICT DO NOTHING',
        v_collist, v_sellist) USING (v_data -> 'auth__users');
      GET DIAGNOSTICS v_count = ROW_COUNT;
      v_total := v_total + v_count;
      IF v_count > 0 THEN
        v_results := v_results || jsonb_build_object('table', 'auth.users', 'inserted', v_count);
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_results := v_results || jsonb_build_object('table', 'auth.users', 'error', SQLERRM);
    END;
  END IF;

  -- Identitas login (auth.identities).
  IF v_data ? 'auth__identities' AND jsonb_typeof(v_data -> 'auth__identities') = 'array' THEN
    BEGIN
      v_cols := public._system_backup_cols('auth', 'identities');
      v_collist := '';
      v_sellist := '';
      FOR i IN 1..array_length(v_cols, 1) LOOP
        v_collist := v_collist || quote_ident(v_cols[i]);
        v_sellist := v_sellist || 'y.' || quote_ident(v_cols[i]);
        IF i < array_length(v_cols, 1) THEN
          v_collist := v_collist || ', ';
          v_sellist := v_sellist || ', ';
        END IF;
      END LOOP;
      EXECUTE format(
        'INSERT INTO auth.identities (%s) SELECT %s FROM jsonb_array_elements($1) AS e, jsonb_populate_record(NULL::auth.identities, e) AS y ON CONFLICT DO NOTHING',
        v_collist, v_sellist) USING (v_data -> 'auth__identities');
      GET DIAGNOSTICS v_count = ROW_COUNT;
      v_total := v_total + v_count;
      IF v_count > 0 THEN
        v_results := v_results || jsonb_build_object('table', 'auth.identities', 'inserted', v_count);
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_results := v_results || jsonb_build_object('table', 'auth.identities', 'error', SQLERRM);
    END;
  END IF;

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