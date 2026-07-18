-- Complete the invoice -> WhatsApp portal -> payment proof workflow.
-- Run this migration before deploying the matching application build.

alter table public.rentflow_test_invoices
  add column if not exists general_electric numeric(12,2) not null default 0,
  add column if not exists parking_rental numeric(12,2) not null default 0,
  add column if not exists electricity_tariff_name text not null default 'TNB default tariff',
  add column if not exists electricity_rate_per_kwh numeric(12,6) not null default 0.516,
  add column if not exists electricity_amount numeric(12,2),
  add column if not exists electricity_tariff_summary text,
  add column if not exists pdf_path text,
  add column if not exists amount_paid numeric(12,2),
  add column if not exists payment_date timestamptz,
  add column if not exists payment_reference text,
  add column if not exists slip_submitted_at timestamptz;
