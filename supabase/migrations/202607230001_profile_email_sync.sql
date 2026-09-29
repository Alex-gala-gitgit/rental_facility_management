-- Login email is owned by auth.users; business ownership remains keyed by UUID.
-- Keep the display/profile copy aligned only after Supabase accepts the secure
-- email-change flow. This never changes owner_id or any workspace foreign key.
create or replace function public.sync_profile_login_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email is distinct from old.email then
    update public.profiles
    set email = lower(new.email)
    where id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists sync_profile_login_email_after_update on auth.users;
create trigger sync_profile_login_email_after_update
after update of email on auth.users
for each row execute procedure public.sync_profile_login_email();
