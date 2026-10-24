# HomeOps360 production security review — 24 October 2026

## Release decision

Production remains usable, but the next release should be blocked until the two security warnings below are remediated and rechecked. UAT returned no security or performance advisories, but the project is currently inactive and must be restored before browser UAT.

## Live Supabase advisor results

1. **13 `SECURITY DEFINER` functions have overly broad execute grants.** Trigger-only functions must have `EXECUTE` revoked from `PUBLIC`, `anon`, and `authenticated`. RLS helper functions should normally be callable by `authenticated` only. Review every function before applying grants because several are used inside RLS policies.
2. **Leaked-password protection is disabled.** Enable it in Supabase Auth password security before public launch.
3. Performance advisories include 20 unindexed foreign keys, 22 RLS policies that should wrap `auth.*` calls in `select`, two duplicate permissive policies, and unused-index observations. Address the foreign keys and RLS initialization plans before growth testing; do not remove unused indexes until production traffic is representative.

Remediation references:

- https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable
- https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select

## Required verification

- Re-run Supabase security and performance advisors after every DDL deployment.
- Test cross-owner isolation with two owner accounts and two tenant accounts.
- Confirm tenants cannot read another tenancy, facility, document, bill, payment, or storage object.
- Confirm suspended accounts cannot refresh a session or invoke user-facing Edge Functions.
- Confirm every `verify_jwt=false` Edge Function validates a user token, a single-use business token, or a dedicated cron secret.
- Rotate any secret found in client code or logs; service-role keys must remain server-side only.
