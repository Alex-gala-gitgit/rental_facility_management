-- Public customization inquiries are accepted only through the validated
-- customize-request Edge Function. Admins access them through admin-console.
create table if not exists public.customize_requests (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  company text not null default '' check (char_length(company) <= 160),
  phone text not null check (char_length(phone) between 6 and 40),
  property_count text not null check (char_length(property_count) <= 40),
  interest text not null check (char_length(interest) <= 160),
  message text not null check (char_length(message) between 1 and 4000),
  language text not null default 'en' check (language in ('en', 'zh')),
  source_path text not null default '/customize/' check (char_length(source_path) <= 300),
  status text not null default 'new' check (status in ('new', 'contacted', 'closed')),
  admin_notes text not null default '' check (char_length(admin_notes) <= 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists customize_requests_created_idx
  on public.customize_requests (created_at desc);
create index if not exists customize_requests_status_created_idx
  on public.customize_requests (status, created_at desc);

alter table public.customize_requests enable row level security;
revoke all on public.customize_requests from anon, authenticated;

-- Existing owner-scoped workspace grants and RLS policies remain unchanged.
-- The admin-console service role performs validated cross-owner edits and
-- records every change in immutable admin_audit_logs.
