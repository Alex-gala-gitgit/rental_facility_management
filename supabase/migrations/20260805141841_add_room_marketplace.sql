-- Cross-owner room marketplace for the tenant Explore tab.
-- Only signed-in owners/property agents may publish. Signed-in users can read
-- published posts, while publishers retain access to their own drafts.

create table if not exists public.room_listings (
  id uuid primary key default gen_random_uuid(),
  publisher_id uuid not null references public.profiles(id) on delete cascade,
  publisher_name text not null,
  publisher_role text not null check (publisher_role in ('owner', 'property_agent')),
  source_facility_id text,
  title text not null check (char_length(title) between 5 and 120),
  description text not null default '' check (char_length(description) <= 3000),
  property_type text not null default 'Condominium',
  room_type text not null default 'Private room',
  monthly_rent numeric(12,2) not null check (monthly_rent > 0),
  deposit_amount numeric(12,2) not null default 0 check (deposit_amount >= 0),
  address_line text not null default '',
  postcode text not null default '',
  city text not null,
  state text not null,
  bedrooms smallint not null default 1 check (bedrooms between 0 and 30),
  bathrooms smallint not null default 1 check (bathrooms between 0 and 30),
  furnishing text not null default 'Partly furnished',
  gender_preference text not null default 'Any',
  available_from date not null default current_date,
  amenities text[] not null default '{}',
  image_paths text[] not null default '{}',
  contact_name text not null,
  contact_phone text not null,
  status text not null default 'draft'
    check (status in ('draft', 'published', 'rented', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists room_listings_public_feed_idx
  on public.room_listings (status, created_at desc);
create index if not exists room_listings_location_idx
  on public.room_listings (state, city);
create index if not exists room_listings_publisher_idx
  on public.room_listings (publisher_id, updated_at desc);

create schema if not exists private;

create or replace function private.set_room_listing_publisher()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  publisher public.profiles%rowtype;
begin
  select * into publisher
  from public.profiles
  where id = auth.uid() and role in ('owner', 'property_agent');

  if publisher.id is null then
    raise exception 'Only an owner or property agent can publish a room listing.';
  end if;

  new.publisher_id := publisher.id;
  new.publisher_name := publisher.full_name;
  new.publisher_role := publisher.role::text;
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function private.set_room_listing_publisher()
  from public, anon, authenticated, service_role;

drop trigger if exists set_room_listing_publisher on public.room_listings;
create trigger set_room_listing_publisher
  before insert or update on public.room_listings
  for each row execute function private.set_room_listing_publisher();

alter table public.room_listings enable row level security;

drop policy if exists "published rooms are visible to signed in users" on public.room_listings;
create policy "published rooms are visible to signed in users"
on public.room_listings for select
to authenticated
using (status = 'published' or publisher_id = (select auth.uid()));

drop policy if exists "managers create their room listings" on public.room_listings;
create policy "managers create their room listings"
on public.room_listings for insert
to authenticated
with check (
  publisher_id = (select auth.uid())
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('owner', 'property_agent')
  )
);

drop policy if exists "publishers update their room listings" on public.room_listings;
create policy "publishers update their room listings"
on public.room_listings for update
to authenticated
using (publisher_id = (select auth.uid()))
with check (
  publisher_id = (select auth.uid())
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('owner', 'property_agent')
  )
);

drop policy if exists "publishers delete their room listings" on public.room_listings;
create policy "publishers delete their room listings"
on public.room_listings for delete
to authenticated
using (publisher_id = (select auth.uid()));

grant select, insert, update, delete on public.room_listings to authenticated;
grant all on public.room_listings to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'room-listings',
  'room-listings',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "signed in users view listing photos" on storage.objects;
create policy "signed in users view listing photos"
on storage.objects for select
to authenticated
using (bucket_id = 'room-listings');

drop policy if exists "managers upload listing photos" on storage.objects;
create policy "managers upload listing photos"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'room-listings'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('owner', 'property_agent')
  )
);

drop policy if exists "managers replace listing photos" on storage.objects;
create policy "managers replace listing photos"
on storage.objects for update
to authenticated
using (
  bucket_id = 'room-listings'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'room-listings'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "managers delete listing photos" on storage.objects;
create policy "managers delete listing photos"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'room-listings'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
