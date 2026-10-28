-- KasirGo: lampiran (gambar/file) pada Tiket Support
-- Tabel metadata + bucket privat `support-attachments` + RLS.
-- Path objek: {outlet_id}/{ticket_id}/{uuid}_{filename}

create table if not exists public.support_ticket_attachments (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  reply_id uuid references public.support_ticket_replies(id) on delete cascade,
  outlet_id uuid not null references public.outlets(id) on delete cascade,
  uploaded_by uuid references auth.users(id) on delete set null,
  file_name text not null,
  mime_type text,
  size_bytes bigint not null default 0,
  storage_path text not null unique,
  created_at timestamptz not null default now()
);

create index if not exists idx_support_attach_ticket
  on public.support_ticket_attachments(ticket_id, created_at);
create index if not exists idx_support_attach_outlet
  on public.support_ticket_attachments(outlet_id);

alter table public.support_ticket_attachments enable row level security;

drop policy if exists support_attach_select on public.support_ticket_attachments;
create policy support_attach_select on public.support_ticket_attachments
  for select to authenticated
  using (public.is_outlet_member(outlet_id) or public.is_platform_admin());

drop policy if exists support_attach_insert on public.support_ticket_attachments;
create policy support_attach_insert on public.support_ticket_attachments
  for insert to authenticated
  with check (
    (public.is_outlet_member(outlet_id) and uploaded_by = auth.uid())
    or public.is_platform_admin()
  );

drop policy if exists support_attach_delete on public.support_ticket_attachments;
create policy support_attach_delete on public.support_ticket_attachments
  for delete to authenticated
  using (public.is_platform_admin() or uploaded_by = auth.uid());

grant select, insert, update, delete on public.support_ticket_attachments
  to authenticated, service_role;

-- Bucket privat untuk lampiran tiket (maks 10 MB per file).
insert into storage.buckets (id, name, public, file_size_limit)
values ('support-attachments', 'support-attachments', false, 10485760)
on conflict (id) do update
  set public = false,
      file_size_limit = 10485760;

drop policy if exists support_attach_obj_select on storage.objects;
create policy support_attach_obj_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'support-attachments'
    and (
      public.is_platform_admin()
      or public.is_outlet_member(((storage.foldername(name))[1])::uuid)
    )
  );

drop policy if exists support_attach_obj_insert on storage.objects;
create policy support_attach_obj_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'support-attachments'
    and public.is_outlet_member(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists support_attach_obj_delete on storage.objects;
create policy support_attach_obj_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'support-attachments'
    and public.is_platform_admin()
  );