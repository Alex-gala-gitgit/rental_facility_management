create table public.move_out_settlements (
 owner_id uuid not null references public.profiles(id),
 record_key text not null,
 tenant_id text,
 tenancy_id text,
 facility_id text,
 payload jsonb not null,
 pdf_path text not null,
 revision integer not null default 1,
 updated_at timestamptz not null default now(),
 primary key(owner_id, record_key),
 check (pdf_path like owner_id::text || '/%')
);
alter table public.move_out_settlements enable row level security;
grant select, insert, update on public.move_out_settlements to authenticated;
create policy "settlement owner read" on public.move_out_settlements for select to authenticated
 using (owner_id = (select auth.uid()) and public.is_owner());
create policy "settlement owner insert" on public.move_out_settlements for insert to authenticated
 with check (owner_id = (select auth.uid()) and public.is_owner());
create policy "settlement owner update" on public.move_out_settlements for update to authenticated
 using (owner_id = (select auth.uid()) and public.is_owner())
 with check (owner_id = (select auth.uid()) and public.is_owner());
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values ('move-out-settlements','move-out-settlements',false,26214400,array['application/pdf']);
create policy "settlement file read" on storage.objects for select to authenticated
 using (bucket_id='move-out-settlements' and (storage.foldername(name))[1]=(select auth.uid())::text and public.is_owner());
create policy "settlement file insert" on storage.objects for insert to authenticated
 with check (bucket_id='move-out-settlements' and (storage.foldername(name))[1]=(select auth.uid())::text and public.is_owner());
create policy "settlement file delete" on storage.objects for delete to authenticated
 using (bucket_id='move-out-settlements' and (storage.foldername(name))[1]=(select auth.uid())::text and public.is_owner());
