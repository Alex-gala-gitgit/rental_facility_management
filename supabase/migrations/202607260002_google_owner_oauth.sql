-- Google OAuth users must follow the same ownership boundary as password users.
-- An email that has an existing tenant invitation remains a tenant. Any other
-- new Google identity receives a brand-new, isolated owner workspace keyed by
-- auth.users.id. Email is never used as the workspace/ownership key.
create or replace function public.enforce_invitation_only_signup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_role text;
  auth_provider text;
  has_invitation boolean;
begin
  requested_role := coalesce(new.raw_user_meta_data ->> 'role', '');
  auth_provider := coalesce(new.raw_app_meta_data ->> 'provider', '');

  select exists (
    select 1
    from public.tenant_workspace_snapshots
    where lower(tenant_email) = lower(coalesce(new.email, ''))
      and invited_at is not null
  ) into has_invitation;

  if requested_role = 'owner' then
    return new;
  end if;

  if auth_provider = 'google' and not has_invitation then
    new.raw_user_meta_data := coalesce(new.raw_user_meta_data, '{}'::jsonb)
      || jsonb_build_object(
        'role', 'owner',
        'full_name', coalesce(
          nullif(new.raw_user_meta_data ->> 'full_name', ''),
          nullif(new.raw_user_meta_data ->> 'name', ''),
          split_part(coalesce(new.email, 'Owner'), '@', 1)
        )
      );
    return new;
  end if;

  if requested_role <> 'tenant' and not has_invitation then
    raise exception 'Account creation is invitation-only.';
  end if;

  return new;
end;
$$;
