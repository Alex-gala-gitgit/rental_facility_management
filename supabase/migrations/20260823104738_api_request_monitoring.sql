-- Operational telemetry for HomeOps360 Edge Functions. Request bodies,
-- authorization headers, IP addresses and other personal data are never
-- stored here. Browser roles have no access; only service-role server code
-- writes and reads these records.

create table public.api_request_logs (
  id bigint generated always as identity primary key,
  request_id uuid not null default gen_random_uuid(),
  function_name text not null
    check (function_name ~ '^[a-z0-9][a-z0-9-]*$'),
  method text not null
    check (method ~ '^[A-Z]{3,12}$'),
  status_code smallint not null
    check (status_code between 100 and 599),
  duration_ms integer not null
    check (duration_ms >= 0),
  error_code text,
  created_at timestamptz not null default now()
);

create unique index api_request_logs_request_id_idx
  on public.api_request_logs (request_id);
create index api_request_logs_created_idx
  on public.api_request_logs (created_at desc);
create index api_request_logs_function_created_idx
  on public.api_request_logs (function_name, created_at desc);
create index api_request_logs_failures_idx
  on public.api_request_logs (created_at desc, function_name)
  where status_code >= 400;

alter table public.api_request_logs enable row level security;
revoke all on public.api_request_logs from public, anon, authenticated;

-- Edge Functions only append rows. Server-side maintenance retains the
-- ability to prune old telemetry according to the deployment's retention
-- policy; browser clients cannot read or mutate any row.
