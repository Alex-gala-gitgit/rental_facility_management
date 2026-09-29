-- Realtime owner notifications for changes initiated by tenants.
-- The owner receives a durable notification row even when the owner app is
-- offline. Supabase Realtime delivers new rows immediately while the app is
-- open, and unread rows are loaded at the next sign-in.

create table if not exists public.owner_notifications (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  category text not null check (category in ('payment', 'request', 'tenant', 'account')),
  title text not null,
  message text not null,
  source_table text not null,
  source_id text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists owner_notifications_owner_created_idx
  on public.owner_notifications (owner_id, created_at desc);
create index if not exists owner_notifications_owner_unread_idx
  on public.owner_notifications (owner_id, created_at desc)
  where read_at is null;

alter table public.owner_notifications enable row level security;

drop policy if exists "owners read own notifications" on public.owner_notifications;
drop policy if exists "owners update own notifications" on public.owner_notifications;
drop policy if exists "owners delete own notifications" on public.owner_notifications;

create policy "owners read own notifications"
on public.owner_notifications for select to authenticated
using (owner_id = auth.uid() and public.is_owner());

create policy "owners update own notifications"
on public.owner_notifications for update to authenticated
using (owner_id = auth.uid() and public.is_owner())
with check (owner_id = auth.uid() and public.is_owner());

create policy "owners delete own notifications"
on public.owner_notifications for delete to authenticated
using (owner_id = auth.uid() and public.is_owner());

revoke insert on public.owner_notifications from anon, authenticated;

create or replace function public.notify_owner_from_tenant_snapshot()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  tenant_name text;
  event_category text;
  event_title text;
  event_message text;
begin
  -- Owner-side synchronisation must not create a notification about the
  -- owner's own changes. Only the tenant assigned to this snapshot qualifies.
  if auth.uid() is null
     or auth.uid() = new.owner_id
     or new.tenant_id is distinct from auth.uid() then
    return new;
  end if;

  select coalesce(nullif(full_name, ''), split_part(new.tenant_email, '@', 1))
    into tenant_name
  from public.profiles
  where id = new.tenant_id;
  tenant_name := coalesce(tenant_name, split_part(new.tenant_email, '@', 1));

  if new.payload -> 'tenantRequests' is distinct from old.payload -> 'tenantRequests' then
    event_category := 'request';
    event_title := 'Tenant request updated';
    event_message := tenant_name || ' submitted or updated a tenant request.';
  elsif new.payload -> 'bills' is distinct from old.payload -> 'bills' then
    event_category := 'payment';
    event_title := 'Tenant payment updated';
    event_message := tenant_name || ' submitted or updated payment information.';
  elsif new.payload -> 'users' is distinct from old.payload -> 'users' then
    event_category := 'tenant';
    event_title := 'Tenant profile updated';
    event_message := tenant_name || ' updated their tenant profile.';
  else
    event_category := 'account';
    event_title := 'Tenant workspace updated';
    event_message := tenant_name || ' updated information in the tenant app.';
  end if;

  insert into public.owner_notifications (
    owner_id,
    actor_id,
    category,
    title,
    message,
    source_table,
    source_id
  ) values (
    new.owner_id,
    new.tenant_id,
    event_category,
    event_title,
    event_message,
    'tenant_workspace_snapshots',
    lower(new.tenant_email)
  );

  return new;
end;
$$;

drop trigger if exists notify_owner_after_tenant_snapshot_update
  on public.tenant_workspace_snapshots;
create trigger notify_owner_after_tenant_snapshot_update
  after update of payload on public.tenant_workspace_snapshots
  for each row
  when (old.payload is distinct from new.payload)
  execute procedure public.notify_owner_from_tenant_snapshot();

create or replace function public.notify_owner_from_invoice_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.owner_id is null
     or new.status <> 'slipSubmitted'
     or old.status is not distinct from new.status then
    return new;
  end if;

  insert into public.owner_notifications (
    owner_id,
    category,
    title,
    message,
    source_table,
    source_id
  ) values (
    new.owner_id,
    'payment',
    'Payment proof received',
    coalesce(nullif(new.tenant_name, ''), 'A tenant') ||
      ' submitted payment proof for ' || coalesce(nullif(new.period, ''), 'an invoice') || '.',
    'rentflow_test_invoices',
    new.id
  );

  return new;
end;
$$;

drop trigger if exists notify_owner_after_invoice_payment
  on public.rentflow_test_invoices;
create trigger notify_owner_after_invoice_payment
  after update of status on public.rentflow_test_invoices
  for each row
  execute procedure public.notify_owner_from_invoice_payment();

create or replace function public.notify_owner_from_tenant_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  facility_owner uuid;
  tenant_name text;
begin
  if auth.uid() is null or new.tenant_id is distinct from auth.uid() then
    return new;
  end if;

  select owner_id into facility_owner
  from public.facilities
  where id = new.facility_id;

  if facility_owner is null then return new; end if;

  select coalesce(nullif(full_name, ''), 'A tenant') into tenant_name
  from public.profiles
  where id = new.tenant_id;

  insert into public.owner_notifications (
    owner_id,
    actor_id,
    category,
    title,
    message,
    source_table,
    source_id
  ) values (
    facility_owner,
    new.tenant_id,
    'request',
    'New tenant request',
    coalesce(tenant_name, 'A tenant') || ' submitted: ' || new.title || '.',
    'tenant_requests',
    new.id::text
  );

  return new;
end;
$$;

drop trigger if exists notify_owner_after_tenant_request
  on public.tenant_requests;
create trigger notify_owner_after_tenant_request
  after insert on public.tenant_requests
  for each row execute procedure public.notify_owner_from_tenant_request();

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'owner_notifications'
  ) then
    alter publication supabase_realtime add table public.owner_notifications;
  end if;
end $$;
