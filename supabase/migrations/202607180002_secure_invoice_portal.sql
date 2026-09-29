-- Production hardening for the invoice -> tenant portal -> payment proof flow.
-- This migration deliberately removes the anonymous policies installed by
-- 202607020001_rentflow_public_test.sql while preserving existing test rows.

alter table public.rentflow_test_invoices
  add column if not exists owner_id uuid references public.profiles(id) on delete cascade,
  add column if not exists portal_token_hash text,
  add column if not exists portal_expires_at timestamptz;

-- The current application has one owner. Associate legacy test invoices with
-- that owner so they remain visible after RLS is tightened. If no owner exists,
-- the rows remain inaccessible until an administrator assigns owner_id.
do $$
declare
  first_owner uuid;
begin
  select id into first_owner
  from public.profiles
  where role = 'owner'
  order by created_at
  limit 1;

  if first_owner is not null then
    update public.rentflow_test_invoices
    set owner_id = first_owner
    where owner_id is null;
  end if;
end $$;

alter table public.rentflow_test_invoices
  alter column owner_id set default auth.uid();

create index if not exists rentflow_test_invoices_owner_idx
  on public.rentflow_test_invoices (owner_id, created_at desc);
create index if not exists rentflow_test_invoices_portal_token_idx
  on public.rentflow_test_invoices (portal_token_hash)
  where portal_token_hash is not null;

alter table public.rentflow_test_invoices enable row level security;

create or replace function public.is_owner()
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'owner'
  );
$$;

-- A signed-in user may edit their own profile details but must never be able
-- to promote themselves from tenant/agent to owner. Role changes are reserved
-- for trusted service-role administration.
create or replace function public.prevent_profile_role_escalation()
returns trigger language plpgsql set search_path = public
as $$
begin
  if new.role is distinct from old.role
     and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Account roles can only be changed by an administrator.';
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_profile_role_escalation on public.profiles;
create trigger prevent_profile_role_escalation
  before update of role on public.profiles
  for each row execute procedure public.prevent_profile_role_escalation();

create or replace function public.owns_tenancy(target uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.tenancies
    where id = target and tenant_id = auth.uid()
  );
$$;

-- Keep owner operating costs private. A tenant only needs their own bills,
-- requests and tenancy documents, not facility-wide commitments or cashflow.
drop policy if exists "commitments read accessible" on public.recurring_commitments;
drop policy if exists "commitments owners read" on public.recurring_commitments;
create policy "commitments owners read"
on public.recurring_commitments for select to authenticated
using (public.owns_facility(facility_id));

drop policy if exists "transactions read accessible" on public.transactions;
drop policy if exists "transactions owners read" on public.transactions;
create policy "transactions owners read"
on public.transactions for select to authenticated
using (public.owns_facility(facility_id));

-- Bill approval and request status are owner decisions. Tenant payment proof
-- is accepted through the validated invoice-portal function instead of a broad
-- table update policy.
drop policy if exists "bills participants update" on public.bills;
drop policy if exists "bills owners update" on public.bills;
create policy "bills owners update"
on public.bills for update to authenticated
using (public.owns_facility(facility_id))
with check (public.owns_facility(facility_id));

drop policy if exists "request participants update" on public.tenant_requests;
drop policy if exists "request owners update" on public.tenant_requests;
create policy "request owners update"
on public.tenant_requests for update to authenticated
using (public.owns_facility(facility_id))
with check (public.owns_facility(facility_id));

drop policy if exists "documents read accessible" on public.documents;
drop policy if exists "documents participants insert" on public.documents;
drop policy if exists "documents uploader or owner delete" on public.documents;
drop policy if exists "documents read own tenancy or owner" on public.documents;
drop policy if exists "documents insert own tenancy or owner" on public.documents;
drop policy if exists "documents delete uploader or owner" on public.documents;

create policy "documents read own tenancy or owner"
on public.documents for select to authenticated
using (
  public.owns_facility(facility_id)
  or uploaded_by = auth.uid()
  or (tenancy_id is not null and public.owns_tenancy(tenancy_id))
);

create policy "documents insert own tenancy or owner"
on public.documents for insert to authenticated
with check (
  uploaded_by = auth.uid()
  and (
    public.owns_facility(facility_id)
    or (tenancy_id is not null and public.owns_tenancy(tenancy_id))
  )
);

create policy "documents delete uploader or owner"
on public.documents for delete to authenticated
using (uploaded_by = auth.uid() or public.owns_facility(facility_id));

drop policy if exists "rental files read accessible" on storage.objects;
drop policy if exists "rental files upload accessible" on storage.objects;
drop policy if exists "rental files delete accessible" on storage.objects;
drop policy if exists "rental files read own tenancy or owner" on storage.objects;
drop policy if exists "rental files upload own tenancy or owner" on storage.objects;
drop policy if exists "rental files delete uploader or owner" on storage.objects;

create policy "rental files read own tenancy or owner"
on storage.objects for select to authenticated
using (
  bucket_id = 'rental-documents'
  and (
    public.owns_facility(((storage.foldername(name))[1])::uuid)
    or exists (
      select 1 from public.documents d
      where d.storage_path = name
        and (
          d.uploaded_by = auth.uid()
          or (d.tenancy_id is not null and public.owns_tenancy(d.tenancy_id))
        )
    )
  )
);

create policy "rental files upload own tenancy or owner"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'rental-documents'
  and (
    public.owns_facility(((storage.foldername(name))[1])::uuid)
    or exists (
      select 1 from public.tenancies t
      where t.facility_id = ((storage.foldername(name))[1])::uuid
        and t.tenant_id = auth.uid()
    )
  )
);

create policy "rental files delete uploader or owner"
on storage.objects for delete to authenticated
using (
  bucket_id = 'rental-documents'
  and (
    public.owns_facility(((storage.foldername(name))[1])::uuid)
    or exists (
      select 1 from public.documents d
      where d.storage_path = name and d.uploaded_by = auth.uid()
    )
  )
);

drop policy if exists "TEMP public test read invoices" on public.rentflow_test_invoices;
drop policy if exists "TEMP public test insert invoices" on public.rentflow_test_invoices;
drop policy if exists "TEMP public test update invoices" on public.rentflow_test_invoices;
drop policy if exists "owners read own rentflow invoices" on public.rentflow_test_invoices;
drop policy if exists "owners create own rentflow invoices" on public.rentflow_test_invoices;
drop policy if exists "owners update own rentflow invoices" on public.rentflow_test_invoices;
drop policy if exists "owners delete own rentflow invoices" on public.rentflow_test_invoices;

create policy "owners read own rentflow invoices"
on public.rentflow_test_invoices for select to authenticated
using (owner_id = auth.uid() and public.is_owner());

create policy "owners create own rentflow invoices"
on public.rentflow_test_invoices for insert to authenticated
with check (owner_id = auth.uid() and public.is_owner());

create policy "owners update own rentflow invoices"
on public.rentflow_test_invoices for update to authenticated
using (owner_id = auth.uid() and public.is_owner())
with check (owner_id = auth.uid() and public.is_owner());

create policy "owners delete own rentflow invoices"
on public.rentflow_test_invoices for delete to authenticated
using (owner_id = auth.uid() and public.is_owner());

-- Invoice PDFs, meter photos and payment proofs contain private tenant data.
-- Keep the bucket private and let authenticated owners access only the folder
-- named with their own auth user id. The portal Edge Function uses the service
-- role to issue expiring PDF URLs and accept a single validated payment proof.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'rentflow-test-files',
  'rentflow-test-files',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'application/pdf']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "TEMP public test read files" on storage.objects;
drop policy if exists "TEMP public test upload files" on storage.objects;
drop policy if exists "TEMP public test update files" on storage.objects;
drop policy if exists "owners read own rentflow files" on storage.objects;
drop policy if exists "owners upload own rentflow files" on storage.objects;
drop policy if exists "owners update own rentflow files" on storage.objects;
drop policy if exists "owners delete own rentflow files" on storage.objects;

create policy "owners read own rentflow files"
on storage.objects for select to authenticated
using (
  bucket_id = 'rentflow-test-files'
  and (storage.foldername(name))[1] = auth.uid()::text
  and public.is_owner()
);

create policy "owners upload own rentflow files"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'rentflow-test-files'
  and (storage.foldername(name))[1] = auth.uid()::text
  and public.is_owner()
);

create policy "owners update own rentflow files"
on storage.objects for update to authenticated
using (
  bucket_id = 'rentflow-test-files'
  and (storage.foldername(name))[1] = auth.uid()::text
  and public.is_owner()
)
with check (
  bucket_id = 'rentflow-test-files'
  and (storage.foldername(name))[1] = auth.uid()::text
  and public.is_owner()
);

create policy "owners delete own rentflow files"
on storage.objects for delete to authenticated
using (
  bucket_id = 'rentflow-test-files'
  and (storage.foldername(name))[1] = auth.uid()::text
  and public.is_owner()
);
