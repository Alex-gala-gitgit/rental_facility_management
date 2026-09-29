create or replace function public.admin_project_resource_usage()
returns table (
  database_bytes bigint,
  storage_bytes bigint,
  storage_objects bigint
)
language sql
security definer
set search_path = pg_catalog, public, storage
as $$
  select
    pg_database_size(current_database())::bigint as database_bytes,
    coalesce(sum(
      case
        when objects.metadata ->> 'size' ~ '^\d+$'
          then (objects.metadata ->> 'size')::bigint
        else 0
      end
    ), 0)::bigint as storage_bytes,
    count(objects.id)::bigint as storage_objects
  from storage.objects as objects;
$$;

revoke all on function public.admin_project_resource_usage() from public;
revoke all on function public.admin_project_resource_usage() from anon;
revoke all on function public.admin_project_resource_usage() from authenticated;
grant execute on function public.admin_project_resource_usage() to service_role;

comment on function public.admin_project_resource_usage() is
  'Returns project database and Storage footprint to the service-role-only admin console.';
