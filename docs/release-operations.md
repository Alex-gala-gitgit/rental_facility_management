# HomeOps360 release operations

## GitHub configuration

Create protected GitHub environments named `uat` and `production`. Require reviewer approval for `production`.

Set these values in each environment:

- Secret `CLOUDFLARE_API_TOKEN`
- Secret `CLOUDFLARE_ACCOUNT_ID`
- Variable `CLOUDFLARE_PAGES_PROJECT`
- Variable `HOMEOPS_BASE_URL`
- Variable `HOMEOPS_SUPABASE_URL`
- Secret `HOMEOPS_SUPABASE_KEY`
- Optional secret `HOMEOPS_UAT_ACCESS_TOKEN` for authenticated UAT smoke testing

For the scheduled production monitor, set repository secrets:

- `PRODUCTION_SUPABASE_URL`
- `PRODUCTION_SUPABASE_SERVICE_ROLE_KEY`
- `PRODUCTION_ALERT_WEBHOOK_URL`

The service-role key is used only by the GitHub runner to read restricted telemetry. Never expose it as a Flutter build argument, browser variable, repository variable, or log value.

The `uat` environment values above also power the scheduled UAT Supabase
keep-alive. It makes a read-only database request three times daily and fails
the workflow if either value is missing. After setup, manually run **Keep UAT
Supabase active** once from GitHub Actions and confirm it succeeds.

This keep-alive reduces the chance that a lightly used Free project is paused,
but Supabase does not guarantee that any fixed request count will prevent a
pause. Upgrade the organization to Pro when continuous availability is
required; paid projects are not paused for inactivity.

## Release procedure

1. Merge only when **Quality gate** passes.
2. Run **Release web**, choosing `uat`.
3. Complete the owner and tenant smoke journeys and review API telemetry.
4. Run **Release web**, choosing `production`; the protected environment requires approval.
5. Confirm the deployed version metadata and monitor the first 30 minutes for errors.

## Rollback

Use Cloudflare Pages deployment history to promote the previous known-good deployment. Record the failed commit, symptoms, affected roles, start/end time, and any database or Edge Function changes that need separate reversal.
