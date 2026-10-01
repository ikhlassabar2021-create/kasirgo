-- =============================================================================
-- 2026-10-07-kasirgo-rcb-pg.sql
--
-- Integrasi Payment Gateway RCB Pay (PT Raga Cipta Bersama).
--
-- Mode yang dipakai: SANDBOX LANGSUNG DARI APLIKASI (untuk testing).
--   - Kredensial & mode disimpan di platform_integrations.secret_config
--     (tabel tidak bisa dibaca klien).
--   - RPC get_pg_client_config() adalah satu-satunya jalan klien memperoleh
--     konfigurasi; api_key HANYA dikembalikan bila mode = 'sandbox_direct'.
--   - Untuk produksi: ganti mode menjadi 'server' dan pindahkan pemanggilan
--     ke Edge Function (rcb_create_charge / rcb_webhook). Saat itu api_key
--     tidak lagi dikembalikan ke klien.
--
-- Yang dibuat:
--   1. Tabel public.payment_orders (order QRIS per outlet).
--   2. Helper is_outlet_member() + RLS payment_orders.
--   3. RPC get_pg_client_config().
--   4. RPC confirm_pg_order() (tandai PAID + aktivasi langganan).
--   5. Merge config payment_gateway (mode + base_url).
-- =============================================================================

\set ON_ERROR_STOP on
BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Tabel payment_orders
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_orders (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id      uuid NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  created_by     uuid,
  purpose        text NOT NULL DEFAULT 'pos',        -- pos | subscription
  provider       text NOT NULL DEFAULT 'rcb',
  rcb_order_id   text UNIQUE,
  external_id    text,
  amount         numeric(14,2) NOT NULL,
  total_amount   numeric(14,2),
  kode_unik      integer,
  status         text NOT NULL DEFAULT 'PENDING',   -- PENDING | PAID | EXPIRED | FAILED
  payment_url    text,
  qris_url       text,
  qris_string    text,
  payment_type   text,
  qris_provider  text,
  transaction_id uuid,
  supporter_id   uuid,
  expired_at     timestamptz,
  paid_at        timestamptz,
  raw            jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payment_orders_outlet_idx ON public.payment_orders(outlet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS payment_orders_status_idx ON public.payment_orders(status);

-- -----------------------------------------------------------------------------
-- 2. Helper + RLS
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_outlet_member(p_outlet uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.outlets o
                  WHERE o.id = p_outlet AND o.owner_id = auth.uid())
      OR EXISTS (SELECT 1 FROM public.user_roles r
                  WHERE r.outlet_id = p_outlet AND r.user_id = auth.uid());
$function$;

GRANT EXECUTE ON FUNCTION public.is_outlet_member(uuid) TO authenticated;

ALTER TABLE public.payment_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Outlet member read payment_orders" ON public.payment_orders;
CREATE POLICY "Outlet member read payment_orders" ON public.payment_orders
  FOR SELECT TO authenticated
  USING (public.is_outlet_member(outlet_id));

DROP POLICY IF EXISTS "Outlet member insert payment_orders" ON public.payment_orders;
CREATE POLICY "Outlet member insert payment_orders" ON public.payment_orders
  FOR INSERT TO authenticated
  WITH CHECK (public.is_outlet_member(outlet_id));

DROP POLICY IF EXISTS "Outlet member update payment_orders" ON public.payment_orders;
CREATE POLICY "Outlet member update payment_orders" ON public.payment_orders
  FOR UPDATE TO authenticated
  USING (public.is_outlet_member(outlet_id))
  WITH CHECK (public.is_outlet_member(outlet_id));

-- -----------------------------------------------------------------------------
-- 3. Konfigurasi PG untuk klien
--    api_key hanya keluar saat mode 'sandbox_direct' (testing saja).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_pg_client_config()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  r public.platform_integrations;
  v_mode text;
BEGIN
  SELECT * INTO r FROM public.platform_integrations WHERE key = 'payment_gateway' LIMIT 1;
  IF r IS NULL THEN
    RETURN jsonb_build_object('enabled', false, 'mode', '', 'provider', 'rcb', 'api_key', '');
  END IF;

  v_mode := COALESCE(r.secret_config->>'mode', '');

  RETURN jsonb_build_object(
    'provider', COALESCE(r.public_config->>'provider', r.secret_config->>'provider', 'rcb'),
    'enabled',  r.is_active,
    'mode',     v_mode,
    'base_url', COALESCE(r.secret_config->>'base_url',
                         r.public_config->>'base_url',
                         'https://api.ragaciptabersama.web.id/api'),
    'api_key',  CASE WHEN v_mode = 'sandbox_direct'
                     THEN COALESCE(r.secret_config->>'api_key', '')
                     ELSE '' END
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_pg_client_config() TO anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. confirm_pg_order: tandai order PAID (hasil polling klien) + aktivasi
--    langganan bila purpose='subscription'. SECURITY DEFINER; hanya boleh
--    untuk order milik outlet si pemanggil.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.confirm_pg_order(
  p_rcb_order_id text,
  p_status text DEFAULT 'PAID'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_outlet uuid;
  v_purpose text;
  v_supporter uuid;
  v_status text := upper(COALESCE(p_status, 'PAID'));
BEGIN
  SELECT id, outlet_id, purpose, supporter_id
    INTO v_id, v_outlet, v_purpose, v_supporter
    FROM public.payment_orders
   WHERE rcb_order_id = p_rcb_order_id
   LIMIT 1;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;
  IF NOT public.is_outlet_member(v_outlet) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.payment_orders
     SET status = v_status,
         paid_at = CASE WHEN v_status = 'PAID' THEN now() ELSE paid_at END,
         updated_at = now()
   WHERE id = v_id;

  -- Aktivasi langganan Program Pendukung.
  IF v_status = 'PAID' AND v_purpose = 'subscription' AND v_supporter IS NOT NULL THEN
    UPDATE public.supporters
       SET status = 'active',
           start_date = now(),
           end_date = now() + interval '30 days',
           pg_reference_id = p_rcb_order_id,
           updated_at = now()
     WHERE id = v_supporter;
  END IF;

  RETURN jsonb_build_object('ok', true, 'order_id', p_rcb_order_id, 'status', v_status);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.confirm_pg_order(text, text) TO authenticated;

-- -----------------------------------------------------------------------------
-- 5. Merge config payment_gateway: provider + mode + base_url
-- -----------------------------------------------------------------------------
INSERT INTO public.platform_integrations (key, label, is_active, public_config, secret_config)
VALUES (
  'payment_gateway',
  'Payment Gateway',
  true,
  '{"provider":"rcb","base_url":"https://api.ragaciptabersama.web.id/api"}'::jsonb,
  '{"provider":"rcb","mode":"sandbox_direct","base_url":"https://api.ragaciptabersama.web.id/api"}'::jsonb
)
ON CONFLICT (key) DO UPDATE
  SET public_config = public.platform_integrations.public_config || EXCLUDED.public_config,
      secret_config = public.platform_integrations.secret_config || EXCLUDED.secret_config,
      label = COALESCE(public.platform_integrations.label, EXCLUDED.label);

COMMIT;
