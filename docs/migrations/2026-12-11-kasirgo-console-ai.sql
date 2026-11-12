-- =============================================================================
-- 2026-12-11-kasirgo-console-ai.sql
--
-- Console AI superadmin: chat dengan LLM (membaca system_api_configs + Vault)
-- untuk memeriksa/memperbaiki/mengembangkan sistem. Aman berulang (idempotent).
--
-- Objek:
--   1) console_ai_sessions  — percakapan (judul + aktor).
--   2) console_ai_messages  — pesan chat (role user/assistant/tool).
--   3) console_ai_run_sql() — RPC SECURITY DEFINER (admin-gated) untuk eksekusi
--      single-statement SQL. Mode 'read' hanya SELECT/SHOW/EXPLAIN/WITH; mode
--      'write' membolehkan DML/DDL dan ditulis jejak ke audit_logs.
-- =============================================================================

\set ON_ERROR_STOP on
BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Tabel sesi & pesan Console AI
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.console_ai_sessions (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id   uuid,
  title      text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.console_ai_messages (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.console_ai_sessions(id) ON DELETE CASCADE,
  role       text NOT NULL,
  content    text,
  tool_calls jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_console_ai_messages_session
  ON public.console_ai_messages (session_id, created_at);
CREATE INDEX IF NOT EXISTS idx_console_ai_sessions_actor
  ON public.console_ai_sessions (actor_id, updated_at DESC);

-- RLS: hanya superadmin platform yang boleh membaca/menulis riwayat console.
ALTER TABLE public.console_ai_sessions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.console_ai_messages  ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  DROP POLICY IF EXISTS "console sessions superadmin" ON public.console_ai_sessions;
  CREATE POLICY "console sessions superadmin" ON public.console_ai_sessions
    FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

  DROP POLICY IF EXISTS "console messages superadmin" ON public.console_ai_messages;
  CREATE POLICY "console messages superadmin" ON public.console_ai_messages
    FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());
END $$;

-- -----------------------------------------------------------------------------
-- 2. RPC eksekusi SQL (admin-gated, single statement)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.console_ai_run_sql(
  p_sql  text,
  p_mode text DEFAULT 'read'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sql      text := btrim(COALESCE(p_sql, ''));
  v_mode     text := lower(btrim(COALESCE(p_mode, 'read')));
  v_lower    text := lower(v_sql);
  v_stmts    text[];
  v_rows     jsonb;
  v_n        int;
  v_affected int := 0;
BEGIN
  IF NOT public.is_platform_admin() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'forbidden', 'detail', 'Hanya superadmin platform.');
  END IF;

  IF v_sql = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'empty', 'detail', 'SQL kosong.');
  END IF;

  IF v_mode NOT IN ('read', 'write') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_mode', 'detail', 'mode harus read/write.');
  END IF;

  -- Satu pernyataan saja; pecah per ';' (aproksimasi aman untuk console admin).
  v_stmts := ARRAY(
    SELECT btrim(s) FROM unnest(regexp_split_to_array(v_sql, ';')) AS s
    WHERE btrim(s) <> ''
  );
  IF coalesce(array_length(v_stmts, 1), 0) > 1 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'multi_statement',
      'detail', 'Kirim satu pernyataan per langkah agar aman ditinjau.');
  END IF;
  v_sql := v_stmts[1];
  v_lower := lower(v_sql);

  -- Kata kunci yang DILARANG mutlak (proteksi sistem & Vault).
  IF v_lower ~ '\y(drop\s+database|drop\s+schema|drop\s+role|create\s+role|alter\s+role|drop\s+owned|reassign\s+owned|truncate|vacuum\s+full|pg_reload_conf|pg_terminate_backend|cancel_backend|lo_unlink|dblink|postgres_fdw|copy)\y' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'forbidden',
      'detail', 'Pernyataan ini diblokir untuk keselamatan sistem.');
  END IF;

  -- Mode read: hanya operasi baca.
  IF v_mode = 'read' THEN
    IF v_lower !~ '^(select|show|explain|with)\y' THEN
      RETURN jsonb_build_object('ok', false, 'error', 'write_not_allowed',
        'detail', 'Mode read hanya mengizinkan SELECT/SHOW/EXPLAIN/WITH. Aktifkan mode tulis bila ingin mengubah data.');
    END IF;
    -- CTE tulis (WITH ... INSERT/UPDATE/DELETE) juga ditolak.
    IF v_lower ~ '\y(insert\s+into|update\s+\w|delete\s+from|merge\s+into|alter\s+table|drop\s+table|create\s+table)\y' THEN
      RETURN jsonb_build_object('ok', false, 'error', 'write_not_allowed',
        'detail', 'CTE tulis tidak diizinkan dalam mode read.');
    END IF;
  END IF;

  -- Jalankan. Untuk SELECT/SHOW/EXPLAIN/WITH kembalikan baris (batas 200).
  IF v_lower ~ '^(select|show|explain|with)\y' THEN
    -- Ambil baris secara generik lewat json_agg.
    BEGIN
      EXECUTE format(
        'SELECT coalesce(jsonb_agg(t), ''[]''::jsonb) FROM (%s) AS t', v_sql)
      INTO v_rows;
    EXCEPTION WHEN OTHERS THEN
      -- Beberapa pernyataan tidak bisa dibungkus; coba eksekusi langsung + row count.
      EXECUTE v_sql;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      RETURN jsonb_build_object('ok', true, 'kind', 'count', 'row_count', v_n);
    END;
    -- Sensor: potong bila terlalu besar.
    IF jsonb_array_length(v_rows) > 200 THEN
      v_rows := jsonb_build_object('truncated', true, 'rows', (
        SELECT jsonb_agg(r) FROM (SELECT * FROM jsonb_array_elements(v_rows) AS r LIMIT 200) q
      ));
    END IF;
    RETURN jsonb_build_object('ok', true, 'kind', 'rows',
      'row_count', jsonb_array_length(v_rows), 'rows', v_rows);
  ELSE
    -- DML/DDL (hanya mode write).
    BEGIN
      EXECUTE v_sql;
      GET DIAGNOSTICS v_affected = ROW_COUNT;
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('ok', false, 'error', 'sql_error',
        'detail', SQLERRM, 'hint', SQLSTATE);
    END;

    -- Jejak audit untuk semua operasi tulis.
    PERFORM public.log_admin_action('console_ai.run_sql', 'console_ai',
      jsonb_build_object('mode', v_mode, 'sql', left(v_sql, 800), 'affected', v_affected));

    RETURN jsonb_build_object('ok', true, 'kind', 'exec', 'affected', v_affected);
  END IF;
END $$;

GRANT EXECUTE ON FUNCTION public.console_ai_run_sql(text, text) TO authenticated;

-- -----------------------------------------------------------------------------
-- 3. RPC daftar tabel (service_role via Edge Function list_tables)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.console_ai_list_tables()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_agg(t)
  FROM (
    SELECT table_name, obj_description((quote_ident(table_schema) || '.' || quote_ident(table_name))::regclass, 'pg_class') AS description
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE'
    ORDER BY table_name
  ) AS t;
$$;
GRANT EXECUTE ON FUNCTION public.console_ai_list_tables() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.console_ai_list_tables() FROM anon, authenticated;

COMMIT;

-- =============================================================================
-- VERIFIKASI:
--   SELECT public.console_ai_run_sql('select count(*) from public.outlets', 'read');
--   SELECT public.console_ai_run_sql('select * from public.admin_users limit 5', 'read');
-- =============================================================================