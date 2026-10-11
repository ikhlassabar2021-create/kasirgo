-- ST17-2 (Phase 17 - Ekosistem Hyper-Local): akses Pesanan Online untuk KASIR/ADMIN.
-- Sebelumnya RLS `orders`/`order_items` + RPC validate/complete hanya mengizinkan
-- OWNER outlet. Layar POS "Pesanan Online Masuk" dipakai owner DAN kasir, sehingga
-- akses diperluas memakai helper `is_outlet_member(outlet)` (owner + staf outlet).
-- Idempotent: aman dijalankan ulang.

-- ---------------------------------------------------------------------------
-- 1. RLS orders -> outlet member (owner + admin + kasir)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Owner full access orders" ON public.orders;
DROP POLICY IF EXISTS "Outlet member full access orders" ON public.orders;
CREATE POLICY "Outlet member full access orders" ON public.orders
  FOR ALL TO authenticated
  USING (public.is_outlet_member(outlet_id))
  WITH CHECK (public.is_outlet_member(outlet_id));

-- ---------------------------------------------------------------------------
-- 2. RLS order_items -> outlet member via parent order
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Owner full access order_items" ON public.order_items;
DROP POLICY IF EXISTS "Outlet member full access order_items" ON public.order_items;
CREATE POLICY "Outlet member full access order_items" ON public.order_items
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.orders o
                  WHERE o.id = order_id AND public.is_outlet_member(o.outlet_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM public.orders o
                  WHERE o.id = order_id AND public.is_outlet_member(o.outlet_id)));

-- ---------------------------------------------------------------------------
-- 3. RPC validate_order_payment -> izinkan staf outlet
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_order_payment(p_order uuid, p_accept boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_outlet UUID;
BEGIN
  SELECT outlet_id INTO v_outlet FROM public.orders WHERE id = p_order;
  IF v_outlet IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'ORDER_NOT_FOUND');
  END IF;
  IF NOT (public.is_outlet_member(v_outlet) OR public.is_platform_admin()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN');
  END IF;

  IF p_accept THEN
    UPDATE public.orders
      SET payment_status = 'divalidasi', status = 'diproses',
          validated_by = auth.uid(), validated_at = NOW(), updated_at = NOW()
      WHERE id = p_order;
  ELSE
    UPDATE public.orders
      SET payment_status = 'ditolak', status = 'dibatalkan',
          validated_by = auth.uid(), validated_at = NOW(), updated_at = NOW()
      WHERE id = p_order;
  END IF;
  RETURN jsonb_build_object('success', true, 'accepted', p_accept);
END; $function$;

-- ---------------------------------------------------------------------------
-- 4. RPC complete_order -> izinkan staf outlet
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_order(p_order uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_ord RECORD;
  v_tx UUID;
  v_customer UUID;
  v_it RECORD;
BEGIN
  SELECT * INTO v_ord FROM public.orders WHERE id = p_order;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'ORDER_NOT_FOUND');
  END IF;
  IF NOT (public.is_outlet_member(v_ord.outlet_id) OR public.is_platform_admin()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN');
  END IF;

  IF v_ord.status = 'selesai' AND v_ord.transaction_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'idempotent', true, 'transaction_id', v_ord.transaction_id);
  END IF;
  IF v_ord.payment_status <> 'divalidasi' THEN
    RETURN jsonb_build_object('success', false, 'error', 'PAYMENT_NOT_VALIDATED');
  END IF;

  SELECT id INTO v_customer FROM public.customers
    WHERE outlet_id = v_ord.outlet_id AND phone_wa = v_ord.buyer_phone LIMIT 1;

  INSERT INTO public.transactions (
    outlet_id, user_id, customer_id, channel, payment_method,
    total_amount, total_discount, final_amount, status,
    order_status, payment_status, notes, paid_at,
    gross_amount, product_revenue, delivery_pass_through, order_id
  ) VALUES (
    v_ord.outlet_id, auth.uid(), v_customer, 'online', 'qris',
    v_ord.subtotal, 0, v_ord.total, 'completed',
    'selesai', 'paid', 'Pesanan online ' || COALESCE(v_ord.code,''), NOW(),
    v_ord.total, v_ord.subtotal, v_ord.delivery_fee, p_order
  ) RETURNING id INTO v_tx;

  FOR v_it IN SELECT * FROM public.order_items WHERE order_id = p_order LOOP
    INSERT INTO public.transaction_items (
      transaction_id, product_id, product_name, quantity, unit_price, discount, subtotal
    ) VALUES (
      v_tx, v_it.product_id, v_it.name_snapshot, v_it.qty, v_it.price_snapshot, 0, v_it.line_total
    );
  END LOOP;

  UPDATE public.orders
    SET status = 'selesai', transaction_id = v_tx, updated_at = NOW()
    WHERE id = p_order;

  RETURN jsonb_build_object('success', true, 'transaction_id', v_tx, 'total', v_ord.total);
END; $function$;
