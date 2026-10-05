-- =============================================================================
-- 2026-10-12-kasirgo-13a-midtrans-schema.sql
--
-- Phase 13A — Payment Gateway QRIS Dinamis Midtrans (zero-custody).
--
-- Prinsip keamanan:
--   - Midtrans Server Key TIDAK PERNAH disimpan sebagai teks di tabel biasa.
--     Disimpan di Supabase Vault (vault.secrets, terenkripsi at-rest); tabel
--     hanya menyimpan `server_key_secret_id` (uuid opaque).
--   - vault.secrets / vault.decrypted_secrets hanya bisa dibaca role
--     postgres + service_role. Klien (anon/authenticated) tidak bisa mendekripsi
--     walau tahu uuid-nya.
--   - Klien hanya membaca config ter-mask via RPC get_outlet_payment_config().
--
-- Yang dibuat:
--   1. Tabel public.outlet_pg_configs (kredensial PG per outlet).
--   2. RLS + column-level grant (secret id tak terbaca authenticated).
--   3. Kolom transactions: provider_ref, paid_at (+ index unik provider_ref).
--   4. Trigger updated_at.
--   5. RPC get_outlet_payment_config(p_outlet) — config ter-mask untuk owner.
--   6. Merge platform_integrations key 'payment_gateway' -> provider midtrans
--      (base_url sandbox + production), hapus 'pg_duitku' bila ada.
--
-- Aman dijalankan berulang (idempotent).
-- =============================================================================

\set ON_ERROR_STOP on
BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Tabel outlet_payment_configs
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.outlet_pg_configs (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id             uuid NOT NULL UNIQUE REFERENCES public.outlets(id) ON DELETE CASCADE,
  provider              text NOT NULL DEFAULT 'midtrans',
  merchant_id           text,
  client_key            text,
  -- uuid baris vault.secrets; nilai rahasia hanya bisa didekripsi service_role.
  server_key_secret_id  uuid,
  is_production         boolean NOT NULL DEFAULT false,
  status                text NOT NULL DEFAULT 'pending',  -- pending | verified | disabled
  last_tested_at        timestamptz,
  last_test_result      text,
  created_by            uuid,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT outlet_pg_configs_status_check
    CHECK (status IN ('pending', 'verified', 'disabled'))
);

CREATE INDEX IF NOT EXISTS outlet_pg_configs_outlet_idx
  ON public.outlet_pg_configs(outlet_id);

-- -----------------------------------------------------------------------------
-- 2. RLS + privilege kolom
-- -----------------------------------------------------------------------------
ALTER TABLE public.outlet_pg_configs ENABLE ROW LEVEL SECURITY;

-- Hanya service_role yang boleh menulis (via Edge Function). Owner hanya baca.
DROP POLICY IF EXISTS "Owner read own payment config" ON public.outlet_pg_configs;
CREATE POLICY "Owner read own payment config" ON public.outlet_pg_configs
  FOR SELECT TO authenticated
  USING (public.is_outlet_owner(outlet_id));

-- Pastikan klien tidak punya akses tabel penuh.
REVOKE ALL ON public.outlet_pg_configs FROM anon;
REVOKE ALL ON public.outlet_pg_configs FROM authenticated;

-- Beri SELECT hanya pada kolom aman (tanpa server_key_secret_id).
GRANT SELECT (
  id, outlet_id, provider, merchant_id, client_key, is_production,
  status, last_tested_at, last_test_result, created_at, updated_at
) ON public.outlet_pg_configs TO authenticated;

GRANT ALL ON public.outlet_pg_configs TO service_role;

-- -----------------------------------------------------------------------------
-- 3. Kolom transactions untuk pembayaran via PG
-- -----------------------------------------------------------------------------
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS provider_ref text,
  ADD COLUMN IF NOT EXISTS paid_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS transactions_provider_ref_uidx
  ON public.transactions(provider_ref)
  WHERE provider_ref IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 4. Trigger updated_at
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_outlet_pg_config_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_outlet_pg_config_updated_at ON public.outlet_pg_configs;
CREATE TRIGGER trg_outlet_pg_config_updated_at
  BEFORE UPDATE ON public.outlet_pg_configs
  FOR EACH ROW EXECUTE FUNCTION public.set_outlet_pg_config_updated_at();

-- -----------------------------------------------------------------------------
-- 5. RPC config ter-mask untuk owner
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_outlet_payment_config(p_outlet uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  r public.outlet_pg_configs;
BEGIN
  IF NOT public.is_outlet_owner(p_outlet) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT * INTO r FROM public.outlet_pg_configs WHERE outlet_id = p_outlet LIMIT 1;
  IF r IS NULL THEN
    RETURN jsonb_build_object(
      'provider', 'midtrans',
      'configured', false,
      'has_server_key', false,
      'is_production', false,
      'status', 'pending'
    );
  END IF;

  RETURN jsonb_build_object(
    'provider', r.provider,
    'configured', (r.merchant_id IS NOT NULL AND r.client_key IS NOT NULL AND r.server_key_secret_id IS NOT NULL),
    'merchant_id', r.merchant_id,
    'client_key', r.client_key,
    'has_server_key', (r.server_key_secret_id IS NOT NULL),
    'is_production', r.is_production,
    'status', r.status,
    'last_tested_at', r.last_tested_at,
    'last_test_result', r.last_test_result
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_outlet_payment_config(uuid) TO authenticated;

-- -----------------------------------------------------------------------------
-- 6. platform_integrations payment_gateway -> midtrans
-- -----------------------------------------------------------------------------
DELETE FROM public.platform_integrations WHERE key = 'pg_duitku';

INSERT INTO public.platform_integrations (key, label, is_active, public_config, secret_config)
VALUES (
  'payment_gateway',
  'Payment Gateway',
  true,
  '{"provider":"midtrans","base_url":"https://api.sandbox.midtrans.com","base_url_production":"https://api.midtrans.com"}'::jsonb,
  '{"provider":"midtrans"}'::jsonb
)
ON CONFLICT (key) DO UPDATE
  SET public_config = public.platform_integrations.public_config
        || '{"provider":"midtrans","base_url":"https://api.sandbox.midtrans.com","base_url_production":"https://api.midtrans.com"}'::jsonb,
      secret_config = public.platform_integrations.secret_config || '{"provider":"midtrans"}'::jsonb,
      label = COALESCE(public.platform_integrations.label, EXCLUDED.label);

COMMIT;

-- =============================================================================
-- VERIFIKASI:
--   \d public.outlet_pg_configs
--   SELECT key, is_active, public_config FROM public.platform_integrations WHERE key='payment_gateway';
--   SELECT has_column_privilege('authenticated','public.outlet_pg_configs','server_key_secret_id','SELECT'); -- harus false
-- =============================================================================
