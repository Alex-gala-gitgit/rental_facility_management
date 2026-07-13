-- Enforce invitation-only account creation at the database boundary.
-- This protects Auth even if somebody calls the public signup API directly.

alter table public.tenant_workspace_snapshots
  add column if not exists invited_at timestamptz,
  add column if not exists invitation_sent_by uuid references public.profiles(id) on delete set null;

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

drop trigger if exists enforce_invitation_only_before_signup on auth.users;
create trigger enforce_invitation_only_before_signup
  before insert on auth.users
  for each row execute procedure public.enforce_invitation_only_signup();
