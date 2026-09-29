-- Payment instructions are copied into each published invoice so historical
-- invoices keep the account details that applied when they were issued.
alter table public.rentflow_test_invoices
  add column if not exists bank_name text not null default '',
  add column if not exists bank_account_number text not null default '',
  add column if not exists bank_beneficiary text not null default '',
  add column if not exists payment_qr_name text,
  add column if not exists payment_qr_base64 text;

comment on column public.rentflow_test_invoices.portal_token_hash is
  'SHA-256 hash of a 256-bit random bearer token. Raw tokens are never stored.';

create or replace function public.cap_invoice_portal_expiry()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.portal_expires_at is not null then
    new.portal_expires_at := least(
      new.portal_expires_at,
      current_timestamp + interval '72 hours'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists cap_invoice_portal_expiry_72_hours
  on public.rentflow_test_invoices;
create trigger cap_invoice_portal_expiry_72_hours
before insert or update of portal_expires_at
on public.rentflow_test_invoices
for each row execute function public.cap_invoice_portal_expiry();
