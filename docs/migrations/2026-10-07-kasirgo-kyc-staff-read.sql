-- Phase 13C fix: izinkan staf (admin/kasir) membaca STATUS KYC outlet mereka
-- tanpa membuka PII (foto KTP/selfie). RLS `outlet_kyc` sengaja hanya membuka
-- baris penuh ke owner; staf cukup butuh status agar KycGate tidak salah blokir.

create or replace function public.get_outlet_kyc_status(p_outlet uuid)
returns text
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce(
           (select k.status from public.outlet_kyc k where k.outlet_id = p_outlet),
           'unsubmitted')
  where public.is_outlet_member(p_outlet) or public.is_platform_admin();
$$;

revoke all on function public.get_outlet_kyc_status(uuid) from public;
grant execute on function public.get_outlet_kyc_status(uuid) to authenticated;
