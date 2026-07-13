-- TEMPORARY PUBLIC TEST MODE.
-- This intentionally permits anonymous invoice access and uploads.
-- Remove the TEMP policies and make the bucket private before production.

create table if not exists public.rentflow_test_invoices (
  id text primary key,
  tenant_id text not null,
  tenant_name text not null,
  tenant_email text not null,
  tenant_phone text not null,
  property_name text not null,
  unit_name text not null,
  rent numeric(12,2) not null default 0,
  water numeric(12,2) not null default 0,
  internet numeric(12,2) not null default 0,
  period text not null,
  usage_period text not null,
  previous_reading numeric(12,2) not null,
  current_reading numeric(12,2) not null,
  evidence_name text not null,
  evidence_path text,
  due_date timestamptz not null,
  status text not null default 'sent'
    check (status in ('draft', 'sent', 'slipSubmitted', 'paid')),
  slip_name text,
  slip_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.rentflow_test_invoices enable row level security;

drop policy if exists "TEMP public test read invoices" on public.rentflow_test_invoices;
drop policy if exists "TEMP public test insert invoices" on public.rentflow_test_invoices;
drop policy if exists "TEMP public test update invoices" on public.rentflow_test_invoices;

create policy "TEMP public test read invoices"
on public.rentflow_test_invoices for select to anon, authenticated using (true);
create policy "TEMP public test insert invoices"
on public.rentflow_test_invoices for insert to anon, authenticated with check (true);
create policy "TEMP public test update invoices"
on public.rentflow_test_invoices for update to anon, authenticated using (true) with check (true);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'rentflow-test-files',
  'rentflow-test-files',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'application/pdf']
)
on conflict (id) do update set public = true;

drop policy if exists "TEMP public test read files" on storage.objects;
drop policy if exists "TEMP public test upload files" on storage.objects;
drop policy if exists "TEMP public test update files" on storage.objects;

create policy "TEMP public test read files"
on storage.objects for select to anon, authenticated
using (bucket_id = 'rentflow-test-files');
create policy "TEMP public test upload files"
on storage.objects for insert to anon, authenticated
with check (bucket_id = 'rentflow-test-files');
create policy "TEMP public test update files"
on storage.objects for update to anon, authenticated
using (bucket_id = 'rentflow-test-files')
with check (bucket_id = 'rentflow-test-files');

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'rentflow_test_invoices'
  ) then
    alter publication supabase_realtime add table public.rentflow_test_invoices;
  end if;
end $$;
