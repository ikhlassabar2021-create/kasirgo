-- KasirGo - Katalog Online Publik + Nomor WA Outlet
-- Tanggal: 2026-10-08
--
-- Latar belakang:
--   Katalog online publik (deep-link /#/catalog?outlet=<id>) perlu menampilkan
--   nomor WhatsApp toko agar pelanggan bisa memesan. Nomor tersimpan di
--   outlets.owner_wa_number (terlindungi RLS), sehingga pelanggan anonim perlu
--   RPC SECURITY DEFINER yang hanya mengembalikan nomor tersebut.
--
-- Aman: hanya mengembalikan owner_wa_number dari satu outlet; tanpa PII lain.

create or replace function public.get_public_outlet_wa(p_outlet text)
returns table(wa_number text)
language sql
security definer
set search_path to 'public'
as $$
  select coalesce(o.owner_wa_number, '') as wa_number
  from public.outlets o
  where o.id::text = p_outlet
  limit 1;
$$;

grant execute on function public.get_public_outlet_wa(text) to anon, authenticated;
