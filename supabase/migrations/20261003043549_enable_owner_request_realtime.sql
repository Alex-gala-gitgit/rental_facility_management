-- Owner-scoped Realtime subscription still uses the existing SELECT RLS policy.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'tenant_workspace_snapshots'
  ) then
    alter publication supabase_realtime add table public.tenant_workspace_snapshots;
  end if;
end $$;
