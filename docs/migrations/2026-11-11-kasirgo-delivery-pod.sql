-- ---------------------------------------------------------------------------
-- KasirGo - Proof of Delivery (PoD) + konfirmasi penerimaan pembeli
--
-- Alur antar (delivery):
--   divalidasi -> [Tandai Diantar] diantar -> [Tandai Terkirim + kode penerima]
--   terkirim -> [Selesai] selesai (transaksi dibuat).
--
-- Status baru: 'diantar' (kurir jalan) & 'terkirim' (sudah diterima).
-- receiver_code: 4 digit yang HANYA dilihat pembeli; kasir/kurir harus
--   memasukkan kode tsb untuk menandai 'terkirim' (bukti barang diterima).
--   Untuk Grab/Gojek, pembeli boleh menandai sendiri "sudah saya terima".
--
-- Kolom orders.total tetap nilai pesanan (omzet). Idempotent.
-- ---------------------------------------------------------------------------

-- 1. Perluas status yang diizinkan.
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_status_check
  CHECK (status IN ('baru','diproses','siap','diantar','terkirim','selesai','dibatalkan'));

-- 2. Kolom PoD.
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS receiver_code TEXT,
  ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS delivered_by UUID,
  ADD COLUMN IF NOT EXISTS receiver_confirmed_at TIMESTAMPTZ;

-- 3. submit_order: hasilkan receiver_code (4 digit) untuk pesanan antar.
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

-- 4. Tandai pesanan antar sedang diantar (kurir jalan).
CREATE OR REPLACE FUNCTION public.mark_order_out_for_delivery(p_order UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ord RECORD;
BEGIN
  SELECT * INTO v_ord FROM public.orders WHERE id = p_order FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'ORDER_NOT_FOUND');
  END IF;
  IF NOT (public.is_outlet_member(v_ord.outlet_id) OR public.is_platform_admin()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN');
  END IF;
  IF v_ord.fulfillment <> 'delivery' THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_DELIVERY');
  END IF;
  IF v_ord.payment_status <> 'divalidasi' THEN
    RETURN jsonb_build_object('success', false, 'error', 'PAYMENT_NOT_VALIDATED');
  END IF;
  IF v_ord.status = 'diantar' THEN
    RETURN jsonb_build_object('success', true, 'idempotent', true, 'status', 'diantar');
  END IF;
  IF v_ord.status NOT IN ('baru', 'diproses', 'siap') THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_STATUS', 'status', v_ord.status);
  END IF;

  UPDATE public.orders
    SET status = 'diantar', updated_at = NOW()
    WHERE id = p_order;

  RETURN jsonb_build_object('success', true, 'status', 'diantar');
END; $$;

-- 5. Konfirmasi pesanan diterima.
--    - Kasir/kurir: wajib memasukkan kode penerima (receiver_code) yang benar.
--    - Pembeli: hanya untuk Grab/Gojek (barang diserahkan ke pihak ketiga).
CREATE OR REPLACE FUNCTION public.confirm_order_received(
  p_order UUID,
  p_receiver_code TEXT DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ord RECORD;
  v_is_member BOOLEAN;
  v_is_buyer BOOLEAN;
BEGIN
  SELECT * INTO v_ord FROM public.orders WHERE id = p_order FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'ORDER_NOT_FOUND');
  END IF;

  v_is_member := public.is_outlet_member(v_ord.outlet_id) OR public.is_platform_admin();
  v_is_buyer := (v_ord.buyer_id IS NOT NULL AND v_ord.buyer_id = public.current_app_customer_id());

  IF NOT (v_is_member OR v_is_buyer) THEN
    RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN');
  END IF;
  IF v_ord.fulfillment <> 'delivery' THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_DELIVERY');
  END IF;
  IF v_ord.payment_status <> 'divalidasi' THEN
    RETURN jsonb_build_object('success', false, 'error', 'PAYMENT_NOT_VALIDATED');
  END IF;

  -- Idempoten.
  IF v_ord.status = 'terkirim' THEN
    RETURN jsonb_build_object('success', true, 'idempotent', true, 'status', 'terkirim');
  END IF;
  IF v_ord.status NOT IN ('baru', 'diproses', 'siap', 'diantar') THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_STATUS', 'status', v_ord.status);
  END IF;

  IF v_is_member THEN
    -- Kurir warung: kasir WAJIB memasukkan kode penerima dari pembeli.
    -- Grab/Gojek: kasir boleh menandai terkirim tanpa kode (barang diserahkan
    -- ke pihak ketiga; konfirmasi pembeli tetap tersedia).
    IF COALESCE(v_ord.courier, 'kurir_warung') = 'kurir_warung'
       AND v_ord.receiver_code IS NOT NULL
       AND (p_receiver_code IS NULL OR btrim(p_receiver_code) <> v_ord.receiver_code) THEN
      RETURN jsonb_build_object('success', false, 'error', 'WRONG_RECEIVER_CODE');
    END IF;
    UPDATE public.orders
      SET status = 'terkirim', delivered_at = NOW(), delivered_by = auth.uid(),
          updated_at = NOW()
      WHERE id = p_order;
    RETURN jsonb_build_object('success', true, 'status', 'terkirim', 'by', 'member');
  ELSE
    -- Pembeli hanya boleh konfirmasi bila diantar pihak ketiga (Grab/Gojek).
    IF COALESCE(v_ord.courier, '') NOT IN ('grab', 'gojek') THEN
      RETURN jsonb_build_object('success', false, 'error', 'BUYER_CONFIRM_NOT_ALLOWED');
    END IF;
    UPDATE public.orders
      SET status = 'terkirim', receiver_confirmed_at = NOW(), updated_at = NOW()
      WHERE id = p_order;
    RETURN jsonb_build_object('success', true, 'status', 'terkirim', 'by', 'buyer');
  END IF;
END; $$;

GRANT EXECUTE ON FUNCTION public.mark_order_out_for_delivery(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_order_received(UUID, TEXT) TO authenticated;
