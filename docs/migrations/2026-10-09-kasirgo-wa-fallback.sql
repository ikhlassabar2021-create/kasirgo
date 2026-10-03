-- get_public_outlet_wa: fallback ke nomor KYC & outlet.phone bila
-- owner_wa_number kosong, supaya tombol "Pesan WA" katalog pelanggan
-- langsung berfungsi tanpa setting manual tambahan.
-- Prioritas: outlets.owner_wa_number -> outlet_kyc.phone -> outlets.phone.

CREATE OR REPLACE FUNCTION public.get_public_outlet_wa(p_outlet text)
RETURNS TABLE(wa_number text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select coalesce(
    nullif(o.owner_wa_number, ''),
    (select nullif(k.phone, '') from public.outlet_kyc k
      where k.outlet_id = o.id limit 1),
    nullif(o.phone, ''),
    ''
  ) as wa_number
  from public.outlets o
  where o.id::text = p_outlet
  limit 1;
$function$;

GRANT EXECUTE ON FUNCTION public.get_public_outlet_wa(text) TO anon, authenticated;
