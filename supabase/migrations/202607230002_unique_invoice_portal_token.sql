create unique index if not exists rentflow_test_invoices_portal_token_hash_key
  on public.rentflow_test_invoices (portal_token_hash)
  where portal_token_hash is not null;
