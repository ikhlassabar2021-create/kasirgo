-- ============================================================================
-- KASIRGO PHASE 16E - OWNER SELF-SERVICE KONEKSI AKUN KANAL
-- ============================================================================
-- Tujuan: owner dapat menghubungkan akun media sosial / iklan SENDIRI dari
--   dashboard owner (tanpa superadmin), semudah mungkin.
-- Keamanan:
--   - token kanal disimpan di dm_channel_accounts.token_enc.
--   - tabel dm_channel_accounts TIDAK memberi policy baca ke owner -> token
--     tidak pernah bisa dibaca klien (hanya status ter-mask via dm_channel_status).
--   - owner hanya boleh MENULIS untuk outlet miliknya via RPC SECURITY DEFINER
--     (is_outlet_owner). Superadmin tetap full access.
--   - RPC tidak pernah mengembalikan token.
-- Idempoten.
-- ============================================================================

-- 1) Owner set/hubungkan akun kanal miliknya sendiri
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
    NULLIF(p_token, ''), COALESCE(p_connected, true),
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

-- 2) Owner putuskan akun kanal miliknya
CREATE OR REPLACE FUNCTION public.dm_delete_own_channel_account(
  p_outlet UUID,
  p_channel TEXT
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT (public.is_outlet_owner(p_outlet) OR public.is_platform_admin()) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Forbidden');
  END IF;
  DELETE FROM public.dm_channel_accounts WHERE outlet_id = p_outlet AND channel = p_channel;
  RETURN jsonb_build_object('success', true, 'channel', p_channel);
END; $$;

REVOKE ALL ON FUNCTION public.dm_set_own_channel_account(UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.dm_delete_own_channel_account(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dm_set_own_channel_account(UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dm_delete_own_channel_account(UUID, TEXT) TO authenticated;

-- ============================================================================
-- VERIFIKASI (owner):
--   SELECT public.dm_set_own_channel_account('<outlet>', 'ig', 'toko_saya', '@toko_saya', 'token-rahasia');
--   SELECT public.dm_channel_status('<outlet>');
--   SELECT public.dm_delete_own_channel_account('<outlet>', 'ig');
-- ============================================================================
