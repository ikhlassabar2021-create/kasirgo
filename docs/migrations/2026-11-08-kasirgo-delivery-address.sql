-- ---------------------------------------------------------------------------
-- KasirGo - Alamat Pengantaran Wajib (Checkout Pembeli)
-- Saat Pembeli memilih "Diantar", alamat lengkap WAJIB diisi.
-- Alamat disimpan di orders.buyer_address (teks) dan divalidasi server-side.
--
-- Idempotent.
-- ---------------------------------------------------------------------------

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS buyer_address TEXT;

-- submit_order: tambah p_address + wajib saat fulfillment = 'delivery'.
DROP FUNCTION IF EXISTS public.submit_order(
  UUID, JSONB, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT);

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
  -- Alamat lengkap wajib untuk pengantaran.
  IF p_fulfillment = 'delivery' AND (p_address IS NULL OR btrim(p_address) = '') THEN
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

  IF p_fulfillment = 'delivery' AND v_enabled THEN
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
  v_code := 'ORD' || to_char(NOW(), 'YYMMDD') || lpad(nextval('public.order_code_seq')::text, 5, '0');

  INSERT INTO public.orders (
    outlet_id, buyer_id, code, status, payment_status, fulfillment,
    subtotal, delivery_fee, total, distance_km, note, buyer_name, buyer_phone,
    buyer_lat, buyer_lng, buyer_address
  ) VALUES (
    p_outlet, v_buyer, v_code, 'baru', 'belum_konfirmasi',
    CASE WHEN p_fulfillment = 'delivery' THEN 'delivery' ELSE 'pickup' END,
    v_subtotal, v_fee, v_total, v_dist, NULLIF(p_note,''), NULLIF(p_name,''), NULLIF(p_phone,''),
    p_buyer_lat, p_buyer_lng, NULLIF(btrim(p_address),'')
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
    'distance_km', v_dist, 'buyer_id', v_buyer,
    'ongkir_manual', v_manual
  );
END; $$;

GRANT EXECUTE ON FUNCTION
  public.submit_order(UUID, JSONB, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT)
  TO authenticated;
