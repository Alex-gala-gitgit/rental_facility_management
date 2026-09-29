-- Let owners and property agents highlight selected listings for the future
-- tenant Explore reopening. Existing listings remain unpromoted by default.

alter table public.room_listings
  add column if not exists is_featured boolean not null default false;

drop index if exists public.room_listings_public_feed_idx;
create index room_listings_public_feed_idx
  on public.room_listings (status, is_featured desc, created_at desc);
