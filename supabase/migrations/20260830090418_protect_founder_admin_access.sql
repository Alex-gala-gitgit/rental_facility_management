-- Founder administration access is permanent. Routine verification timestamps
-- and display-name changes remain allowed, but the identity, role and enabled
-- state cannot be weakened or removed.

create or replace function private.protect_founder_admin_access()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.is_founder_email(old.email) then
    if tg_op = 'DELETE' then
      raise exception 'Founder super-admin access cannot be removed.';
    end if;
    if new.user_id <> old.user_id
       or lower(new.email) <> lower(old.email)
       or new.admin_role <> 'super_admin'
       or new.enabled is not true then
      raise exception 'Founder super-admin access cannot be disabled, demoted or reassigned.';
    end if;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke execute on function private.protect_founder_admin_access()
  from public, anon, authenticated;

drop trigger if exists protect_founder_admin_access on public.admin_users;
create trigger protect_founder_admin_access
before update or delete on public.admin_users
for each row execute function private.protect_founder_admin_access();
