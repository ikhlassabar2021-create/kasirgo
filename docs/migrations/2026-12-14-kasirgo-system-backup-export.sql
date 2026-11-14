-- ============================================================================
-- KASIRGO: Full-system backup -> export SQL (Duplicator-style, selalu aktual).
-- Menghasilkan 3 bagian SQL yang bisa direstore ke PostgreSQL/Supabase lain:
--   p_part='schema'  : DDL (extensions, roles, auth shim, tables, index,
--                      constraint, sequence, function, view, trigger, RLS, grants)
--   p_part='data'    : INSERT semua tabel public dari snapshot (dollar-quoted jsonb)
--   p_part='auth'    : INSERT auth.users + auth.identities (kolom non-generated)
-- Data diambil LANGSUNG dari katalog & baris live (bukan file statis yang basi),
-- lalu disimpan di payload fungsi `platform_system_backup_export_sql`.
-- Target restore: Supabase project baru (auth/RLS/realtime) ATAU PostgreSQL polos
-- (auth shim + role dibuat otomatis). Idempotent.
-- ============================================================================

-- Kolom non-generated (dipakai buat INSERT auth yang punya kolom generated).
CREATE OR REPLACE FUNCTION public._sb_cols(p_schema text, p_table text)
RETURNS text[]
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $fn$
  SELECT array_agg(column_name ORDER BY ordinal_position)
  FROM information_schema.columns
  WHERE table_schema = p_schema AND table_name = p_table
    AND is_generated = 'NEVER';
$fn$;

-- ============================================================================
-- BAGIAN 1: DDL schema (extensions, roles, shim auth, tabel, dll)
-- ============================================================================
CREATE OR REPLACE FUNCTION public._sb_schema_sql()
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  s text := '';
  r record;
  tbl record;
  cols text[];
  col record;
  defs text;
  dbname text;
  has_gen boolean;
BEGIN
  s := s || '-- KasirGo full-system schema export (generated live)' || E'\n';
  s := s || 'SET statement_timeout = 0;' || E'\n';

  -- Roles (untuk PostgreSQL polos; Supabase sudah punya).
  s := s || E'\n' ||
    'DO $$ BEGIN' || E'\n' ||
    '  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = ''anon'') THEN CREATE ROLE anon NOLOGIN; END IF;' || E'\n' ||
    '  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = ''authenticated'') THEN CREATE ROLE authenticated NOLOGIN; END IF;' || E'\n' ||
    '  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = ''service_role'') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF;' || E'\n' ||
    '  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = ''authenticator'') THEN CREATE ROLE authenticator NOINHERIT LOGIN; END IF;' || E'\n' ||
    'END $$;' || E'\n';

  s := s || E'\n' ||
    'CREATE SCHEMA IF NOT EXISTS extensions;' || E'\n' ||
    'CREATE SCHEMA IF NOT EXISTS auth;' || E'\n' ||
    'CREATE SCHEMA IF NOT EXISTS vault;' || E'\n' ||
    'CREATE SCHEMA IF NOT EXISTS storage;' || E'\n';

  -- Extensions (guard bila tak tersedia di hosting).
  s := s || E'\nDO $$ BEGIN' || E'\n' ||
    '  CREATE EXTENSION IF NOT EXISTS pgcrypto;' || E'\n' ||
    'EXCEPTION WHEN OTHERS THEN NULL; END $$;' || E'\n' ||
    E'\nDO $$ BEGIN' || E'\n' ||
    '  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";' || E'\n' ||
    'EXCEPTION WHEN OTHERS THEN NULL; END $$;' || E'\n' ||
    E'\nDO $$ BEGIN' || E'\n' ||
    '  CREATE EXTENSION IF NOT EXISTS postgis;' || E'\n' ||
    'EXCEPTION WHEN OTHERS THEN NULL; END $$;' || E'\n';

  -- auth shim (hanya bila auth.uid() belum ada -> PostgreSQL polos).
  s := s || E'\nDO $$ BEGIN' || E'\n' ||
    '  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname=''auth'' AND p.proname=''uid'') THEN' || E'\n' ||
    '    EXECUTE $f$CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS ''SELECT nullif(current_setting(''\\''request.jwt.claim.sub''\\'', true), ''''''\\'''''''' )::uuid''$f$;' || E'\n' ||
    '  END IF;' || E'\n' ||
    '  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname=''auth'' AND p.proname=''role'') THEN' || E'\n' ||
    '    EXECUTE $f$CREATE OR REPLACE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS ''SELECT coalesce(nullif(current_setting(''\\''request.jwt.claim.role''\\'', true), ''''''), ''''anon'''')''$f$;' || E'\n' ||
    '  END IF;' || E'\n' ||
    'END $$;' || E'\n';

  -- Sequences di public.
  FOR r IN
    SELECT sequencename, start_value, increment_by, min_value, max_value
    FROM pg_sequences WHERE schemaname = 'public'
  LOOP
    s := s || format('CREATE SEQUENCE IF NOT EXISTS public.%I START WITH %s INCREMENT BY %s MINVALUE %s MAXVALUE %s;%s',
      r.sequencename, r.start_value, r.increment_by, r.min_value, r.max_value, E'\n');
  END LOOP;

  -- Tabel (public + auth.users/identities) beserta kolom.
  FOR tbl IN
    SELECT 'public' AS sch, c.relname AS tbl
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r'
    UNION ALL
    SELECT 'auth', 'users'
    UNION ALL
    SELECT 'auth', 'identities'
    ORDER BY 1, 2
  LOOP
    defs := '';
    FOR col IN
      SELECT a.attname,
             pg_catalog.format_type(a.atttypid, a.atttypmod) AS typ,
             a.attnotnull,
             a.atthasdef,
             a.attidentity,
             a.attgenerated,
             pg_catalog.pg_get_expr(d.adbin, d.adrelid) AS def,
             a.attnum
      FROM pg_attribute a
      JOIN pg_class c ON c.oid = a.attrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
      WHERE n.nspname = tbl.sch AND c.relname = tbl.tbl
        AND a.attnum > 0 AND NOT a.attisdropped
      ORDER BY a.attnum
    LOOP
      defs := defs || E'    ' || quote_ident(col.attname) || ' ' || col.typ;
      IF col.attgenerated <> '' THEN
        defs := defs || ' GENERATED ALWAYS AS (' || col.def || ') STORED';
      ELSIF col.attidentity <> '' THEN
        defs := defs || ' GENERATED ' || CASE col.attidentity WHEN 'a' THEN 'ALWAYS' ELSE 'BY DEFAULT' END || ' AS IDENTITY';
      ELSIF col.atthasdef THEN
        defs := defs || ' DEFAULT ' || col.def;
      END IF;
      IF col.attnotnull THEN defs := defs || ' NOT NULL'; END IF;
      defs := defs || E',\n';
    END LOOP;
    defs := rtrim(defs, E',\n');
    s := s || E'\nCREATE TABLE IF NOT EXISTS ' || quote_ident(tbl.sch) || '.' || quote_ident(tbl.tbl) ||
         ' (' || E'\n' || defs || E'\n);' || E'\n';
  END LOOP;

  -- Constraint PK/UNIQUE/CHECK dulu (FK menyusul).
  FOR r IN
    SELECT pn.nspname AS sch, pc.relname AS tbl, con.conname,
           pg_catalog.pg_get_constraintdef(con.oid) AS def, con.contype
    FROM pg_constraint con
    JOIN pg_class pc ON pc.oid = con.conrelid
    JOIN pg_namespace pn ON pn.oid = pc.relnamespace
    WHERE pn.nspname = 'public' AND con.contype IN ('p','u','c')
    ORDER BY con.contype, pc.relname, con.conname
  LOOP
    s := s || format('ALTER TABLE ONLY %I.%I ADD CONSTRAINT %I %s;%s',
      r.sch, r.tbl, r.conname, r.def, E'\n');
  END LOOP;

  -- FK (setelah semua tabel).
  FOR r IN
    SELECT pn.nspname AS sch, pc.relname AS tbl, con.conname,
           pg_catalog.pg_get_constraintdef(con.oid) AS def
    FROM pg_constraint con
    JOIN pg_class pc ON pc.oid = con.conrelid
    JOIN pg_namespace pn ON pn.oid = pc.relnamespace
    WHERE pn.nspname = 'public' AND con.contype = 'f'
    ORDER BY pc.relname, con.conname
  LOOP
    s := s || format('ALTER TABLE ONLY %I.%I ADD CONSTRAINT %I %s;%s',
      r.sch, r.tbl, r.conname, r.def, E'\n');
  END LOOP;

  -- Index (non-constraint).
  FOR r IN
    SELECT schemaname, indexname, indexdef
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname NOT LIKE '%_pkey'
      AND NOT EXISTS (
        SELECT 1 FROM pg_constraint c WHERE c.conname = pg_indexes.indexname
      )
    ORDER BY tablename, indexname
  LOOP
    s := s || r.indexdef || ';' || E'\n';
  END LOOP;

  -- Functions.
  s := s || E'\nSET check_function_bodies = false;' || E'\n';
  FOR r IN
    SELECT pg_catalog.pg_get_functiondef(p.oid) AS def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prokind = 'f'
    ORDER BY p.proname
  LOOP
    s := s || r.def || E'\n';
  END LOOP;

  -- Views.
  FOR r IN
    SELECT schemaname, viewname, definition
    FROM pg_views WHERE schemaname = 'public' ORDER BY viewname
  LOOP
    s := s || format('CREATE OR REPLACE VIEW %I.%I AS %s;%s',
      r.schemaname, r.viewname, r.definition, E'\n');
  END LOOP;

  -- RLS + policies.
  FOR r IN
    SELECT c.relname, c.relrowsecurity
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind='r' AND c.relrowsecurity
    ORDER BY c.relname
  LOOP
    s := s || format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;%s', r.relname, E'\n');
  END LOOP;

  FOR r IN
    SELECT tablename, policyname, permissive, roles, cmd, qual, with_check
    FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename, policyname
  LOOP
    s := s || format('CREATE POLICY %I ON public.%I AS %s FOR %s TO %s%s%s;%s',
      r.policyname, r.tablename, r.permissive, r.cmd,
      array_to_string(r.roles, ', '),
      CASE WHEN r.qual IS NOT NULL THEN ' USING (' || r.qual || ')' ELSE '' END,
      CASE WHEN r.with_check IS NOT NULL THEN ' WITH CHECK (' || r.with_check || ')' ELSE '' END,
      E'\n');
  END LOOP;

  -- Triggers.
  FOR r IN
    SELECT pg_catalog.pg_get_triggerdef(t.oid) AS def
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND NOT t.tgisinternal
    ORDER BY c.relname, t.tgname
  LOOP
    s := s || r.def || ';' || E'\n';
  END LOOP;

  -- Grants (tabel, fungsi, sequence) + NO RLS bypass hazard.
  s := s || E'\nGRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;' || E'\n';
  s := s || 'GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;' || E'\n';
  s := s || 'GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;' || E'\n';
  s := s || 'GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, service_role;' || E'\n';
  s := s || 'GRANT ALL ON SCHEMA auth TO anon, authenticated, service_role;' || E'\n';

  -- Grants kolom sensitif: buat ulang dari column_privileges (anon & authenticated).
  FOR r IN
    SELECT table_name, grantee, column_name, privilege_type
    FROM information_schema.column_privileges
    WHERE table_schema = 'public' AND grantee IN ('anon','authenticated')
    ORDER BY table_name, grantee, column_name, privilege_type
  LOOP
    s := s || format('GRANT %I (%I) ON TABLE public.%I TO %I;%s',
      r.privilege_type, r.column_name, r.table_name, r.grantee, E'\n');
  END LOOP;

  RETURN s;
END;
$fn$;

-- ============================================================================
-- BAGIAN 2 & 3: render data jadi SQL (dollar-quoted jsonb, aman dari quote)
-- ============================================================================
CREATE OR REPLACE FUNCTION public._sb_render_rows(
  p_sch text, p_tbl text, p_json jsonb, p_order text[], p_cols text[], p_explicit boolean)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  tag text;
  n int := 1;
  cols text[];
  clist text;
  sellist text;
  j text;
  out_sql text := '';
  t text;
BEGIN
  IF p_json IS NULL OR jsonb_typeof(p_json) <> 'array' OR jsonb_array_length(p_json) = 0 THEN
    RETURN '';
  END IF;
  -- pilih tag dollar yang tidak ada di payload
  LOOP
    tag := '$' || 'kgo' || n || '$';
    EXIT WHEN position(tag in p_json::text) = 0;
    n := n + 1;
  END LOOP;

  -- mode: semua tabel public memakai SELECT * (tanpa kolom generated di public),
  -- auth memakai explicit kolom (lewati generated).
  IF p_explicit THEN
    cols := p_cols;
  ELSE
    SELECT array_agg(column_name ORDER BY ordinal_position)
      INTO cols FROM information_schema.columns
      WHERE table_schema = p_sch AND table_name = p_tbl AND is_generated = 'NEVER';
    IF cols IS NULL OR array_length(cols,1) IS NULL THEN RETURN ''; END IF;
    -- beri SELECT * bila tidak ada perbedaan (public, lebih cepat & aman)
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = p_sch AND table_name = p_tbl AND is_generated <> 'NEVER'
    ) THEN
      RETURN format(
        'INSERT INTO %I.%I SELECT * FROM jsonb_populate_recordset(NULL::%I.%I, %s::jsonb) ON CONFLICT DO NOTHING;',
        p_sch, p_tbl, p_sch, p_tbl, tag || p_json::text || tag);
    END IF;
  END IF;

  clist := (SELECT string_agg(quote_ident(c), ', ') FROM unnest(cols) c);
  sellist := (SELECT string_agg('y.' || quote_ident(c), ', ') FROM unnest(cols) c);
  RETURN format(
    'INSERT INTO %I.%I (%s) SELECT %s FROM jsonb_populate_recordset(NULL::%I.%I, %s::jsonb) AS y ON CONFLICT DO NOTHING;',
    p_sch, p_tbl, clist, sellist, p_sch, p_tbl, tag || p_json::text || tag);
END;
$fn$;

-- Data public (semua tabel, urutan FK-friendly), lalu set nilai sequence.
CREATE OR REPLACE FUNCTION public._sb_data_sql(p_data jsonb)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  s text := '';
  t text;
  r record;
BEGIN
  s := '-- KasirGo data export (public), generated live' || E'\n';
  s := s || 'SET session_replication_role = replica;' || E'\n';
  FOREACH t IN ARRAY public._system_backup_table_order() LOOP
    IF t = 'system_backups' OR t = 'web_cache' THEN CONTINUE; END IF;
    IF p_data ? t THEN
      s := s || public._sb_render_rows('public', t, p_data -> t, NULL, NULL, false) || E'\n';
    END IF;
  END LOOP;
  s := s || 'SET session_replication_role = origin;' || E'\n';

  -- set sequence order_code_seq (bila ada) agar tidak bentrok.
  FOR r IN
    SELECT sequencename, last_value
    FROM pg_sequences WHERE schemaname = 'public' AND last_value IS NOT NULL
  LOOP
    s := s || format('SELECT setval(''public.%I'', %s, true);%s', r.sequencename, r.last_value, E'\n');
  END LOOP;

  RETURN s;
END;
$fn$;

-- Data auth (users + identities) dengan kolom non-generated eksplisit.
CREATE OR REPLACE FUNCTION public._sb_auth_sql(p_data jsonb)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  s text := '';
  cols text[];
BEGIN
  s := '-- KasirGo auth data export (users + identities), generated live' || E'\n';
  s := s || 'SET session_replication_role = replica;' || E'\n';

  cols := public._sb_cols('auth', 'users');
  IF p_data ? 'auth__users' AND jsonb_array_length(p_data -> 'auth__users') > 0 THEN
    s := s || public._sb_render_rows('auth', 'users', p_data -> 'auth__users', NULL, cols, true) || E'\n';
  END IF;

  cols := public._sb_cols('auth', 'identities');
  IF p_data ? 'auth__identities' AND jsonb_array_length(p_data -> 'auth__identities') > 0 THEN
    s := s || public._sb_render_rows('auth', 'identities', p_data -> 'auth__identities', NULL, cols, true) || E'\n';
  END IF;

  s := s || 'SET session_replication_role = origin;' || E'\n';
  RETURN s;
END;
$fn$;

-- ============================================================================
-- RPC utama (superadmin-only): hasil snapshot + export SQL 3 bagian.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.platform_system_backup_export_sql(p_kind text DEFAULT 'full')
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  v_ok boolean;
  v_id uuid;
  v_data jsonb;
  v_order text[];
  v_rows int := 0;
  v_tables int := 0;
  v_arr jsonb;
  t text;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  -- Snapshot data (sama seperti create), tanpa menyimpan baris system_backups.
  v_order := public._system_backup_table_order();
  v_data := '{}'::jsonb;
  FOREACH t IN ARRAY v_order LOOP
    IF t = 'system_backups' OR t = 'web_cache' THEN CONTINUE; END IF;
    BEGIN
      EXECUTE format('SELECT COALESCE(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) FROM public.%I x', t) INTO v_arr;
      v_data := jsonb_set(v_data, ARRAY[t], v_arr, true);
      v_rows := v_rows + jsonb_array_length(v_arr);
      v_tables := v_tables + 1;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;

  -- auth
  BEGIN
    EXECUTE 'SELECT COALESCE(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) FROM auth.users x' INTO v_arr;
    v_data := jsonb_set(v_data, ARRAY['auth__users'], v_arr, true);
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    EXECUTE 'SELECT COALESCE(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) FROM auth.identities x' INTO v_arr;
    v_data := jsonb_set(v_data, ARRAY['auth__identities'], v_arr, true);
  EXCEPTION WHEN OTHERS THEN NULL; END;

  PERFORM public.log_admin_action('system_backup_export_sql', p_kind,
    jsonb_build_object('tables', v_tables, 'rows', v_rows));

  RETURN jsonb_build_object(
    'schema', public._sb_schema_sql(),
    'data', public._sb_data_sql(v_data),
    'auth', public._sb_auth_sql(v_data),
    'rows', v_rows,
    'tables', v_tables,
    'created_at', NOW());
END;
$fn$;
GRANT EXECUTE ON FUNCTION public.platform_system_backup_export_sql(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.platform_system_backup_export_sql(text) TO anon;