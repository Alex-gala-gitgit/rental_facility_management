create table if not exists public.tenant_profile_invitations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  tenant_id text not null,
  tenant_email text not null,
  token_hash text not null unique,
  status text not null default 'invited'
    check (status in ('invited', 'submitted', 'approved', 'rejected')),
  draft jsonb not null default '{}'::jsonb,
  rejection_reason text,
  expires_at timestamptz not null,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, tenant_id)
);

create index if not exists tenant_profile_invitations_owner_status_idx
  on public.tenant_profile_invitations (owner_id, status, updated_at desc);

alter table public.tenant_profile_invitations enable row level security;

drop policy if exists "owners read their tenant profile invitations"
  on public.tenant_profile_invitations;
create policy "owners read their tenant profile invitations"
  on public.tenant_profile_invitations
  for select to authenticated
  using (owner_id = auth.uid());

revoke all on public.tenant_profile_invitations from anon;
revoke insert, update, delete on public.tenant_profile_invitations from authenticated;
grant select on public.tenant_profile_invitations to authenticated;

-- Add the durable notification category used when a tenant submits a profile.
alter table public.owner_notifications
  drop constraint if exists owner_notifications_category_check;
alter table public.owner_notifications
  add constraint owner_notifications_category_check
  check (category in ('payment', 'request', 'tenant', 'tenant_profile', 'account'));
