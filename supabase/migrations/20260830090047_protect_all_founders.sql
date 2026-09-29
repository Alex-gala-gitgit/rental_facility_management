-- Keep every HomeOps360 founder account permanently privileged. Founder
-- identity is email-based only at bootstrap; all runtime protection is also
-- backed by the immutable Diamond membership row.

create or replace function private.is_founder_email(account_email text)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select lower(trim(account_email)) in (
    'lauyikfei@gmail.com',
    'just4u_alex@yahoo.co.uk'
  );
$$;

revoke execute on function private.is_founder_email(text)
  from public, anon, authenticated;

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
    if old.membership_tier = 'diamond' or private.is_founder_email(account_email) then
      raise exception 'Diamond founder membership cannot be removed.';
    end if;
    return old;
  end if;

  if private.is_founder_email(account_email) then
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

create or replace function private.create_default_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.is_founder_email(new.email)
     or new.role::text in ('owner', 'property_agent', 'technician') then
    insert into public.account_memberships (
      user_id,
      membership_tier,
      subscription_status,
      started_at
    ) values (
      new.id,
      case when private.is_founder_email(new.email) then 'diamond' else 'free' end,
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

create or replace function private.protect_founder_profile_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if lower(new.email) is distinct from lower(old.email)
     and (
       private.is_founder_email(old.email)
       or exists (
         select 1
         from public.account_memberships membership
         where membership.user_id = old.id
           and membership.membership_tier = 'diamond'
       )
     ) then
    raise exception 'Diamond founder identity cannot be reassigned.';
  end if;
  return new;
end;
$$;

revoke execute on function private.protect_founder_profile_email()
  from public, anon, authenticated;

drop trigger if exists protect_founder_profile_email on public.profiles;
create trigger protect_founder_profile_email
before update of email on public.profiles
for each row execute function private.protect_founder_profile_email();

insert into public.admin_users (
  user_id,
  email,
  display_name,
  admin_role,
  enabled
)
select
  profile.id,
  profile.email,
  coalesce(nullif(profile.full_name, ''), 'Founder'),
  'super_admin',
  true
from public.profiles profile
where private.is_founder_email(profile.email)
on conflict (user_id) do update set
  email = excluded.email,
  display_name = excluded.display_name,
  admin_role = 'super_admin',
  enabled = true,
  updated_at = now();

insert into public.account_memberships (
  user_id,
  membership_tier,
  subscription_status,
  billing_period,
  started_at,
  expires_at,
  updated_at
)
select
  profile.id,
  'diamond',
  'active',
  null,
  now(),
  null,
  now()
from public.profiles profile
where private.is_founder_email(profile.email)
on conflict (user_id) do update set
  membership_tier = 'diamond',
  subscription_status = 'active',
  billing_period = null,
  expires_at = null,
  updated_at = now();
