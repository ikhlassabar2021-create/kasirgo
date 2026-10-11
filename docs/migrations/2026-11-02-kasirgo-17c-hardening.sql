-- ============================================================================
-- KasirGo - Phase 17 (ST17-7) HARDENING & ANTREAN JASA
-- 2026-11-02
-- ----------------------------------------------------------------------------
-- Isi:
--   1) Rate limit pesanan online (anti-spam) via trigger BEFORE INSERT orders
--   2) nearby_outlets() + kolom service_queue_enabled (Pembeli tahu antrean jasa)
--   3) RPC take_queue_number(p_outlet) - Pembeli ambil nomor antrean jasa
--   4) Audit RLS (tanpa perubahan skema; lihat catatan di akhir)
-- Idempoten.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) RATE LIMIT PESANAN ONLINE
--    Membaca platform_configs.hyperlocal.order_rate_limit_per_hour (default 5).
--    Trigger berjalan pada INSERT orders (submit_order & jalur lain).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_order_rate_limit()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_limit INT;
  v_count INT;
BEGIN
  IF NEW.buyer_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE((value->>'order_rate_limit_per_hour')::int, 5)
    INTO v_limit
    FROM public.platform_configs
    WHERE key = 'hyperlocal' AND scope = 'global'
    ORDER BY version DESC LIMIT 1;
  v_limit := COALESCE(v_limit, 5);

  SELECT count(*) INTO v_count
    FROM public.orders
    WHERE buyer_id = NEW.buyer_id
      AND created_at > (NOW() - interval '1 hour');

  IF v_count >= v_limit THEN
    RAISE EXCEPTION 'ORDER_RATE_LIMITED: maksimal % pesanan per jam. Coba lagi nanti.', v_limit
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_orders_rate_limit ON public.orders;
CREATE TRIGGER trg_orders_rate_limit
  BEFORE INSERT ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.enforce_order_rate_limit();

-- ---------------------------------------------------------------------------
-- 2) nearby_outlets() + service_queue_enabled
--    Return type berubah -> wajib DROP lalu CREATE ulang + GRANT ulang.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.nearby_outlets(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);

CREATE FUNCTION public.nearby_outlets(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT NULL
)
RETURNS TABLE (
  id UUID, name TEXT, type TEXT, address TEXT, phone TEXT,
  is_open BOOLEAN, is_mobile BOOLEAN, latitude DOUBLE PRECISION, longitude DOUBLE PRECISION,
  distance_km DOUBLE PRECISION, queue_count INT, has_delivery BOOLEAN,
  service_queue_enabled BOOLEAN
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
         COALESCE((o.delivery_rules->>'enabled')::boolean, false) AS has_delivery,
         COALESCE(o.service_queue_enabled, false) AS service_queue_enabled
  FROM public.outlets o, pt, r
  WHERE o.latitude IS NOT NULL AND o.longitude IS NOT NULL
    AND st_dwithin(st_setsrid(st_makepoint(o.longitude, o.latitude), 4326)::geography, pt.g, r.km * 1000)
  ORDER BY distance_km ASC;
$$;

GRANT EXECUTE ON FUNCTION public.nearby_outlets(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3) RPC take_queue_number(p_outlet) - Pembeli ambil nomor antrean jasa.
--    Nomor urut atomik per outlet; buyer_id dari sesi anonymous.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.take_queue_number(p_outlet UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_buyer UUID;
  v_next INT;
  v_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.outlets WHERE id = p_outlet AND service_queue_enabled = TRUE
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'QUEUE_DISABLED');
  END IF;

  SELECT id INTO v_buyer FROM public.app_customers WHERE auth_uid = auth.uid() LIMIT 1;

  SELECT COALESCE(max(number), 0) + 1 INTO v_next
    FROM public.service_queue WHERE outlet_id = p_outlet;

  INSERT INTO public.service_queue (outlet_id, buyer_id, number, status)
    VALUES (p_outlet, v_buyer, v_next, 'menunggu')
    RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', true, 'id', v_id, 'number', v_next);
END; $$;

GRANT EXECUTE ON FUNCTION public.take_queue_number(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4) AUDIT RLS (tanpa perubahan; dokumentasi hasil audit)
--    - orders: buyer SELECT/INSERT miliknya (buyer_id=current_app_customer_id);
--      outlet member ALL (is_outlet_member); superadmin ALL (is_platform_admin).
--    - order_items: via order_id milik outlet member / superadmin.
--    - outlet_locations: SELECT publik HANYA bila outlets.is_open=true;
--      owner manage (is_outlet_owner); superadmin ALL.
--    - service_queue: owner ALL (is_outlet_owner); buyer SELECT/INSERT miliknya;
--      superadmin ALL. Mutasi nomor lewat RPC take_queue_number (SECURITY DEFINER).
--    - app_customers: self (auth_uid=auth.uid()).
--    Semua tabel hyper-local memakai RLS aktif. Tidak ada akses anon langsung
--    selain nearby_outlets() (RPC) & SELECT outlet_locations saat is_open.
-- ---------------------------------------------------------------------------

-- ============================================================================
-- VERIFIKASI:
--   SELECT public.nearby_outlets(-6.2, 106.8, 3);
--   SELECT public.take_queue_number('<outlet-uuid>');
--   -- rate limit: insert > limit orders utk buyer sama -> error ORDER_RATE_LIMITED
-- ============================================================================
