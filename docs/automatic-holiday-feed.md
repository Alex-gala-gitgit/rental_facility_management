# Automatic Malaysian holiday calendar

The app requests `/api/malaysia-holidays?year=YYYY` on calendar startup,
month navigation, app resume and hourly while the calendar remains mounted.
Successful results refresh at most daily, with a one-hour retry backoff for
unpublished schedules or outages. Current and next-year schedules are prefetched.
Verified dates are cached in browser/device storage; there is no Codex automation.

The Cloudflare Pages Function discovers annual HKA PDFs from the official BKPP
index, validates the known 16-state matrix layout, and returns dates and state
applicability. Unsupported layouts or incomplete documents return an error,
never fabricated dates. Responses are cached at the edge for 24 hours.

Deployment: run `npm ci --ignore-scripts`, build Flutter web, and deploy the
existing Pages project from the repository root so Wrangler includes `functions/`.
No Supabase schema, credentials, paid API or scheduled job is required.
Packaged apps use the production endpoint. Web apps use their own origin.

This imports **annual schedules**, not arbitrary later ad-hoc state gazettes or
employer-dependent replacement days. The separately verified 2026 supplements
remain bundled. New/unknown holiday names retain the original Malay title.
If the government changes its PDF layout, a parser update is required.

Verification: `node tool/test_holiday_feed.mjs` checks real 2026 and 2027 PDFs.
Run `flutter test test/holiday_feed_test.dart test/malaysia_holidays_test.dart
test/tenancy_calendar_test.dart` for cache, outage and state-filtering regression tests.
