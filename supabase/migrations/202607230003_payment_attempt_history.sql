create table if not exists public.rentflow_payment_attempts (
  id uuid primary key default gen_random_uuid(),
  invoice_id text not null references public.rentflow_test_invoices(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  slip_name text not null,
  slip_path text not null unique,
  amount_paid numeric(12,2) not null check (amount_paid > 0),
  payment_date timestamptz not null,
  payment_reference text,
  submitted_at timestamptz not null default now(),
  status text not null default 'submitted'
    check (status in ('submitted', 'approved', 'rejected')),
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists rentflow_payment_attempts_invoice_submitted_idx
  on public.rentflow_payment_attempts (invoice_id, submitted_at desc);

alter table public.rentflow_payment_attempts enable row level security;

drop policy if exists "Owners can read their payment attempts"
  on public.rentflow_payment_attempts;
create policy "Owners can read their payment attempts"
  on public.rentflow_payment_attempts
  for select
  to authenticated
  using (owner_id = auth.uid());

drop policy if exists "Owners can review their payment attempts"
  on public.rentflow_payment_attempts;
create policy "Owners can review their payment attempts"
  on public.rentflow_payment_attempts
  for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());
