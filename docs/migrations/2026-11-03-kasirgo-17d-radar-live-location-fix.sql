-- KasirGo Phase 17D - Fix radar Pembeli: nearby_outlets pakai koordinat LIVE.
--
-- Masalah: Lapak Live (owner) menyimpan posisi gerobak di tabel `outlet_locations`
-- (via LocationService.updateOutletLocation, termasuk tombol "Deteksi lokasi" dan
-- broadcast 60 detik), sedangkan RPC `nearby_outlets` hanya membaca
-- `outlets.latitude/longitude` (kolom statis). Akibatnya outlet yang baru
-- menyalakan Lapak Live TIDAK muncul di radar Pembeli (koordinat statis NULL).
--
-- Perbaikan: `nearby_outlets` memakai koordinat efektif =
-- COALESCE(outlet_locations.latitude, outlets.latitude). Ini otomatis
-- memperbaiki jalur koordinat manual maupun "Deteksi lokasi", dan gerobak
-- bergerak akan mengikuti posisi live terbaru.
--
-- Idempoten. Signature & return type tidak berubah dari 17c
-- (tetap menyertakan service_queue_enabled).

CREATE OR REPLACE FUNCTION public.nearby_outlets(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision DEFAULT NULL
)
RETURNS TABLE(
  id uuid,
  name text,
  type text,
  address text,
  phone text,
  is_open boolean,
  is_mobile boolean,
  latitude double precision,
  longitude double precision,
  distance_km double precision,
  queue_count integer,
  has_delivery boolean,
  service_queue_enabled boolean
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
    SELECT st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography AS g
  ), eff AS (
    SELECT
      o.id, o.name, o.type, o.address, o.phone, o.is_open, o.is_mobile,
      o.delivery_rules, o.service_queue_enabled,
      COALESCE(l.latitude, o.latitude) AS eff_lat,
      COALESCE(l.longitude, o.longitude) AS eff_lng
    FROM public.outlets o
    LEFT JOIN public.outlet_locations l ON l.outlet_id = o.id
  )
  SELECT
    e.id, e.name, e.type, e.address, e.phone, e.is_open, e.is_mobile,
    e.eff_lat AS latitude, e.eff_lng AS longitude,
    (st_distance(st_setsrid(st_makepoint(e.eff_lng, e.eff_lat), 4326)::geography, pt.g) / 1000.0) AS distance_km,
    (SELECT count(*)::int FROM public.service_queue q WHERE q.outlet_id = e.id AND q.status = 'menunggu') AS queue_count,
    COALESCE((e.delivery_rules->>'enabled')::boolean, false) AS has_delivery,
    COALESCE(e.service_queue_enabled, false) AS service_queue_enabled
  FROM eff e, pt, r
  WHERE e.eff_lat IS NOT NULL AND e.eff_lng IS NOT NULL
    AND st_dwithin(st_setsrid(st_makepoint(e.eff_lng, e.eff_lat), 4326)::geography, pt.g, r.km * 1000)
  ORDER BY distance_km ASC;
$function$;

GRANT EXECUTE ON FUNCTION public.nearby_outlets(double precision, double precision, double precision) TO anon, authenticated;
