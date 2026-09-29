update public.subscription_plans
set tenant_limit = 2,
    updated_at = now()
where code = 'free';

update public.owner_access_configs
set tenant_limit = 2,
    updated_at = now()
where membership_tier = 'free'
   or subscription_status <> 'active';

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
  tenant_limit integer := 2;
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
