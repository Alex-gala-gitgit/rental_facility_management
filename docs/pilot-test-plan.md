# HomeOps360 pilot test plan

## Participants and duration

Run a two-week pilot with 3–5 property owners/managers and 6–10 tenants. Use UAT accounts and synthetic payment information during week one; permit real operational data only after the security gate is cleared and participants consent.

## Required journeys

| Role | Journey | Success criterion |
|---|---|---|
| Owner | Sign in, create a property and add rooms | Completed without help in under 8 minutes |
| Owner | Invite a tenant and start a tenancy | Invite received and linked to the correct workspace |
| Owner | Issue rent and utility bills | Correct tenant, dates and totals |
| Tenant | Sign in, review a bill and upload proof | Completed on mobile in under 5 minutes |
| Owner | Review payment and update its status | Tenant sees the update without re-entering data |
| Tenant | Create a maintenance request | Owner receives it with the correct property context |
| Both | Complete move-out and settlement | Documents, balances and status remain auditable |

## Evidence to collect

- Task completion rate and time on task.
- Number of facilitator interventions.
- User-rated confidence from 1–5 after each journey.
- Defects with account role, browser/device, steps, expected result, actual result and screenshot.
- API failures, slow requests and interrupted upload behavior during each session.

## Severity and response

- **P0:** data exposure, payment corruption or account takeover — stop the pilot immediately.
- **P1:** core journey cannot complete — fix before the next participant.
- **P2:** workaround exists but causes confusion — include in the next sprint.
- **P3:** cosmetic or minor wording issue — prioritize with other UX work.

## Exit criteria

- 95% or better completion across core journeys.
- No open P0 or P1 defects.
- No cross-account data access.
- At least 4/5 average confidence for billing and payment tasks.
- Production monitoring and rollback ownership confirmed.
