-- Deny database access immediately when an Auth account is suspended or
-- soft-deleted. Auth access tokens can remain cryptographically valid until
-- they expire, so every existing public RLS table receives this additional
-- restrictive account-state check.

create schema if not exists private;

create or replace function private.current_auth_account_is_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.users as auth_user
    where auth_user.id = (select auth.uid())
      and auth_user.deleted_at is null
      and (
        auth_user.banned_until is null
        or auth_user.banned_until <= now()
      )
  );
$$;

revoke all on function private.current_auth_account_is_active() from public;
revoke all on function private.current_auth_account_is_active() from anon;
grant usage on schema private to authenticated;
grant execute on function private.current_auth_account_is_active() to authenticated;

do $policy_install$
declare
  target_table record;
begin
  for target_table in
    select namespace.nspname as schema_name,
           relation.relname as table_name
    from pg_class as relation
    join pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relkind in ('r', 'p')
      and relation.relrowsecurity
  loop
    if not exists (
      select 1
      from pg_policy as policy
      join pg_class as policy_table
        on policy_table.oid = policy.polrelid
      join pg_namespace as policy_namespace
        on policy_namespace.oid = policy_table.relnamespace
      where policy.polname = 'account_access_not_blocked'
        and policy_namespace.nspname = target_table.schema_name
        and policy_table.relname = target_table.table_name
    ) then
      execute format(
        'create policy account_access_not_blocked on %I.%I as restrictive for all to authenticated using ((select private.current_auth_account_is_active())) with check ((select private.current_auth_account_is_active()))',
        target_table.schema_name,
        target_table.table_name
      );
    end if;
  end loop;
end;
$policy_install$;

comment on function private.current_auth_account_is_active() is
  'Returns true only when the calling authenticated user still exists and is not currently banned.';
