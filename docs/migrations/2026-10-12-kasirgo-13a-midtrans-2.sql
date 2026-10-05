-- =============================================================================
-- 2026-10-12-kasirgo-13a-midtrans-2.sql
--
-- Phase 13A (ST13A-2) — helper Vault + kolom order provider.
--
-- - RPC public.vault_put_secret / vault_read_secret: satu-satunya jalan Edge
--   Function (service_role) menulis/membaca server key Midtrans dari Supabase
--   Vault. EXECUTE hanya untuk service_role; klien TIDAK bisa memanggil.
-- - payment_orders.provider_order_id: id order milik provider (Midtrans),
--   dipisah dari rcb_order_id milik RCB.
--
-- Aman dijalankan berulang (idempotent).
-- =============================================================================

\set ON_ERROR_STOP on
BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Helper Vault (SECURITY DEFINER, hanya service_role)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.vault_put_secret(
  p_secret text,
  p_name text DEFAULT NULL,
  p_secret_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'vault'
AS $function$
DECLARE
  v_id uuid := p_secret_id;
BEGIN
  IF p_secret IS NULL OR length(p_secret) = 0 THEN
    RAISE EXCEPTION 'secret_empty';
  END IF;

  IF v_id IS NULL THEN
    v_id := vault.create_secret(p_secret, p_name, 'KasirGo payment gateway server key');
  ELSE
    -- update_secret() menangani enkripsi ulang + nonce dengan benar.
    PERFORM vault.update_secret(v_id, p_secret);
    IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE id = v_id) THEN
      v_id := vault.create_secret(p_secret, p_name, 'KasirGo payment gateway server key');
    END IF;
  END IF;

  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.vault_read_secret(p_secret_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'vault'
AS $function$
  SELECT decrypted_secret FROM vault.decrypted_secrets WHERE id = p_secret_id LIMIT 1;
$function$;

-- Hanya service_role (Edge Function) yang boleh.
REVOKE ALL ON FUNCTION public.vault_put_secret(text, text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.vault_read_secret(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.vault_put_secret(text, text, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.vault_read_secret(uuid) TO service_role;

-- -----------------------------------------------------------------------------
-- 2. payment_orders.provider_order_id
-- -----------------------------------------------------------------------------
ALTER TABLE public.payment_orders
  ADD COLUMN IF NOT EXISTS provider_order_id text;

CREATE UNIQUE INDEX IF NOT EXISTS payment_orders_provider_order_id_uidx
  ON public.payment_orders(provider_order_id)
  WHERE provider_order_id IS NOT NULL;

COMMIT;

-- =============================================================================
-- VERIFIKASI:
--   SELECT public.vault_put_secret('dummy-test-key','kasirgo-test');
--   SELECT public.vault_read_secret('<uuid>');
--   SELECT has_function_privilege('authenticated','public.vault_read_secret(uuid)','EXECUTE'); -- false
-- =============================================================================
