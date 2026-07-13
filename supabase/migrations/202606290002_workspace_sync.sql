-- Secure cloud snapshots used by the current offline-first application.
-- Owners receive the complete workspace; tenants receive only their own slice.

create table public.workspace_snapshots (
  owner_id uuid primary key references public.profiles(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);

create table public.tenant_workspace_snapshots (
  owner_id uuid not null references public.profiles(id) on delete cascade,
  tenant_email text not null,
  tenant_id uuid references public.profiles(id) on delete set null,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (owner_id, tenant_email)
);

create index tenant_workspace_email_idx
  on public.tenant_workspace_snapshots (lower(tenant_email));

create or replace function public.link_tenant_workspace()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if new.tenant_id is null then
    select id into new.tenant_id
    from public.profiles
    where lower(email) = lower(new.tenant_email)
      and role = 'tenant'
    limit 1;
  end if;
  return new;
end;
$$;

create trigger link_tenant_workspace_before_write
  before insert or update of tenant_email on public.tenant_workspace_snapshots
  for each row execute procedure public.link_tenant_workspace();

create or replace function public.link_new_profile_to_workspace()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if new.role = 'tenant' then
    update public.tenant_workspace_snapshots
    set tenant_id = new.id, updated_at = now()
    where lower(tenant_email) = lower(new.email) and tenant_id is null;
  end if;
  return new;
end;
$$;

create trigger link_profile_to_tenant_workspace
  after insert on public.profiles
  for each row execute procedure public.link_new_profile_to_workspace();

alter table public.workspace_snapshots enable row level security;
alter table public.tenant_workspace_snapshots enable row level security;

create policy "owners manage own workspace snapshot"
on public.workspace_snapshots for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "owners manage tenant workspace snapshots"
on public.tenant_workspace_snapshots for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "tenants read assigned workspace snapshot"
on public.tenant_workspace_snapshots for select
using (
  tenant_id = auth.uid()
  or lower(tenant_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
);

create policy "tenants update assigned workspace snapshot"
on public.tenant_workspace_snapshots for update
using (
  tenant_id = auth.uid()
  or lower(tenant_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
)
with check (
  tenant_id = auth.uid()
  or lower(tenant_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
);
