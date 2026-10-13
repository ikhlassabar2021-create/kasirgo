-- ============================================================================
-- KasirGo - Item 5: Owner/Kasir blokir Pembeli (Pembeli tidak bisa order lagi)
-- ----------------------------------------------------------------------------
-- Tabel outlet_blocked_buyers + RLS (member outlet & superadmin) + RPC
-- block_buyer/unblock_buyer/list_blocked_buyers + penegakan di submit_order
-- (error BUYER_BLOCKED). Idempoten.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tabel blokir
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.outlet_blocked_buyers (
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  buyer_id UUID NOT NULL REFERENCES public.app_customers(id) ON DELETE CASCADE,
  reason TEXT,
  blocked_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (outlet_id, buyer_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_buyers_outlet
  ON public.outlet_blocked_buyers (outlet_id, created_at DESC);

-- ----------------------------------------------------------------------------
-- 2. RLS
-- ----------------------------------------------------------------------------
ALTER TABLE public.outlet_blocked_buyers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS blocked_buyers_member_all ON public.outlet_blocked_buyers;
CREATE POLICY blocked_buyers_member_all ON public.outlet_blocked_buyers
  FOR ALL TO authenticated
  USING (public.is_outlet_member(outlet_id))
  WITH CHECK (public.is_outlet_member(outlet_id));

DROP POLICY IF EXISTS blocked_buyers_admin_all ON public.outlet_blocked_buyers;
CREATE POLICY blocked_buyers_admin_all ON public.outlet_blocked_buyers
  FOR ALL TO authenticated
  USING (public.is_platform_admin())
  WITH CHECK (public.is_platform_admin());

-- ----------------------------------------------------------------------------
-- 3. RPC: blokir / buka blokir / daftar
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.block_buyer(
  p_outlet UUID,
  p_buyer UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;
  IF NOT (public.is_outlet_member(p_outlet) OR public.is_platform_admin()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.app_customers WHERE id = p_buyer) THEN
    RETURN jsonb_build_object('success', false, 'error', 'BUYER_NOT_FOUND');
  END IF;

  INSERT INTO public.outlet_blocked_buyers (outlet_id, buyer_id, reason, blocked_by)
  VALUES (p_outlet, p_buyer, NULLIF(btrim(p_reason), ''), auth.uid())
  ON CONFLICT (outlet_id, buyer_id) DO UPDATE
    SET reason = EXCLUDED.reason,
        blocked_by = EXCLUDED.blocked_by,
        created_at = NOW();

  RETURN jsonb_build_object('success', true, 'outlet_id', p_outlet, 'buyer_id', p_buyer);
END; $$;

CREATE OR REPLACE FUNCTION public.unblock_buyer(
  p_outlet UUID,
  p_buyer UUID
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;
  IF NOT (public.is_outlet_member(p_outlet) OR public.is_platform_admin()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN');
  END IF;

  DELETE FROM public.outlet_blocked_buyers
   WHERE outlet_id = p_outlet AND buyer_id = p_buyer;

  RETURN jsonb_build_object('success', true, 'outlet_id', p_outlet, 'buyer_id', p_buyer);
END; $$;

CREATE OR REPLACE FUNCTION public.list_blocked_buyers(p_outlet UUID)
RETURNS TABLE (
  buyer_id UUID,
  name TEXT,
  phone TEXT,
  reason TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT b.buyer_id,
         c.name,
         c.phone,
         b.reason,
         b.created_at
    FROM public.outlet_blocked_buyers b
    JOIN public.app_customers c ON c.id = b.buyer_id
   WHERE b.outlet_id = p_outlet
     AND (public.is_outlet_member(p_outlet) OR public.is_platform_admin())
   ORDER BY b.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.block_buyer(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unblock_buyer(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_blocked_buyers(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 4. submit_order: tolak bila pembeli diblokir di outlet ini (BUYER_BLOCKED)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.submit_order(
  UUID, JSONB, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.submit_order(
  p_outlet UUID,
  p_items JSONB,
  p_fulfillment TEXT DEFAULT 'pickup',
  p_note TEXT DEFAULT NULL,
  p_buyer_lat DOUBLE PRECISION DEFAULT NULL,
  p_buyer_lng DOUBLE PRECISION DEFAULT NULL,
  p_name TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL,
  p_address TEXT DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE
  v_buyer UUID;
  v_rules JSONB;
  v_enabled BOOLEAN;
  v_mode TEXT;
  v_value NUMERIC;
  v_free_above NUMERIC;
  v_max_km NUMERIC;
  v_manual BOOLEAN;
  v_manual_value NUMERIC;
  v_dist NUMERIC;
  v_subtotal NUMERIC := 0;
  v_fee NUMERIC := 0;
  v_total NUMERIC;
  v_order UUID;
  v_code TEXT;
  v_seq BIGINT;
  v_unique INT;
  v_receiver TEXT;
  v_is_delivery BOOLEAN;
  v_item JSONB;
  v_prod RECORD;
  v_qty NUMERIC;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.outlets WHERE id = p_outlet) THEN
    RETURN jsonb_build_object('success', false, 'error', 'OUTLET_NOT_FOUND');
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'EMPTY_CART');
  END IF;
  v_is_delivery := (p_fulfillment = 'delivery');
  IF v_is_delivery AND (p_address IS NULL OR btrim(p_address) = '') THEN
    RETURN jsonb_build_object('success', false, 'error', 'ADDRESS_REQUIRED');
  END IF;

  SELECT id INTO v_buyer FROM public.app_customers WHERE auth_uid = auth.uid() LIMIT 1;
  IF v_buyer IS NULL THEN
    INSERT INTO public.app_customers (auth_uid, name, phone)
    VALUES (auth.uid(), NULLIF(p_name,''), NULLIF(p_phone,''))
    RETURNING id INTO v_buyer;
  ELSE
    UPDATE public.app_customers
      SET last_seen = NOW(),
          name = COALESCE(NULLIF(p_name,''), name),
          phone = COALESCE(NULLIF(p_phone,''), phone)
      WHERE id = v_buyer;
  END IF;

  -- Item 5: pembeli yang diblokir outlet ini tidak boleh membuat pesanan.
  IF EXISTS (
    SELECT 1 FROM public.outlet_blocked_buyers b
     WHERE b.outlet_id = p_outlet AND b.buyer_id = v_buyer
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'BUYER_BLOCKED');
  END IF;

  SELECT COALESCE(delivery_rules, '{}'::jsonb) INTO v_rules FROM public.outlets WHERE id = p_outlet;
  v_enabled := COALESCE((v_rules->>'enabled')::boolean, false);
  v_mode := COALESCE(v_rules->>'mode', 'flat');
  v_value := COALESCE((v_rules->>'value')::numeric, 0);
  v_free_above := COALESCE((v_rules->>'free_above')::numeric, 0);
  v_max_km := COALESCE((v_rules->>'max_km')::numeric, 3);
  v_manual := COALESCE((v_rules->>'manual')::boolean, false);
  v_manual_value := COALESCE((v_rules->>'manual_value')::numeric, 0);

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    SELECT id, name, base_price, stock, is_published INTO v_prod
      FROM public.products WHERE id = (v_item->>'product_id')::uuid AND outlet_id = p_outlet;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'PRODUCT_NOT_FOUND', 'product_id', v_item->>'product_id');
    END IF;
    IF v_prod.is_published IS NOT TRUE THEN
      RETURN jsonb_build_object('success', false, 'error', 'PRODUCT_NOT_PUBLISHED', 'product_id', v_prod.id);
    END IF;
    v_qty := GREATEST(COALESCE((v_item->>'qty')::numeric, 0), 0);
    IF v_qty <= 0 THEN CONTINUE; END IF;
    v_subtotal := v_subtotal + (v_prod.base_price * v_qty);
  END LOOP;

  IF v_subtotal <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'EMPTY_CART');
  END IF;

  IF v_is_delivery AND v_enabled THEN
    IF p_buyer_lat IS NOT NULL AND p_buyer_lng IS NOT NULL THEN
      SELECT (st_distance(
                st_setsrid(st_makepoint(o.longitude, o.latitude), 4326)::geography,
                st_setsrid(st_makepoint(p_buyer_lng, p_buyer_lat), 4326)::geography) / 1000.0)
        INTO v_dist FROM public.outlets o
        WHERE o.id = p_outlet AND o.latitude IS NOT NULL AND o.longitude IS NOT NULL;
    END IF;
    IF v_dist IS NOT NULL AND v_dist > v_max_km THEN
      RETURN jsonb_build_object('success', false, 'error', 'OUT_OF_DELIVERY_RANGE', 'max_km', v_max_km, 'distance_km', v_dist);
    END IF;
    IF v_manual THEN
      v_fee := v_manual_value;
    ELSIF v_mode = 'percent' THEN
      v_fee := round(v_subtotal * v_value / 100.0);
    ELSE
      v_fee := v_value;
    END IF;
    IF NOT v_manual AND v_free_above > 0 AND v_subtotal >= v_free_above THEN
      v_fee := 0;
    END IF;
  END IF;

  v_total := v_subtotal + v_fee;
  v_seq := nextval('public.order_code_seq');
  v_code := 'ORD' || to_char(NOW(), 'YYMMDD') || lpad(v_seq::text, 5, '0');
  v_unique := ((v_seq % 900) + 100)::int;  -- 100..999
  -- Kode penerima 4 digit (hanya untuk pesanan antar).
  v_receiver := CASE WHEN v_is_delivery
                     THEN lpad((v_seq % 10000)::text, 4, '0')
                     ELSE NULL END;

  INSERT INTO public.orders (
    outlet_id, buyer_id, code, status, payment_status, fulfillment,
    subtotal, delivery_fee, total, distance_km, note, buyer_name, buyer_phone,
    buyer_lat, buyer_lng, buyer_address, unique_code, receiver_code
  ) VALUES (
    p_outlet, v_buyer, v_code, 'baru', 'belum_konfirmasi',
    CASE WHEN v_is_delivery THEN 'delivery' ELSE 'pickup' END,
    v_subtotal, v_fee, v_total, v_dist, NULLIF(p_note,''), NULLIF(p_name,''), NULLIF(p_phone,''),
    p_buyer_lat, p_buyer_lng, NULLIF(btrim(p_address),''), v_unique, v_receiver
  ) RETURNING id INTO v_order;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    SELECT id, name, base_price INTO v_prod FROM public.products
      WHERE id = (v_item->>'product_id')::uuid AND outlet_id = p_outlet;
    v_qty := GREATEST(COALESCE((v_item->>'qty')::numeric, 0), 0);
    IF v_qty <= 0 THEN CONTINUE; END IF;
    INSERT INTO public.order_items (order_id, product_id, name_snapshot, price_snapshot, qty, line_total)
    VALUES (v_order, v_prod.id, v_prod.name, v_prod.base_price, v_qty, v_prod.base_price * v_qty);
  END LOOP;

  RETURN jsonb_build_object(
    'success', true, 'order_id', v_order, 'code', v_code,
    'subtotal', v_subtotal, 'delivery_fee', v_fee, 'total', v_total,
    'unique_code', v_unique, 'pay_amount', v_total + v_unique,
    'receiver_code', v_receiver,
    'distance_km', v_dist, 'buyer_id', v_buyer,
    'ongkir_manual', v_manual
  );
END; $$;

GRANT EXECUTE ON FUNCTION
  public.submit_order(UUID, JSONB, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT)
  TO authenticated;
