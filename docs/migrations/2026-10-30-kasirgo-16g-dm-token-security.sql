-- ============================================================================
-- KASIRGO PHASE 16G - HARDENING TOKEN KANAL DM (enkripsi at-rest) + PRUNE OAUTH
-- ============================================================================
-- Tujuan: menutup celah hardening alur OAuth/koneksi kanal Squad DM.
--   1. dm_channel_accounts.token_enc disimpan TERENKRIPSI (pgcrypto) dengan
--      kunci acak 32-byte yang HANYA ada di Supabase Vault. Kunci tidak pernah
--      masuk kode/klien. Dekripsi hanya lewat fungsi service_role.
--   2. Backfill baris lama (plaintext) -> terenkripsi, idempoten (prefix 'v1:').
--   3. Index + helper prune dm_oauth_states (anti-CSRF) agar tidak menumpuk.
-- Keamanan:
--   - dm_encrypt_token / dm_decrypt_token / dm_token_key: SECURITY DEFINER,
--     EXECUTE hanya service_role (klien & anon TIDAK bisa memanggil).
--   - dm_channel_accounts tetap tanpa policy baca owner (token tak pernah ke klien).
-- Idempoten (aman dijalankan berulang).
-- ============================================================================

\set ON_ERROR_STOP on
BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Kunci enkripsi token kanal (Vault, dibuat sekali)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'dm_channel_token_key') THEN
    PERFORM vault.create_secret(
      encode(gen_random_bytes(32), 'hex'),
      'dm_channel_token_key',
      'KasirGo DM channel account token encryption key'
    );
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 2. Helper kunci (service_role only)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dm_token_key()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'vault'
AS $function$
  SELECT decrypted_secret FROM vault.decrypted_secrets
   WHERE name = 'dm_channel_token_key' LIMIT 1;
$function$;

-- ----------------------------------------------------------------------------
-- 3. Enkripsi / dekripsi token kanal
--    Format ciphertext: 'v1:' || base64(pgp_sym_encrypt(token, key))
--    - dm_encrypt_token idempoten: nilai 'v1:'... dikembalikan apa adanya.
--    - dm_decrypt_token toleran nilai lama (plaintext tanpa prefix) -> passthrough.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dm_encrypt_token(p_token text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'vault', 'extensions'
AS $function$
DECLARE
  v_key text;
BEGIN
  IF p_token IS NULL OR length(p_token) = 0 THEN
    RETURN NULL;
  END IF;
  IF p_token LIKE 'v1:%' THEN
    RETURN p_token;
  END IF;
  v_key := public.dm_token_key();
  IF v_key IS NULL THEN
    RAISE EXCEPTION 'dm_token_key_missing';
  END IF;
  RETURN 'v1:' || encode(pgp_sym_encrypt(p_token, v_key), 'base64');
END;
$function$;

CREATE OR REPLACE FUNCTION public.dm_decrypt_token(p_stored text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'vault', 'extensions'
AS $function$
DECLARE
  v_key text;
BEGIN
  IF p_stored IS NULL OR length(p_stored) = 0 THEN
    RETURN NULL;
  END IF;
  IF p_stored NOT LIKE 'v1:%' THEN
    RETURN p_stored;  -- data lama (plaintext) -> diteruskan apa adanya
  END IF;
  v_key := public.dm_token_key();
  IF v_key IS NULL THEN
    RAISE EXCEPTION 'dm_token_key_missing';
  END IF;
  RETURN pgp_sym_decrypt(decode(substring(p_stored from 4), 'base64'), v_key);
END;
$function$;

REVOKE ALL ON FUNCTION public.dm_token_key() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.dm_encrypt_token(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.dm_decrypt_token(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.dm_token_key() TO service_role;
GRANT EXECUTE ON FUNCTION public.dm_encrypt_token(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.dm_decrypt_token(text) TO service_role;

-- ----------------------------------------------------------------------------
-- 4. dm_set_own_channel_account: enkripsi token sebelum disimpan
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dm_set_own_channel_account(
  p_outlet UUID,
  p_channel TEXT,
  p_account_name TEXT DEFAULT NULL,
  p_external_id TEXT DEFAULT NULL,
  p_token TEXT DEFAULT NULL,
  p_connected BOOLEAN DEFAULT TRUE
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT (public.is_outlet_owner(p_outlet) OR public.is_platform_admin()) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Forbidden');
  END IF;

  INSERT INTO public.dm_channel_accounts AS a (
    outlet_id, channel, account_name, external_id, token_enc, is_connected, last_sync
  )
  VALUES (
    p_outlet, p_channel, NULLIF(p_account_name, ''), NULLIF(p_external_id, ''),
    public.dm_encrypt_token(NULLIF(p_token, '')), COALESCE(p_connected, true),
    CASE WHEN COALESCE(p_connected, true) THEN NOW() ELSE NULL END
  )
  ON CONFLICT (outlet_id, channel) DO UPDATE SET
    account_name = COALESCE(EXCLUDED.account_name, a.account_name),
    external_id  = COALESCE(EXCLUDED.external_id, a.external_id),
    token_enc    = CASE WHEN EXCLUDED.token_enc IS NULL THEN a.token_enc ELSE EXCLUDED.token_enc END,
    is_connected = EXCLUDED.is_connected,
    last_sync    = CASE WHEN EXCLUDED.is_connected THEN NOW() ELSE a.last_sync END;

  RETURN jsonb_build_object('success', true, 'channel', p_channel, 'is_connected', COALESCE(p_connected, true));
END; $$;

REVOKE ALL ON FUNCTION public.dm_set_own_channel_account(UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dm_set_own_channel_account(UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. Backfill token lama (plaintext -> terenkripsi)
-- ----------------------------------------------------------------------------
UPDATE public.dm_channel_accounts
   SET token_enc = public.dm_encrypt_token(token_enc)
 WHERE token_enc IS NOT NULL
   AND token_enc NOT LIKE 'v1:%';

-- ----------------------------------------------------------------------------
-- 6. Prune dm_oauth_states (anti-CSRF) + index
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_dm_oauth_states_expires
  ON public.dm_oauth_states (expires_at);

CREATE OR REPLACE FUNCTION public.dm_prune_oauth_states()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_n integer;
BEGIN
  DELETE FROM public.dm_oauth_states
   WHERE expires_at < NOW() - INTERVAL '1 day';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END; $$;

REVOKE ALL ON FUNCTION public.dm_prune_oauth_states() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.dm_prune_oauth_states() TO service_role;

COMMIT;

-- ============================================================================
-- VERIFIKASI (service_role / Management API):
--   SELECT public.dm_encrypt_token('rahasia');            -- -> v1:....
--   SELECT public.dm_decrypt_token(public.dm_encrypt_token('rahasia'));  -- -> rahasia
--   SELECT public.dm_prune_oauth_states();                -- jumlah baris dipangkas
--   SELECT has_function_privilege('authenticated','public.dm_decrypt_token(text)','EXECUTE'); -- false
-- ============================================================================
