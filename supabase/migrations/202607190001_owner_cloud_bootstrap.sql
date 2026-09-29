-- Property owners are application users, not Supabase project administrators.
-- Allow owners to create isolated workspaces while keeping tenant registration
-- invitation-only. Row-level security separates every owner's records.
create or replace function public.enforce_invitation_only_signup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_role text;
  has_invitation boolean;
begin
  requested_role := coalesce(new.raw_user_meta_data ->> 'role', '');

  if requested_role = 'owner' then
    return new;
  end if;

  if requested_role <> 'tenant' then
    raise exception 'Account creation is invitation-only.';
  end if;

  select exists (
    select 1
    from public.tenant_workspace_snapshots
    where lower(tenant_email) = lower(coalesce(new.email, ''))
      and invited_at is not null
  ) into has_invitation;

  if not has_invitation then
    raise exception 'A valid owner invitation is required.';
  end if;

  return new;
end;
$$;
