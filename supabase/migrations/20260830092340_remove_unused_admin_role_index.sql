-- The allowlist is intentionally small and is always returned as one ordered
-- directory, so a role/status index adds write overhead without helping the
-- current access pattern.
drop index if exists public.admin_users_role_enabled_idx;
