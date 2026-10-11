-- ============================================================================
-- KASIRGO 3.0 - PHASE 17A / ST17-1
-- Ekosistem Hyper-Local - Fondasi Backend/DB (BAGIAN 16 / 17.3)
--   - ALTER outlets (lat/lng, is_mobile, is_open, open_hours, service_queue_enabled,
--     delivery_rules)
--   - CREATE orders, order_items, app_customers, outlet_locations, service_queue
--   - ALTER transactions (gross_amount, product_revenue, delivery_pass_through, order_id)
--   - PostGIS + GIST index; RPC nearby_outlets/submit_order/
--     validate_order_payment/complete_order
--   - RLS (owner full, buyer SELECT/INSERT miliknya); Realtime publication
--   - Seed platform_configs group 'hyperlocal'
-- Idempotent.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0) EXTENSIONS
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- 1) OUTLETS - kolom hyper-local
-- ---------------------------------------------------------------------------
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS is_mobile BOOLEAN DEFAULT FALSE;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS is_open BOOLEAN DEFAULT FALSE;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS open_hours JSONB;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS service_queue_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS delivery_rules JSONB DEFAULT
  '{"enabled":false,"mode":"flat","value":0,"min_km":0,"max_km":3,"free_above":0,"zones":[],"courier":"owner"}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_outlets_geog
  ON public.outlets USING gist
  ((extensions.st_setsrid(extensions.st_makepoint(longitude, latitude), 4326)::extensions.geography));
CREATE INDEX IF NOT EXISTS idx_outlets_open ON public.outlets (is_open);

-- ---------------------------------------------------------------------------
-- 2) APP_CUSTOMERS - identitas Pembeli (anon auth)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_uid UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  phone TEXT,
  name TEXT,
  device_uuid TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_seen TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_app_customers_phone ON public.app_customers (phone);

-- ---------------------------------------------------------------------------
-- 3) ORDERS - siklus pesanan online (terpisah dari transactions)
-- ---------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.order_code_seq;

CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  buyer_id UUID REFERENCES public.app_customers(id) ON DELETE SET NULL,
  code TEXT,
  status TEXT NOT NULL DEFAULT 'baru'
    CHECK (status IN ('baru','diproses','siap','selesai','dibatalkan')),
  payment_status TEXT NOT NULL DEFAULT 'belum_konfirmasi'
    CHECK (payment_status IN ('belum_konfirmasi','divalidasi','ditolak')),
  fulfillment TEXT NOT NULL DEFAULT 'pickup'
    CHECK (fulfillment IN ('pickup','delivery')),
  subtotal NUMERIC NOT NULL DEFAULT 0,
  delivery_fee NUMERIC NOT NULL DEFAULT 0,
  total NUMERIC NOT NULL DEFAULT 0,
  distance_km NUMERIC,
  note TEXT,
  buyer_name TEXT,
  buyer_phone TEXT,
  buyer_lat DOUBLE PRECISION,
  buyer_lng DOUBLE PRECISION,
  proof_path TEXT,
  validated_by UUID,
  validated_at TIMESTAMPTZ,
  transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_orders_outlet ON public.orders (outlet_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_buyer ON public.orders (buyer_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_code ON public.orders (code) WHERE code IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 4) ORDER_ITEMS
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
  name_snapshot TEXT NOT NULL,
  price_snapshot NUMERIC NOT NULL DEFAULT 0,
  qty NUMERIC NOT NULL DEFAULT 1,
  line_total NUMERIC NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON public.order_items (order_id);

-- ---------------------------------------------------------------------------
-- 5) OUTLET_LOCATIONS - broadcast live (gerobak/ojol)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.outlet_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL UNIQUE REFERENCES public.outlets(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 6) SERVICE_QUEUE - antrean jasa (bengkel/cukur)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.service_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  buyer_id UUID REFERENCES public.app_customers(id) ON DELETE SET NULL,
  number INT NOT NULL,
  status TEXT NOT NULL DEFAULT 'menunggu'
    CHECK (status IN ('menunggu','dipanggil','selesai','batal')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_service_queue_outlet ON public.service_queue (outlet_id, status, created_at);

-- ---------------------------------------------------------------------------
-- 7) TRANSACTIONS - pisah omzet produk vs titipan ongkir
-- ---------------------------------------------------------------------------
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS gross_amount NUMERIC;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS product_revenue NUMERIC;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS delivery_pass_through NUMERIC DEFAULT 0;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_transactions_order ON public.transactions (order_id);

-- ---------------------------------------------------------------------------
-- 8) RLS - helper pembeli
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_app_customer_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM public.app_customers WHERE auth_uid = auth.uid() LIMIT 1;
$$;

-- ---------------------------------------------------------------------------
-- 9) RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.app_customers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Self access app_customers" ON public.app_customers;
CREATE POLICY "Self access app_customers" ON public.app_customers
  FOR ALL TO authenticated USING (auth_uid = auth.uid()) WITH CHECK (auth_uid = auth.uid());
DROP POLICY IF EXISTS "Superadmin full access app_customers" ON public.app_customers;
CREATE POLICY "Superadmin full access app_customers" ON public.app_customers
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner full access orders" ON public.orders;
CREATE POLICY "Owner full access orders" ON public.orders
  FOR ALL TO authenticated USING (public.is_outlet_owner(outlet_id)) WITH CHECK (public.is_outlet_owner(outlet_id));
DROP POLICY IF EXISTS "Buyer read own orders" ON public.orders;
CREATE POLICY "Buyer read own orders" ON public.orders
  FOR SELECT TO authenticated USING (buyer_id = public.current_app_customer_id());
DROP POLICY IF EXISTS "Buyer insert own orders" ON public.orders;
CREATE POLICY "Buyer insert own orders" ON public.orders
  FOR INSERT TO authenticated WITH CHECK (buyer_id = public.current_app_customer_id());
DROP POLICY IF EXISTS "Superadmin full access orders" ON public.orders;
CREATE POLICY "Superadmin full access orders" ON public.orders
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner full access order_items" ON public.order_items;
CREATE POLICY "Owner full access order_items" ON public.order_items
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_id AND public.is_outlet_owner(o.outlet_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_id AND public.is_outlet_owner(o.outlet_id)));
DROP POLICY IF EXISTS "Buyer read own order_items" ON public.order_items;
CREATE POLICY "Buyer read own order_items" ON public.order_items
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_id AND o.buyer_id = public.current_app_customer_id()));
DROP POLICY IF EXISTS "Superadmin full access order_items" ON public.order_items;
CREATE POLICY "Superadmin full access order_items" ON public.order_items
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

ALTER TABLE public.outlet_locations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read open outlet_locations" ON public.outlet_locations;
CREATE POLICY "Public read open outlet_locations" ON public.outlet_locations
  FOR SELECT TO anon, authenticated
  USING (EXISTS (SELECT 1 FROM public.outlets o WHERE o.id = outlet_id AND o.is_open = true));
DROP POLICY IF EXISTS "Owner manage own outlet_locations" ON public.outlet_locations;
CREATE POLICY "Owner manage own outlet_locations" ON public.outlet_locations
  FOR ALL TO authenticated USING (public.is_outlet_owner(outlet_id)) WITH CHECK (public.is_outlet_owner(outlet_id));
DROP POLICY IF EXISTS "Superadmin full access outlet_locations" ON public.outlet_locations;
CREATE POLICY "Superadmin full access outlet_locations" ON public.outlet_locations
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

ALTER TABLE public.service_queue ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner full access service_queue" ON public.service_queue;
CREATE POLICY "Owner full access service_queue" ON public.service_queue
  FOR ALL TO authenticated USING (public.is_outlet_owner(outlet_id)) WITH CHECK (public.is_outlet_owner(outlet_id));
DROP POLICY IF EXISTS "Buyer read own service_queue" ON public.service_queue;
CREATE POLICY "Buyer read own service_queue" ON public.service_queue
  FOR SELECT TO authenticated USING (buyer_id = public.current_app_customer_id());
DROP POLICY IF EXISTS "Buyer insert own service_queue" ON public.service_queue;
CREATE POLICY "Buyer insert own service_queue" ON public.service_queue
  FOR INSERT TO authenticated WITH CHECK (buyer_id = public.current_app_customer_id());
DROP POLICY IF EXISTS "Superadmin full access service_queue" ON public.service_queue;
CREATE POLICY "Superadmin full access service_queue" ON public.service_queue
  FOR ALL USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

-- ---------------------------------------------------------------------------
-- 10) RPC - nearby_outlets (SECURITY DEFINER, data publik saja)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.nearby_outlets(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT NULL
)
RETURNS TABLE (
  id UUID, name TEXT, type TEXT, address TEXT, phone TEXT,
  is_open BOOLEAN, is_mobile BOOLEAN, latitude DOUBLE PRECISION, longitude DOUBLE PRECISION,
  distance_km DOUBLE PRECISION, queue_count INT, has_delivery BOOLEAN
)
LANGUAGE sql SECURITY DEFINER SET search_path = public, extensions AS $$
  WITH cfg AS (
    SELECT
      COALESCE((SELECT (value->>'radius_default_km')::double precision FROM public.platform_configs WHERE key='hyperlocal' AND scope='global' ORDER BY version DESC LIMIT 1), 3) AS def_km,
      COALESCE((SELECT (value->>'max_radius_km')::double precision FROM public.platform_configs WHERE key='hyperlocal' AND scope='global' ORDER BY version DESC LIMIT 1), 10) AS max_km
  ), r AS (
    SELECT LEAST(COALESCE(p_radius_km, cfg.def_km), cfg.max_km) AS km FROM cfg
  ), pt AS (
    SELECT st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography AS g
  )
  SELECT o.id, o.name, o.type, o.address, o.phone, o.is_open, o.is_mobile,
         o.latitude, o.longitude,
         (st_distance(st_setsrid(st_makepoint(o.longitude, o.latitude), 4326)::geography, pt.g) / 1000.0) AS distance_km,
         (SELECT count(*)::int FROM public.service_queue q WHERE q.outlet_id = o.id AND q.status = 'menunggu') AS queue_count,
         COALESCE((o.delivery_rules->>'enabled')::boolean, false) AS has_delivery
  FROM public.outlets o, pt, r
  WHERE o.latitude IS NOT NULL AND o.longitude IS NOT NULL
    AND st_dwithin(st_setsrid(st_makepoint(o.longitude, o.latitude), 4326)::geography, pt.g, r.km * 1000)
  ORDER BY distance_km ASC;
$$;

-- ---------------------------------------------------------------------------
-- 11) RPC - submit_order (atomik: order + items + ongkir)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_order(
  p_outlet UUID,
  p_items JSONB,
  p_fulfillment TEXT DEFAULT 'pickup',
  p_note TEXT DEFAULT NULL,
  p_buyer_lat DOUBLE PRECISION DEFAULT NULL,
  p_buyer_lng DOUBLE PRECISION DEFAULT NULL,
  p_name TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL
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
    IF v_mode = 'percent' THEN
      v_fee := round(v_subtotal * v_value / 100.0);
    ELSE
      v_fee := v_value;
    END IF;
    IF v_free_above > 0 AND v_subtotal >= v_free_above THEN
      v_fee := 0;
    END IF;
  END IF;

  v_total := v_subtotal + v_fee;
  v_code := 'ORD' || to_char(NOW(), 'YYMMDD') || lpad(nextval('public.order_code_seq')::text, 5, '0');

  INSERT INTO public.orders (
    outlet_id, buyer_id, code, status, payment_status, fulfillment,
    subtotal, delivery_fee, total, distance_km, note, buyer_name, buyer_phone,
    buyer_lat, buyer_lng
  ) VALUES (
    p_outlet, v_buyer, v_code, 'baru', 'belum_konfirmasi',
    CASE WHEN p_fulfillment = 'delivery' THEN 'delivery' ELSE 'pickup' END,
    v_subtotal, v_fee, v_total, v_dist, NULLIF(p_note,''), NULLIF(p_name,''), NULLIF(p_phone,''),
    p_buyer_lat, p_buyer_lng
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
    'distance_km', v_dist, 'buyer_id', v_buyer
  );
END; $$;

-- ---------------------------------------------------------------------------
-- 12) RPC - validate_order_payment (kasir validasi mutasi manual)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_order_payment(p_order UUID, p_accept BOOLEAN)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_outlet UUID;
BEGIN
  SELECT outlet_id INTO v_outlet FROM public.orders WHERE id = p_order;
  IF v_outlet IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'ORDER_NOT_FOUND');
  END IF;
  IF NOT (public.is_outlet_owner(v_outlet) OR public.is_platform_admin()) THEN
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
END; $$;

-- ---------------------------------------------------------------------------
-- 13) RPC - complete_order (idempoten -> transactions + items)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_order(p_order UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
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
  IF NOT (public.is_outlet_owner(v_ord.outlet_id) OR public.is_platform_admin()) THEN
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
END; $$;

-- ---------------------------------------------------------------------------
-- 14) GRANT EXECUTE
-- ---------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.nearby_outlets(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_order(UUID, JSONB, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_order_payment(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_order(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- 15) REALTIME publication
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='orders') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='outlet_locations') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.outlet_locations;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='service_queue') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.service_queue;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 16) Seed/merge platform_configs group 'hyperlocal'
--     (grup sudah ada dari Phase 10 dengan scope_ref NULL -> merge kunci baru)
-- ---------------------------------------------------------------------------
UPDATE public.platform_configs
  SET value = COALESCE(value, '{}'::jsonb) || '{"radius_default_km":3,"max_radius_km":10,"delivery_max_markup_pct":50,"map_tile_url":"https://tile.openstreetmap.org/{z}/{x}/{y}.png","maps_attribution":"© OpenStreetMap contributors","customer_ads_enabled":true,"order_rate_limit_per_hour":5}'::jsonb,
      updated_at = NOW()
  WHERE key = 'hyperlocal' AND scope = 'global' AND scope_ref IS NULL;

INSERT INTO public.platform_configs (key, scope, scope_ref, value, version)
SELECT 'hyperlocal', 'global', NULL,
  '{"enabled":true,"radius_default_km":3,"max_radius_km":10,"delivery_max_markup_pct":50,"map_tile_url":"https://tile.openstreetmap.org/{z}/{x}/{y}.png","maps_attribution":"© OpenStreetMap contributors","customer_ads_enabled":true,"order_rate_limit_per_hour":5}'::jsonb,
  1
WHERE NOT EXISTS (
  SELECT 1 FROM public.platform_configs WHERE key = 'hyperlocal' AND scope = 'global' AND scope_ref IS NULL
);

-- bersihkan duplikat yang dibuat seed lama (scope_ref='all') bila kanonik sudah ada
DELETE FROM public.platform_configs
  WHERE key = 'hyperlocal' AND scope = 'global' AND scope_ref = 'all'
    AND EXISTS (SELECT 1 FROM public.platform_configs WHERE key='hyperlocal' AND scope='global' AND scope_ref IS NULL);

-- ============================================================================
-- VERIFIKASI:
--   SELECT public.nearby_outlets(-6.2, 106.8, 3);
--   SELECT value FROM public.platform_configs WHERE key='hyperlocal';
--   SELECT tablename FROM pg_publication_tables WHERE pubname='supabase_realtime';
-- ============================================================================
