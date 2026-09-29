alter table public.rentflow_test_invoices
  add column if not exists electricity_label text not null
  default 'Air-con electricity';

comment on column public.rentflow_test_invoices.electricity_label is
  'Invoice presentation label: Electricity for combined billing or Air-con electricity for air-con-only billing.';
