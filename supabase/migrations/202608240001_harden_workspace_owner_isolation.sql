-- Keep every owner workspace behind its authenticated UUID and prevent tenant
-- snapshot keys from being reassigned. Client roles receive only the grants
-- required by the signed-in application; anonymous users receive none.

alter table public.workspace_snapshots enable row level security;
alter table public.tenant_workspace_snapshots enable row level security;

revoke all on table public.workspace_snapshots from anon, authenticated;
revoke all on table public.tenant_workspace_snapshots from anon, authenticated;
grant select, insert, update, delete on table public.workspace_snapshots to authenticated;
grant select, insert, update, delete on table public.tenant_workspace_snapshots to authenticated;

drop policy if exists "owners manage own workspace snapshot" on public.workspace_snapshots;
drop policy if exists "owners select own workspace snapshot" on public.workspace_snapshots;
drop policy if exists "owners insert own workspace snapshot" on public.workspace_snapshots;
drop policy if exists "owners update own workspace snapshot" on public.workspace_snapshots;
drop policy if exists "owners delete own workspace snapshot" on public.workspace_snapshots;

create policy "owners select own workspace snapshot"
on public.workspace_snapshots for select
to authenticated
using ((select auth.uid()) = owner_id);

create policy "owners insert own workspace snapshot"
on public.workspace_snapshots for insert
to authenticated
with check ((select auth.uid()) = owner_id);

create policy "owners update own workspace snapshot"
on public.workspace_snapshots for update
to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);

create policy "owners delete own workspace snapshot"
on public.workspace_snapshots for delete
to authenticated
using ((select auth.uid()) = owner_id);

drop policy if exists "owners manage tenant workspace snapshots" on public.tenant_workspace_snapshots;
drop policy if exists "tenants read assigned workspace snapshot" on public.tenant_workspace_snapshots;
drop policy if exists "tenants update assigned workspace snapshot" on public.tenant_workspace_snapshots;
drop policy if exists "owners select tenant workspace snapshots" on public.tenant_workspace_snapshots;
drop policy if exists "owners insert tenant workspace snapshots" on public.tenant_workspace_snapshots;
drop policy if exists "owners update tenant workspace snapshots" on public.tenant_workspace_snapshots;
drop policy if exists "owners delete tenant workspace snapshots" on public.tenant_workspace_snapshots;
drop policy if exists "tenants select assigned workspace snapshot" on public.tenant_workspace_snapshots;
drop policy if exists "tenants update assigned workspace snapshot" on public.tenant_workspace_snapshots;
drop policy if exists "assigned users select tenant workspace snapshots" on public.tenant_workspace_snapshots;
drop policy if exists "assigned users update tenant workspace snapshots" on public.tenant_workspace_snapshots;

create policy "assigned users select tenant workspace snapshots"
on public.tenant_workspace_snapshots for select
to authenticated
using (
  (select auth.uid()) = owner_id
  or (select auth.uid()) = tenant_id
);

create policy "owners insert tenant workspace snapshots"
on public.tenant_workspace_snapshots for insert
to authenticated
with check ((select auth.uid()) = owner_id);

create policy "assigned users update tenant workspace snapshots"
on public.tenant_workspace_snapshots for update
to authenticated
using (
  (select auth.uid()) = owner_id
  or (select auth.uid()) = tenant_id
)
with check (
  (select auth.uid()) = owner_id
  or (
    (select auth.uid()) = tenant_id
    and lower(tenant_email) = lower(coalesce((select auth.jwt()) ->> 'email', ''))
  )
);

create policy "owners delete tenant workspace snapshots"
on public.tenant_workspace_snapshots for delete
to authenticated
using ((select auth.uid()) = owner_id);

create or replace function public.prevent_tenant_workspace_reassignment()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select auth.uid()) = old.tenant_id
     and (select auth.uid()) is distinct from old.owner_id
     and (
       new.owner_id is distinct from old.owner_id
       or new.tenant_id is distinct from old.tenant_id
       or lower(new.tenant_email) is distinct from lower(old.tenant_email)
     ) then
    raise exception 'Tenant workspace ownership cannot be reassigned.';
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_tenant_workspace_reassignment
on public.tenant_workspace_snapshots;

create trigger prevent_tenant_workspace_reassignment
before update of owner_id, tenant_id, tenant_email
on public.tenant_workspace_snapshots
for each row execute function public.prevent_tenant_workspace_reassignment();
