-- =============================================================================
-- 2026-10-08-kasirgo-rcb-provider-normalize.sql
--
-- Normalisasi konfigurasi Payment Gateway agar konsisten dengan provider RCB
-- (PT Raga Cipta Bersama) sebagai DEFAULT, zero-custody (dipanggil via Edge
-- Function rcb_create_charge / rcb_check_status / rcb_webhook).
--
-- Masalah yang diperbaiki:
--   platform_integrations.payment_gateway sebelumnya berisi provider='midtrans'
--   tetapi api_key/base_url = RCB  -> get_pg_client_config() salah melaporkan
--   provider ke aplikasi.
--
-- Setelah migrasi ini, superadmin tetap dapat mengganti provider (rcb/midtrans)
-- dan mode (sandbox_server/live_server) lewat Control Plane TANPA ubah kode:
--   - get_pg_client_config() membaca provider/base_url/mode dari config.
--   - Aplikasi memilih RcbProvider / MidtransProvider otomatis.
-- =============================================================================

\set ON_ERROR_STOP on
BEGIN;

-- 1. Normalisasi config aktif ke RCB + sandbox via Edge Function.
UPDATE public.platform_integrations
   SET public_config = COALESCE(public_config, '{}'::jsonb) || '{
         "provider": "rcb",
         "base_url": "https://api.ragaciptabersama.web.id/api",
         "base_url_production": "https://api.ragaciptabersama.web.id/api"
       }'::jsonb,
       secret_config = COALESCE(secret_config, '{}'::jsonb) || '{
         "provider": "rcb",
         "mode": "sandbox_server",
         "base_url": "https://api.ragaciptabersama.web.id/api",
         "callback_url": "https://lmvjecdvfzsmrowwwpck.supabase.co/functions/v1/rcb_webhook"
       }'::jsonb,
       is_active = true,
       updated_at = now()
 WHERE key = 'payment_gateway';

-- 2. Pastikan RPC get_pg_client_config membaca provider dengan benar dan tidak
--    pernah mengembalikan api_key ke klien (zero-custody; selalu lewat EF).
CREATE OR REPLACE FUNCTION public.get_pg_client_config()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  r public.platform_integrations;
  v_provider text;
BEGIN
  SELECT * INTO r FROM public.platform_integrations WHERE key = 'payment_gateway' LIMIT 1;
  IF r IS NULL THEN
    RETURN jsonb_build_object('enabled', false, 'mode', '', 'provider', 'rcb', 'api_key', '');
  END IF;

  v_provider := lower(COALESCE(r.public_config->>'provider',
                               r.secret_config->>'provider', 'rcb'));

  RETURN jsonb_build_object(
    'provider', v_provider,
    'enabled',  r.is_active,
    'mode',     COALESCE(r.secret_config->>'mode', ''),
    'base_url', COALESCE(r.secret_config->>'base_url',
                         r.public_config->>'base_url',
                         'https://api.ragaciptabersama.web.id/api'),
    -- api_key TIDAK dikembalikan lagi: semua charge lewat Edge Function
    -- (zero-custody). Field dipertahankan agar klien lama tidak error.
    'api_key',  ''
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_pg_client_config() TO anon, authenticated;

COMMIT;
