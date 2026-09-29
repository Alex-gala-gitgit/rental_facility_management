-- Process scheduled tenancy cutoffs and Auth suspension every hour.
-- Required Vault secrets:
--   project_url: https://<project-ref>.supabase.co
--   tenant_lifecycle_cron_secret: matches the Edge Function secret

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

do $$
begin
  if not exists (
    select 1 from vault.decrypted_secrets where name = 'project_url'
  ) or not exists (
    select 1 from vault.decrypted_secrets
    where name = 'tenant_lifecycle_cron_secret'
  ) then
    raise exception
      'Create project_url and tenant_lifecycle_cron_secret in Vault before applying this migration.';
  end if;

  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'homeops360-tenant-lifecycle-hourly';
end
$$;

select cron.schedule(
  'homeops360-tenant-lifecycle-hourly',
  '17 * * * *',
  $job$
    select net.http_post(
      url := (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'project_url'
      ) || '/functions/v1/tenant-lifecycle',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-lifecycle-secret', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'tenant_lifecycle_cron_secret'
        )
      ),
      body := jsonb_build_object('triggered_at', now()),
      timeout_milliseconds := 15000
    );
  $job$
);
