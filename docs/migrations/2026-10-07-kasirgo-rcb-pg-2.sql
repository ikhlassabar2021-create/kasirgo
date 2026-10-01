-- =============================================================================
-- 2026-10-07-kasirgo-rcb-pg-2.sql
-- create_supporter_checkout mengembalikan supporter_id agar pembayaran QRIS
-- dinamis (RCB) dapat dikaitkan -> aktivasi otomatis saat confirm_pg_order.
-- =============================================================================

\set ON_ERROR_STOP on
BEGIN;

CREATE OR REPLACE FUNCTION public.create_supporter_checkout(p_outlet uuid, p_order_id text, p_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_price NUMERIC;
  v_period INT;
  v_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.outlets o WHERE o.id = p_outlet AND o.owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  SELECT COALESCE((value->>'supporter_price')::numeric, 50000),
         COALESCE((value->>'period_days')::int, 30)
    INTO v_price, v_period
  FROM (SELECT value FROM public.platform_configs WHERE key = 'billing'
        ORDER BY version DESC LIMIT 1) c;

  UPDATE public.supporters
     SET status = 'cancelled', updated_at = now()
   WHERE outlet_id = p_outlet AND status IN ('pending', 'pending_verification');

  INSERT INTO public.supporters (
    outlet_id, tier, amount, status, start_date, auto_renew, pg_reference_id)
  VALUES (p_outlet, 'pendukung', v_price, 'pending', now(), true, p_order_id)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'order_id', p_order_id, 'amount', v_price,
    'period_days', v_period, 'status', 'pending', 'supporter_id', v_id);
END;
$function$;

COMMIT;
