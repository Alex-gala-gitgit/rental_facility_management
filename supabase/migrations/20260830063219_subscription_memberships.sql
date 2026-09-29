-- HomeOps360 subscription plans, manual payment verification and permanent
-- Diamond founder protection.

alter type public.app_role add value if not exists 'technician';

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.subscription_plans (
  code text primary key check (code in ('free', 'premium', 'diamond')),
  display_name text not null,
  monthly_price numeric(10,2),
  annual_price numeric(10,2),
  property_limit integer,
  tenant_limit integer,
  explore_listing_limit integer,
  electricity_tariff_enabled boolean not null,
  announcements_enabled boolean not null,
  marketplace_enabled boolean not null,
  priority_support_enabled boolean not null,
  publicly_selectable boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (monthly_price is null or monthly_price >= 0),
  check (annual_price is null or annual_price >= 0),
  check (property_limit is null or property_limit >= 0),
  check (tenant_limit is null or tenant_limit >= 0),
  check (explore_listing_limit is null or explore_listing_limit >= 0)
);

insert into public.subscription_plans (
  code,
  display_name,
  monthly_price,
  annual_price,
  property_limit,
  tenant_limit,
  explore_listing_limit,
  electricity_tariff_enabled,
  announcements_enabled,
  marketplace_enabled,
  priority_support_enabled,
  publicly_selectable
) values
  ('free', 'Free', 0, 0, 1, 4, 0, false, false, false, false, false),
  ('premium', 'Premium', 15.90, 99.90, 5, 30, 10, true, true, true, true, true),
  ('diamond', 'Diamond', null, null, null, null, null, true, true, true, true, false)
on conflict (code) do update set
  display_name = excluded.display_name,
  monthly_price = excluded.monthly_price,
  annual_price = excluded.annual_price,
  property_limit = excluded.property_limit,
  tenant_limit = excluded.tenant_limit,
  explore_listing_limit = excluded.explore_listing_limit,
  electricity_tariff_enabled = excluded.electricity_tariff_enabled,
  announcements_enabled = excluded.announcements_enabled,
  marketplace_enabled = excluded.marketplace_enabled,
  priority_support_enabled = excluded.priority_support_enabled,
  publicly_selectable = excluded.publicly_selectable,
  updated_at = now();

create table public.account_memberships (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  membership_tier text not null default 'free'
    check (membership_tier in ('free', 'premium', 'diamond')),
  subscription_status text not null default 'active'
    check (subscription_status in ('active', 'pending_verification', 'expired')),
  billing_period text check (billing_period is null or billing_period in ('monthly', 'annual')),
  started_at timestamptz,
  expires_at timestamptz,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (membership_tier <> 'diamond' or subscription_status = 'active')
);

create index account_memberships_updated_by_idx
  on public.account_memberships (updated_by)
  where updated_by is not null;
create index account_memberships_status_idx
  on public.account_memberships (subscription_status, membership_tier);

create table public.subscription_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  requested_tier text not null default 'premium'
    check (requested_tier = 'premium'),
  billing_period text not null check (billing_period in ('monthly', 'annual')),
  amount numeric(10,2) not null check (amount >= 0),
  currency text not null default 'MYR' check (currency = 'MYR'),
  payment_slip_path text not null,
  payment_slip_name text not null,
  status text not null default 'pending_verification'
    check (status in ('pending_verification', 'approved', 'rejected', 'cancelled')),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  admin_notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (payment_slip_path <> ''),
  check (payment_slip_name <> '')
);

create index subscription_requests_user_created_idx
  on public.subscription_requests (user_id, created_at desc);
create index subscription_requests_status_created_idx
  on public.subscription_requests (status, created_at desc);
create index subscription_requests_reviewed_by_idx
  on public.subscription_requests (reviewed_by)
  where reviewed_by is not null;
create unique index subscription_requests_one_pending_idx
  on public.subscription_requests (user_id)
  where status = 'pending_verification';

alter table public.owner_access_configs
  add column if not exists membership_tier text not null default 'free',
  add column if not exists subscription_status text not null default 'active',
  add column if not exists subscription_expires_at timestamptz,
  add column if not exists unlimited_access boolean not null default false,
  add column if not exists announcements_enabled boolean not null default false,
  add column if not exists marketplace_enabled boolean not null default false,
  add column if not exists priority_support_enabled boolean not null default false;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'owner_access_configs_membership_tier_check'
      and conrelid = 'public.owner_access_configs'::regclass
  ) then
    alter table public.owner_access_configs
      add constraint owner_access_configs_membership_tier_check
      check (membership_tier in ('free', 'premium', 'diamond'));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'owner_access_configs_subscription_status_check'
      and conrelid = 'public.owner_access_configs'::regclass
  ) then
    alter table public.owner_access_configs
      add constraint owner_access_configs_subscription_status_check
      check (subscription_status in ('active', 'pending_verification', 'expired'));
  end if;
end $$;

alter table public.subscription_plans enable row level security;
alter table public.account_memberships enable row level security;
alter table public.subscription_requests enable row level security;

revoke all on public.subscription_plans from anon, authenticated;
revoke all on public.account_memberships from anon, authenticated;
revoke all on public.subscription_requests from anon, authenticated;
grant select on public.subscription_plans to authenticated;
grant select on public.account_memberships to authenticated;
grant select, insert on public.subscription_requests to authenticated;

create policy "authenticated users read subscription plans"
on public.subscription_plans for select
to authenticated
using (true);

create policy "users read own membership"
on public.account_memberships for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "users read own subscription requests"
on public.subscription_requests for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "eligible users submit own subscription requests"
on public.subscription_requests for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and requested_tier = 'premium'
  and status = 'pending_verification'
  and split_part(payment_slip_path, '/', 1) = (select auth.uid())::text
  and exists (
    select 1
    from public.profiles profile
    where profile.id = (select auth.uid())
      and profile.role::text in ('owner', 'property_agent', 'technician')
  )
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'subscription-payment-slips',
  'subscription-payment-slips',
  false,
  10485760,
  array['image/png', 'image/jpeg', 'application/pdf']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "users upload own subscription payment slips" on storage.objects;
create policy "users upload own subscription payment slips"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'subscription-payment-slips'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "users read own subscription payment slips" on storage.objects;
create policy "users read own subscription payment slips"
on storage.objects for select
to authenticated
using (
  bucket_id = 'subscription-payment-slips'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create or replace function private.protect_diamond_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  account_email text;
  target_user_id uuid;
begin
  target_user_id := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
  select lower(profile.email)
  into account_email
  from public.profiles profile
  where profile.id = target_user_id;

  if tg_op = 'DELETE' then
    if old.membership_tier = 'diamond' or account_email = 'lauyikfei@gmail.com' then
      raise exception 'Diamond founder membership cannot be removed.';
    end if;
    return old;
  end if;

  if account_email = 'lauyikfei@gmail.com' then
    new.membership_tier := 'diamond';
    new.subscription_status := 'active';
    new.billing_period := null;
    new.expires_at := null;
  elsif tg_op = 'UPDATE' and old.membership_tier = 'diamond' and (
    new.membership_tier <> 'diamond'
    or new.subscription_status <> 'active'
    or new.expires_at is not null
  ) then
    raise exception 'Diamond membership cannot be downgraded or expired.';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

revoke execute on function private.protect_diamond_membership()
  from public, anon, authenticated;

create trigger protect_diamond_membership
before insert or update or delete on public.account_memberships
for each row execute function private.protect_diamond_membership();

create or replace function private.sync_membership_entitlements()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  plan_row public.subscription_plans%rowtype;
  effective_tier text;
begin
  effective_tier := case
    when new.membership_tier = 'diamond' then 'diamond'
    when new.membership_tier = 'premium'
      and new.subscription_status = 'active'
      and (new.expires_at is null or new.expires_at > now()) then 'premium'
    else 'free'
  end;

  select * into plan_row
  from public.subscription_plans
  where code = effective_tier;

  insert into public.owner_access_configs (
    owner_id,
    property_limit,
    tenant_limit,
    explore_listing_limit,
    electricity_tariff_enabled,
    explore_promotion_enabled,
    advanced_export_enabled,
    meter_hardware_enabled,
    effective_from,
    membership_tier,
    subscription_status,
    subscription_expires_at,
    unlimited_access,
    announcements_enabled,
    marketplace_enabled,
    priority_support_enabled,
    updated_by,
    updated_at
  ) values (
    new.user_id,
    coalesce(plan_row.property_limit, 2147483647),
    coalesce(plan_row.tenant_limit, 2147483647),
    coalesce(plan_row.explore_listing_limit, 2147483647),
    plan_row.electricity_tariff_enabled,
    plan_row.marketplace_enabled,
    true,
    false,
    date_trunc('month', current_date)::date,
    new.membership_tier,
    new.subscription_status,
    new.expires_at,
    new.membership_tier = 'diamond',
    plan_row.announcements_enabled,
    plan_row.marketplace_enabled,
    plan_row.priority_support_enabled,
    new.updated_by,
    now()
  )
  on conflict (owner_id) do update set
    property_limit = excluded.property_limit,
    tenant_limit = excluded.tenant_limit,
    explore_listing_limit = excluded.explore_listing_limit,
    electricity_tariff_enabled = excluded.electricity_tariff_enabled,
    explore_promotion_enabled = excluded.explore_promotion_enabled,
    membership_tier = excluded.membership_tier,
    subscription_status = excluded.subscription_status,
    subscription_expires_at = excluded.subscription_expires_at,
    unlimited_access = excluded.unlimited_access,
    announcements_enabled = excluded.announcements_enabled,
    marketplace_enabled = excluded.marketplace_enabled,
    priority_support_enabled = excluded.priority_support_enabled,
    updated_by = excluded.updated_by,
    updated_at = now();
  return new;
end;
$$;

revoke execute on function private.sync_membership_entitlements()
  from public, anon, authenticated;

create trigger sync_membership_entitlements
after insert or update of membership_tier, subscription_status, expires_at
on public.account_memberships
for each row execute function private.sync_membership_entitlements();

create or replace function private.prepare_subscription_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  plan_row public.subscription_plans%rowtype;
  current_tier text;
begin
  select membership_tier into current_tier
  from public.account_memberships
  where user_id = new.user_id;
  if current_tier = 'diamond' then
    raise exception 'Diamond membership already includes every feature.';
  end if;

  select * into plan_row
  from public.subscription_plans
  where code = 'premium';
  new.amount := case
    when new.billing_period = 'monthly' then plan_row.monthly_price
    when new.billing_period = 'annual' then plan_row.annual_price
  end;
  new.requested_tier := 'premium';
  new.currency := 'MYR';
  new.status := 'pending_verification';
  new.submitted_at := now();
  new.updated_at := now();
  return new;
end;
$$;

revoke execute on function private.prepare_subscription_request()
  from public, anon, authenticated;

create trigger prepare_subscription_request
before insert on public.subscription_requests
for each row execute function private.prepare_subscription_request();

create or replace function private.mark_membership_pending()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.account_memberships
  set subscription_status = 'pending_verification', updated_at = now()
  where user_id = new.user_id and membership_tier = 'free';
  return new;
end;
$$;

revoke execute on function private.mark_membership_pending()
  from public, anon, authenticated;

create trigger mark_membership_pending
after insert on public.subscription_requests
for each row execute function private.mark_membership_pending();

create or replace function private.protect_diamond_owner_config()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.account_memberships membership
    where membership.user_id = old.owner_id
      and membership.membership_tier = 'diamond'
  ) and (
    new.membership_tier <> 'diamond'
    or new.subscription_status <> 'active'
    or new.unlimited_access is not true
    or new.property_limit <> 2147483647
    or new.tenant_limit <> 2147483647
    or new.explore_listing_limit <> 2147483647
    or new.electricity_tariff_enabled is not true
    or new.announcements_enabled is not true
    or new.marketplace_enabled is not true
    or new.priority_support_enabled is not true
  ) then
    raise exception 'Diamond founder access cannot be restricted.';
  end if;
  return new;
end;
$$;

revoke execute on function private.protect_diamond_owner_config()
  from public, anon, authenticated;

create trigger protect_diamond_owner_config
before update on public.owner_access_configs
for each row execute function private.protect_diamond_owner_config();

create or replace function private.protect_diamond_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.account_memberships membership
    where membership.user_id = old.id
      and membership.membership_tier = 'diamond'
  ) then
    raise exception 'Diamond founder account cannot be removed.';
  end if;
  return old;
end;
$$;

revoke execute on function private.protect_diamond_profile()
  from public, anon, authenticated;

create trigger protect_diamond_profile
before delete on public.profiles
for each row execute function private.protect_diamond_profile();

create or replace function private.create_default_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role::text in ('owner', 'property_agent', 'technician') then
    insert into public.account_memberships (
      user_id,
      membership_tier,
      subscription_status,
      started_at
    ) values (
      new.id,
      case when lower(new.email) = 'lauyikfei@gmail.com' then 'diamond' else 'free' end,
      'active',
      now()
    )
    on conflict (user_id) do nothing;
  end if;
  return new;
end;
$$;

revoke execute on function private.create_default_membership()
  from public, anon, authenticated;

create trigger create_default_membership
after insert on public.profiles
for each row execute function private.create_default_membership();

create or replace function private.validate_workspace_subscription_limits()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  membership_tier text := 'free';
  membership_status text := 'active';
  membership_expiry timestamptz;
  property_limit integer := 1;
  tenant_limit integer := 4;
  new_property_count integer := 0;
  old_property_count integer := 0;
  new_tenant_count integer := 0;
  old_tenant_count integer := 0;
begin
  select membership.membership_tier, membership.subscription_status, membership.expires_at
  into membership_tier, membership_status, membership_expiry
  from public.account_memberships membership
  where membership.user_id = new.owner_id;

  if membership_tier = 'diamond' then
    return new;
  end if;
  if membership_tier = 'premium'
     and membership_status = 'active'
     and (membership_expiry is null or membership_expiry > now()) then
    property_limit := 5;
    tenant_limit := 30;
  end if;

  select count(*) into new_property_count
  from jsonb_array_elements(coalesce(new.payload -> 'facilities', '[]'::jsonb)) facility
  where coalesce(facility ->> 'status', '') <> 'sold';
  select count(*) into new_tenant_count
  from jsonb_array_elements(coalesce(new.payload -> 'users', '[]'::jsonb)) account
  where account ->> 'role' = 'tenant';

  if tg_op = 'UPDATE' then
    select count(*) into old_property_count
    from jsonb_array_elements(coalesce(old.payload -> 'facilities', '[]'::jsonb)) facility
    where coalesce(facility ->> 'status', '') <> 'sold';
    select count(*) into old_tenant_count
    from jsonb_array_elements(coalesce(old.payload -> 'users', '[]'::jsonb)) account
    where account ->> 'role' = 'tenant';
  end if;

  if new_property_count > property_limit and new_property_count > old_property_count then
    raise exception 'Subscription property limit reached.';
  end if;
  if new_tenant_count > tenant_limit and new_tenant_count > old_tenant_count then
    raise exception 'Subscription tenant limit reached.';
  end if;
  return new;
end;
$$;

revoke execute on function private.validate_workspace_subscription_limits()
  from public, anon, authenticated;

create trigger validate_workspace_subscription_limits
before insert or update of payload on public.workspace_snapshots
for each row execute function private.validate_workspace_subscription_limits();

insert into public.account_memberships (
  user_id,
  membership_tier,
  subscription_status,
  started_at
)
select
  profile.id,
  case when lower(profile.email) = 'lauyikfei@gmail.com' then 'diamond' else 'free' end,
  'active',
  now()
from public.profiles profile
where profile.role::text in ('owner', 'property_agent', 'technician')
on conflict (user_id) do update set
  membership_tier = case
    when lower((select email from public.profiles where id = excluded.user_id)) = 'lauyikfei@gmail.com'
      then 'diamond'
    else public.account_memberships.membership_tier
  end,
  subscription_status = case
    when lower((select email from public.profiles where id = excluded.user_id)) = 'lauyikfei@gmail.com'
      then 'active'
    else public.account_memberships.subscription_status
  end,
  updated_at = now();
