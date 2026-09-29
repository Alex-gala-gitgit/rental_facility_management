-- A client bug or stale browser must never replace a populated owner workspace
-- with an empty payload. Intentional removal remains possible by deleting the
-- row explicitly from an authenticated administrative session.
create or replace function public.prevent_populated_workspace_empty_overwrite()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  old_facility_count integer := jsonb_array_length(
    coalesce(old.payload -> 'facilities', '[]'::jsonb)
  );
  new_facility_count integer := jsonb_array_length(
    coalesce(new.payload -> 'facilities', '[]'::jsonb)
  );
begin
  if old_facility_count > 0 and new_facility_count = 0 then
    raise exception using
      errcode = 'check_violation',
      message = 'Refusing to replace a populated workspace with an empty workspace.',
      hint = 'Use an explicit administrative delete only after taking a backup.';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_workspace_from_empty_overwrite
  on public.workspace_snapshots;

create trigger protect_workspace_from_empty_overwrite
before update of payload on public.workspace_snapshots
for each row
execute function public.prevent_populated_workspace_empty_overwrite();
