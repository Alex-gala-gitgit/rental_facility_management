-- HomeOps360 administration boundary.
-- Privileged operations are performed only by the admin-console Edge Function
-- after it verifies the caller against public.admin_users. Browser clients
-- never receive a secret/service-role key.

create table public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text not null default 'Administrator',
  admin_role text not null default 'admin'
    check (admin_role in ('admin', 'super_admin')),
  enabled boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_verified_at timestamptz
);

create unique index admin_users_email_lower_idx
  on public.admin_users (lower(email));
create index admin_users_enabled_idx
  on public.admin_users (enabled)
  where enabled;

create table public.owner_access_configs (
  owner_id uuid primary key references public.profiles(id) on delete cascade,
  property_limit integer not null default 5 check (property_limit >= 0),
  tenant_limit integer not null default 15 check (tenant_limit >= 0),
  explore_listing_limit integer not null default 10
    check (explore_listing_limit >= 0),
  electricity_tariff_enabled boolean not null default true,
  explore_promotion_enabled boolean not null default true,
  advanced_export_enabled boolean not null default true,
  meter_hardware_enabled boolean not null default false,
  effective_from date not null default date_trunc('month', current_date)::date,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create index owner_access_configs_updated_by_idx
  on public.owner_access_configs (updated_by);

create table public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null references auth.users(id) on delete restrict,
  action text not null,
  target_type text not null,
  target_id text,
  before_value jsonb,
  after_value jsonb,
  request_id uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create index admin_audit_logs_created_idx
  on public.admin_audit_logs (created_at desc);
create index admin_audit_logs_admin_created_idx
  on public.admin_audit_logs (admin_user_id, created_at desc);
create index admin_audit_logs_target_idx
  on public.admin_audit_logs (target_type, target_id, created_at desc);

create table public.platform_events (
  id bigint generated always as identity primary key,
  event_type text not null
    check (event_type in ('page_view', 'app_open', 'admin_open')),
  visitor_key text not null,
  path text not null default '/',
  user_id uuid references auth.users(id) on delete set null,
  user_role text,
  occurred_at timestamptz not null default now()
);

create index platform_events_occurred_idx
  on public.platform_events (occurred_at desc);
create index platform_events_daily_visitors_idx
  on public.platform_events (occurred_at, visitor_key);
create index platform_events_user_idx
  on public.platform_events (user_id, occurred_at desc)
  where user_id is not null;

alter table public.admin_users enable row level security;
alter table public.owner_access_configs enable row level security;
alter table public.admin_audit_logs enable row level security;
alter table public.platform_events enable row level security;

-- Owners may read only their own current feature/limit configuration. All
-- writes remain server-side and are audited by the admin-console function.
create policy "owners read own admin configuration"
on public.owner_access_configs for select
to authenticated
using ((select auth.uid()) = owner_id);

revoke all on public.admin_users from anon, authenticated;
revoke all on public.admin_audit_logs from anon, authenticated;
revoke all on public.platform_events from anon, authenticated;
revoke all on public.owner_access_configs from anon, authenticated;
grant select on public.owner_access_configs to authenticated;

-- Audit events cannot be rewritten or removed, including by privileged API
-- code. Corrections are represented by a new compensating audit event.
create or replace function public.prevent_admin_audit_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Admin audit records are immutable.';
end;
$$;

revoke execute on function public.prevent_admin_audit_mutation()
  from public, anon, authenticated;

create trigger admin_audit_logs_immutable
  before update or delete on public.admin_audit_logs
  for each row execute function public.prevent_admin_audit_mutation();

-- Bootstrap the requested operator account when it already exists in this
-- environment. If it does not exist yet, add it from the Supabase SQL editor
-- after the account has confirmed its email.
insert into public.admin_users (
  user_id,
  email,
  display_name,
  admin_role
)
select
  p.id,
  p.email,
  coalesce(nullif(p.full_name, ''), 'Alex Lau'),
  'super_admin'
from public.profiles p
where lower(p.email) = 'just4u_alex@yahoo.co.uk'
on conflict (user_id) do update
set email = excluded.email,
    display_name = excluded.display_name,
    admin_role = 'super_admin',
    enabled = true,
    updated_at = now();
