-- KasirGo Phase 17E - Marketplace Search (Pembeli).
--
-- Tujuan: Pembeli dapat mencari PRODUK di seluruh warung/gerobak sekitar,
-- bukan hanya menelusuri radar satu per satu. Hasil menggabungkan produk
-- publik (`products.is_published` + stok > 0) dengan info outlet + jarak.
--
-- Desain:
--   - RPC `search_marketplace(p_query, p_lat, p_lng, p_radius_km, p_limit)`.
--   - SECURITY DEFINER + data publik saja (tanpa harga beli/HPP, tanpa staf).
--   - Cocokkan nama produk, kategori, atau nama outlet (ILIKE, case-insensitive).
--   - Bila lokasi diberikan -> dibatasi radius (default/max dari platform_configs
--     `hyperlocal`, sama dengan nearby_outlets). Bila tidak -> tanpa radius,
--     distance_km NULL (urut nama).
--   - Idempoten (CREATE OR REPLACE).

CREATE OR REPLACE FUNCTION public.search_marketplace(
  p_query text,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL,
  p_radius_km double precision DEFAULT NULL,
  p_limit integer DEFAULT 40
)
RETURNS TABLE(
  outlet_id uuid,
  outlet_name text,
  product_id uuid,
  product_name text,
  category text,
  price numeric,
  stock numeric,
  unit text,
  distance_km double precision,
  has_delivery boolean,
  is_open boolean
)
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
    e.is_open
  FROM public.products p
  JOIN eff e ON e.id = p.outlet_id, pt, r
  WHERE p.is_published = true
    AND p.stock > 0
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

GRANT EXECUTE ON FUNCTION public.search_marketplace(text, double precision, double precision, double precision, integer) TO anon, authenticated;

-- ============================================================================
-- VERIFIKASI:
--   SELECT * FROM public.search_marketplace('kopi', -6.2, 106.8, 5);
--   SELECT * FROM public.search_marketplace('roti');  -- tanpa lokasi
-- ============================================================================
