-- Rental Facility Manager: initial shared-data schema.
-- Run this entire file once in Supabase SQL Editor.

create extension if not exists pgcrypto;

create type public.app_role as enum ('owner', 'property_agent', 'tenant');
create type public.payment_status as enum (
  'not_submitted',
  'pending_tenant_payment',
  'pending_approval',
  'approved',
  'rejected'
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null,
  role public.app_role not null default 'tenant',
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.facilities (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  address_line text not null,
  postcode text not null,
  city text not null,
  state text not null,
  status text not null default 'active' check (status in ('active', 'sold')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.tenancies (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references public.facilities(id) on delete cascade,
  tenant_id uuid references public.profiles(id) on delete set null,
  tenant_email text not null,
  unit_name text not null,
  monthly_rent numeric(12,2) not null check (monthly_rent >= 0),
  lease_start date not null,
  lease_end date not null check (lease_end >= lease_start),
  electricity_included boolean not null default false,
  water_included boolean not null default false,
  internet_included boolean not null default false,
  car_park_details text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.recurring_commitments (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references public.facilities(id) on delete cascade,
  name text not null,
  amount numeric(12,2) not null check (amount >= 0),
  frequency text not null check (frequency in ('monthly', 'quarterly', 'half_yearly', 'yearly')),
  first_due_month smallint not null check (first_due_month between 1 and 12),
  effective_from date not null,
  effective_until date,
  created_at timestamptz not null default now()
);

create table public.bills (
  id uuid primary key default gen_random_uuid(),
  tenancy_id uuid not null references public.tenancies(id) on delete cascade,
  facility_id uuid not null references public.facilities(id) on delete cascade,
  tenant_id uuid references public.profiles(id) on delete set null,
  bill_month date not null,
  rent_amount numeric(12,2) not null default 0,
  electricity_amount numeric(12,2) not null default 0,
  water_amount numeric(12,2) not null default 0,
  internet_amount numeric(12,2) not null default 0,
  amount_paid numeric(12,2) not null default 0,
  status public.payment_status not null default 'not_submitted',
  utility_evidence_path text,
  payment_evidence_path text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenancy_id, bill_month)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references public.facilities(id) on delete cascade,
  transaction_month date not null,
  direction text not null check (direction in ('income', 'expense')),
  category text not null,
  amount numeric(12,2) not null check (amount >= 0),
  note text,
  recurring_commitment_id uuid references public.recurring_commitments(id) on delete set null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.tenant_requests (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references public.facilities(id) on delete cascade,
  tenancy_id uuid not null references public.tenancies(id) on delete cascade,
  tenant_id uuid not null references public.profiles(id) on delete cascade,
  request_type text not null,
  title text not null,
  message text not null,
  status text not null default 'open' check (status in ('open', 'in_progress', 'closed', 'rejected')),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references public.facilities(id) on delete cascade,
  tenancy_id uuid references public.tenancies(id) on delete cascade,
  uploaded_by uuid not null references public.profiles(id),
  document_type text not null,
  storage_path text not null unique,
  original_name text not null,
  created_at timestamptz not null default now()
);

create or replace function public.is_manager()
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('owner', 'property_agent')
  );
$$;

create or replace function public.owns_facility(target uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.facilities
    where id = target and owner_id = auth.uid()
  );
$$;

create or replace function public.can_access_facility(target uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select public.owns_facility(target) or exists (
    select 1 from public.tenancies
    where facility_id = target and tenant_id = auth.uid()
  );
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
declare
  requested_role public.app_role;
begin
  requested_role := case
    when new.raw_user_meta_data ->> 'role' in ('owner', 'property_agent', 'tenant')
      then (new.raw_user_meta_data ->> 'role')::public.app_role
    else 'tenant'::public.app_role
  end;

  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), split_part(coalesce(new.email, 'User'), '@', 1)),
    requested_role
  );

  update public.tenancies
  set tenant_id = new.id, updated_at = now()
  where lower(tenant_email) = lower(coalesce(new.email, '')) and tenant_id is null;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.facilities enable row level security;
alter table public.tenancies enable row level security;
alter table public.recurring_commitments enable row level security;
alter table public.bills enable row level security;
alter table public.transactions enable row level security;
alter table public.tenant_requests enable row level security;
alter table public.documents enable row level security;

create policy "profiles read own or linked tenant" on public.profiles for select
using (
  id = auth.uid() or exists (
    select 1 from public.tenancies t
    join public.facilities f on f.id = t.facility_id
    where t.tenant_id = profiles.id and f.owner_id = auth.uid()
  )
);
create policy "profiles update own" on public.profiles for update
using (id = auth.uid()) with check (id = auth.uid());

create policy "facilities read accessible" on public.facilities for select
using (public.can_access_facility(id));
create policy "facilities managers insert" on public.facilities for insert
with check (owner_id = auth.uid() and public.is_manager());
create policy "facilities owners update" on public.facilities for update
using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "facilities owners delete" on public.facilities for delete
using (owner_id = auth.uid());

create policy "tenancies read accessible" on public.tenancies for select
using (tenant_id = auth.uid() or public.owns_facility(facility_id));
create policy "tenancies owners insert" on public.tenancies for insert
with check (public.owns_facility(facility_id));
create policy "tenancies owners update" on public.tenancies for update
using (public.owns_facility(facility_id)) with check (public.owns_facility(facility_id));
create policy "tenancies owners delete" on public.tenancies for delete
using (public.owns_facility(facility_id));

create policy "commitments read accessible" on public.recurring_commitments for select
using (public.can_access_facility(facility_id));
create policy "commitments owners manage" on public.recurring_commitments for all
using (public.owns_facility(facility_id)) with check (public.owns_facility(facility_id));

create policy "bills read accessible" on public.bills for select
using (tenant_id = auth.uid() or public.owns_facility(facility_id));
create policy "bills owners insert" on public.bills for insert
with check (public.owns_facility(facility_id));
create policy "bills participants update" on public.bills for update
using (tenant_id = auth.uid() or public.owns_facility(facility_id))
with check (tenant_id = auth.uid() or public.owns_facility(facility_id));

create policy "transactions read accessible" on public.transactions for select
using (public.can_access_facility(facility_id));
create policy "transactions owners manage" on public.transactions for all
using (public.owns_facility(facility_id)) with check (public.owns_facility(facility_id));

create policy "requests read accessible" on public.tenant_requests for select
using (tenant_id = auth.uid() or public.owns_facility(facility_id));
create policy "tenants create requests" on public.tenant_requests for insert
with check (tenant_id = auth.uid() and public.can_access_facility(facility_id));
create policy "request participants update" on public.tenant_requests for update
using (tenant_id = auth.uid() or public.owns_facility(facility_id))
with check (tenant_id = auth.uid() or public.owns_facility(facility_id));

create policy "documents read accessible" on public.documents for select
using (public.can_access_facility(facility_id));
create policy "documents participants insert" on public.documents for insert
with check (uploaded_by = auth.uid() and public.can_access_facility(facility_id));
create policy "documents uploader or owner delete" on public.documents for delete
using (uploaded_by = auth.uid() or public.owns_facility(facility_id));

insert into storage.buckets (id, name, public)
values ('rental-documents', 'rental-documents', false)
on conflict (id) do nothing;

create policy "rental files read accessible" on storage.objects for select
using (
  bucket_id = 'rental-documents'
  and public.can_access_facility(((storage.foldername(name))[1])::uuid)
);
create policy "rental files upload accessible" on storage.objects for insert
with check (
  bucket_id = 'rental-documents'
  and public.can_access_facility(((storage.foldername(name))[1])::uuid)
);
create policy "rental files delete accessible" on storage.objects for delete
using (
  bucket_id = 'rental-documents'
  and public.can_access_facility(((storage.foldername(name))[1])::uuid)
);
