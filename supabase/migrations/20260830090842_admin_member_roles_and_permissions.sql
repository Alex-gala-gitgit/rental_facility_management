-- Admin hierarchy:
--   founder     Permanent, unrestricted and may manage the allowlist.
--   super_admin Restricted operational administrator.

alter table public.admin_users
  drop constraint if exists admin_users_admin_role_check;

create or replace function private.protect_founder_admin_access()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op <> 'DELETE'
     and new.admin_role = 'founder'
     and not private.is_founder_email(new.email) then
    raise exception 'Founder level is reserved for HomeOps360 founders.';
  end if;

  if tg_op <> 'INSERT' and private.is_founder_email(old.email) then
    if tg_op = 'DELETE' then
      raise exception 'Founder administrator access cannot be removed.';
    end if;
    if new.user_id <> old.user_id
       or lower(new.email) <> lower(old.email)
       or new.admin_role <> 'founder'
       or new.enabled is not true then
      raise exception 'Founder administrator access cannot be disabled, demoted or reassigned.';
    end if;
  end if;

  if tg_op = 'INSERT' and private.is_founder_email(new.email) then
    new.admin_role := 'founder';
    new.enabled := true;
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke execute on function private.protect_founder_admin_access()
  from public, anon, authenticated;

drop trigger if exists protect_founder_admin_access on public.admin_users;
create trigger protect_founder_admin_access
before insert or update or delete on public.admin_users
for each row execute function private.protect_founder_admin_access();

update public.admin_users
set admin_role = 'super_admin', updated_at = now()
where not private.is_founder_email(email);

update public.admin_users
set admin_role = 'founder', enabled = true, updated_at = now()
where private.is_founder_email(email);

alter table public.admin_users
  add constraint admin_users_admin_role_check
  check (admin_role in ('founder', 'super_admin'));

create index if not exists admin_users_role_enabled_idx
  on public.admin_users (admin_role, enabled);
