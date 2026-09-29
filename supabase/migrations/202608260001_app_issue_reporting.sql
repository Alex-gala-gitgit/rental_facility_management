-- Authenticated application users can report product/system problems.
-- Reports are visible to the reporter and the service-role admin console only.
create table if not exists public.app_issue_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reporter_email text not null check (char_length(reporter_email) <= 254),
  reporter_name text not null check (char_length(reporter_name) between 1 and 120),
  reporter_role text not null check (reporter_role in ('owner', 'tenant', 'property_agent', 'technician')),
  category text not null check (category in ('login', 'billing', 'payment', 'invoice_pdf', 'request', 'language', 'performance', 'other')),
  title text not null check (char_length(title) between 3 and 160),
  description text not null check (char_length(description) between 10 and 4000),
  severity text not null default 'normal' check (severity in ('low', 'normal', 'high', 'critical')),
  status text not null default 'new' check (status in ('new', 'investigating', 'resolved', 'closed')),
  attachment_name text check (char_length(attachment_name) <= 240),
  attachment_mime text check (char_length(attachment_mime) <= 120),
  attachment_base64 text check (char_length(attachment_base64) <= 2800000),
  app_language text not null default 'english' check (app_language in ('english', 'chinese', 'malay')),
  source text not null default 'app' check (char_length(source) <= 80),
  admin_notes text not null default '' check (char_length(admin_notes) <= 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists app_issue_reports_created_idx
  on public.app_issue_reports (created_at desc);
create index if not exists app_issue_reports_status_created_idx
  on public.app_issue_reports (status, created_at desc);
create index if not exists app_issue_reports_reporter_idx
  on public.app_issue_reports (reporter_id, created_at desc);

alter table public.app_issue_reports enable row level security;

drop policy if exists "users insert own issue reports" on public.app_issue_reports;
create policy "users insert own issue reports"
on public.app_issue_reports for insert
to authenticated
with check ((select auth.uid()) = reporter_id);

drop policy if exists "users read own issue reports" on public.app_issue_reports;
create policy "users read own issue reports"
on public.app_issue_reports for select
to authenticated
using ((select auth.uid()) = reporter_id);

revoke all on public.app_issue_reports from anon, authenticated;
grant select, insert on public.app_issue_reports to authenticated;
