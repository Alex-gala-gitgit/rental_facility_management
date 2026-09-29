alter table public.profiles
  add column if not exists guided_tours jsonb not null default '{}'::jsonb;

alter table public.profiles
  drop constraint if exists profiles_guided_tours_object;

alter table public.profiles
  add constraint profiles_guided_tours_object
  check (jsonb_typeof(guided_tours) = 'object');

comment on column public.profiles.guided_tours is
  'Per-account role-specific tour state. Keys are versioned, for example owner_v1 and tenant_v1.';
