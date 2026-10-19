-- KasirGo 2026-10-19: Dukungan tipe usaha Jasa (produk layanan tanpa stok)
-- Aditif & idempoten. Menambah kolom products.is_service dan menyesuaikan
-- fungsi katalog publik agar produk layanan tetap tampil walau stok 0,
-- serta trigger decrement_stock agar tidak mengurangi stok layanan.

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS is_service BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_products_outlet_is_service
  ON public.products(outlet_id, is_service);

-- ---------------------------------------------------------------------------
-- decrement_stock: lewati produk layanan (stok tidak relevan)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.decrement_stock()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_outlet UUID;
  v_user UUID;
  v_is_service BOOLEAN;
BEGIN
  SELECT t.outlet_id, t.user_id INTO v_outlet, v_user
    FROM public.transactions t WHERE t.id = NEW.transaction_id;

  IF NEW.variant_id IS NOT NULL THEN
    UPDATE public.product_variants
       SET stock = stock - NEW.quantity, updated_at = NOW()
     WHERE id = NEW.variant_id;
    INSERT INTO public.stock_logs (outlet_id, product_id, variant_id, change, reason, ref_id, user_id)
    SELECT pv.outlet_id, pv.product_id, pv.id, -NEW.quantity, 'penjualan', NEW.transaction_id, v_user
      FROM public.product_variants pv WHERE pv.id = NEW.variant_id;
  ELSE
    SELECT COALESCE(p.is_service, false) INTO v_is_service
      FROM public.products p WHERE p.id = NEW.product_id;

    IF COALESCE(v_is_service, false) THEN
      RETURN NEW;
    END IF;

    UPDATE public.products SET stock = stock - NEW.quantity, updated_at = NOW()
     WHERE id = NEW.product_id;
    INSERT INTO public.stock_logs (outlet_id, product_id, change, reason, ref_id, user_id)
    VALUES (v_outlet, NEW.product_id, -NEW.quantity, 'penjualan', NEW.transaction_id, v_user);
  END IF;
  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------------
-- get_public_catalog: layanan tetap tampil walau stok 0 (+ is_service)
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_public_catalog(text);
CREATE FUNCTION public.get_public_catalog(p_outlet text)
RETURNS TABLE(id uuid, name text, category text, price numeric, stock numeric,
              unit text, is_service boolean)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
  SELECT p.id, p.name, p.category, p.base_price, p.stock, p.unit,
         COALESCE(p.is_service, false)
  FROM public.products p
  WHERE p.outlet_id = p_outlet::uuid
    AND p.is_published = true
    AND (COALESCE(p.is_service, false) OR p.stock > 0)
  ORDER BY p.name;
$function$;

-- ---------------------------------------------------------------------------
-- get_public_menu (QR meja): layanan tetap tampil walau stok 0 (+ is_service)
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_public_menu(text);
CREATE FUNCTION public.get_public_menu(p_outlet text)
RETURNS TABLE(id uuid, name text, category text, price numeric, stock numeric,
              unit text, is_service boolean)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
  SELECT p.id, p.name, p.category, p.base_price, p.stock, p.unit,
         COALESCE(p.is_service, false)
  FROM public.products p
  WHERE p.outlet_id = p_outlet::uuid
    AND (COALESCE(p.is_service, false) OR p.stock > 0)
  ORDER BY p.name;
$function$;

-- ---------------------------------------------------------------------------
-- search_marketplace (5 arg): layanan tetap tampil walau stok 0 (+ is_service)
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.search_marketplace(text, double precision, double precision, double precision, integer);
CREATE FUNCTION public.search_marketplace(
  p_query text,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL,
  p_radius_km double precision DEFAULT NULL,
  p_limit integer DEFAULT 40
)
RETURNS TABLE(outlet_id uuid, outlet_name text, product_id uuid, product_name text,
              category text, price numeric, stock numeric, unit text,
              distance_km double precision, has_delivery boolean, is_open boolean,
              is_service boolean)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
  WITH cfg AS (
    SELECT
      COALESCE((SELECT (value->>'radius_default_km')::double precision FROM public.platform_configs WHERE key='hyperlocal' AND scope='global' ORDER BY version DESC LIMIT 1), 3) AS def_km,
      COALESCE((SELECT (value->>'max_radius_km')::double precision FROM public.platform_configs WHERE key='hyperlocal' AND scope='global' ORDER BY version DESC LIMIT 1), 10) AS max_km
  ), r AS (
    SELECT LEAST(COALESCE(p_radius_km, cfg.def_km), cfg.max_km) AS km FROM cfg
  ), pt AS (
    SELECT CASE
      WHEN p_lat IS NULL OR p_lng IS NULL THEN NULL
      ELSE st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
    END AS g
  ), eff AS (
    SELECT
      o.id, o.name, o.is_open, o.delivery_rules,
      COALESCE(l.latitude, o.latitude) AS eff_lat,
      COALESCE(l.longitude, o.longitude) AS eff_lng
    FROM public.outlets o
    LEFT JOIN public.outlet_locations l ON l.outlet_id = o.id
  )
  SELECT
    e.id AS outlet_id,
    e.name AS outlet_name,
    p.id AS product_id,
    p.name AS product_name,
    p.category,
    p.base_price AS price,
    p.stock,
    p.unit,
    CASE
      WHEN pt.g IS NULL OR e.eff_lat IS NULL OR e.eff_lng IS NULL THEN NULL
      ELSE (st_distance(st_setsrid(st_makepoint(e.eff_lng, e.eff_lat), 4326)::geography, pt.g) / 1000.0)
    END AS distance_km,
    COALESCE((e.delivery_rules->>'enabled')::boolean, false) AS has_delivery,
    e.is_open,
    COALESCE(p.is_service, false) AS is_service
  FROM public.products p
  JOIN eff e ON e.id = p.outlet_id, pt, r
  WHERE p.is_published = true
    AND (COALESCE(p.is_service, false) OR p.stock > 0)
    AND COALESCE(p_query, '') <> ''
    AND (
      p.name ILIKE '%' || p_query || '%'
      OR COALESCE(p.category, '') ILIKE '%' || p_query || '%'
      OR e.name ILIKE '%' || p_query || '%'
    )
    AND (
      pt.g IS NULL OR e.eff_lat IS NULL OR e.eff_lng IS NULL
      OR st_dwithin(st_setsrid(st_makepoint(e.eff_lng, e.eff_lat), 4326)::geography, pt.g, r.km * 1000)
    )
  ORDER BY distance_km ASC NULLS LAST, p.name ASC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 40), 100));
$function$;

-- ---------------------------------------------------------------------------
-- search_marketplace (6 arg): layanan tetap tampil walau stok 0 (+ is_service)
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.search_marketplace(text, double precision, double precision, double precision, integer, text);
CREATE FUNCTION public.search_marketplace(
  p_query text,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL,
  p_radius_km double precision DEFAULT NULL,
  p_limit integer DEFAULT 40,
  p_business_type text DEFAULT NULL
)
RETURNS TABLE(outlet_id uuid, outlet_name text, outlet_type text, product_id uuid,
              product_name text, category text, price numeric, stock numeric,
              unit text, distance_km double precision, has_delivery boolean,
              is_open boolean, is_service boolean)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
  WITH cfg AS (
    SELECT
      COALESCE((SELECT (value->>'radius_default_km')::double precision FROM public.platform_configs WHERE key='hyperlocal' AND scope='global' ORDER BY version DESC LIMIT 1), 3) AS def_km,
      COALESCE((SELECT (value->>'max_radius_km')::double precision FROM public.platform_configs WHERE key='hyperlocal' AND scope='global' ORDER BY version DESC LIMIT 1), 10) AS max_km
  ), r AS (
    SELECT LEAST(COALESCE(p_radius_km, cfg.def_km), cfg.max_km) AS km FROM cfg
  ), pt AS (
    SELECT CASE
      WHEN p_lat IS NULL OR p_lng IS NULL THEN NULL
      ELSE st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
    END AS g
  ), eff AS (
    SELECT
      o.id, o.name, o.type, o.is_open, o.delivery_rules,
      COALESCE(l.latitude, o.latitude) AS eff_lat,
      COALESCE(l.longitude, o.longitude) AS eff_lng
    FROM public.outlets o
    LEFT JOIN public.outlet_locations l ON l.outlet_id = o.id
  )
  SELECT
    e.id AS outlet_id,
    e.name AS outlet_name,
    e.type AS outlet_type,
    p.id AS product_id,
    p.name AS product_name,
    p.category,
    p.base_price AS price,
    p.stock,
    p.unit,
    CASE
      WHEN pt.g IS NULL OR e.eff_lat IS NULL OR e.eff_lng IS NULL THEN NULL
      ELSE (st_distance(st_setsrid(st_makepoint(e.eff_lng, e.eff_lat), 4326)::geography, pt.g) / 1000.0)
    END AS distance_km,
    COALESCE((e.delivery_rules->>'enabled')::boolean, false) AS has_delivery,
    e.is_open,
    COALESCE(p.is_service, false) AS is_service
  FROM public.products p
  JOIN eff e ON e.id = p.outlet_id, pt, r
  WHERE p.is_published = true
    AND (COALESCE(p.is_service, false) OR p.stock > 0)
    AND (
      COALESCE(p_query, '') <> ''
      OR COALESCE(p_business_type, '') <> ''
    )
    AND (
      COALESCE(p_query, '') = ''
      OR p.name ILIKE '%' || p_query || '%'
      OR COALESCE(p.category, '') ILIKE '%' || p_query || '%'
      OR e.name ILIKE '%' || p_query || '%'
    )
    AND (
      COALESCE(p_business_type, '') = ''
      OR COALESCE(e.type, '') ILIKE '%' || p_business_type || '%'
    )
    AND (
      pt.g IS NULL OR e.eff_lat IS NULL OR e.eff_lng IS NULL
      OR st_dwithin(st_setsrid(st_makepoint(e.eff_lng, e.eff_lat), 4326)::geography, pt.g, r.km * 1000)
    )
  ORDER BY distance_km ASC NULLS LAST, p.name ASC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 40), 100));
$function$;

GRANT EXECUTE ON FUNCTION public.get_public_catalog(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_public_menu(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.search_marketplace(text, double precision, double precision, double precision, integer) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.search_marketplace(text, double precision, double precision, double precision, integer, text) TO anon, authenticated, service_role;
