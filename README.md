# HomeOps360

A Flutter and Supabase rental operations platform for owners, managers, tenants, and administrators:

- Owner: create facilities, monitor rent/utilities, approve tenant payment slips, and view dashboard reports.
- Tenant: review bills, submit payment proof, create requests, explore listings, and track move-out.
- Administrator: manage access, subscriptions, operational issues, and API health.

The current application uses Supabase Auth, Postgres with row-level security, Storage, Realtime, and Edge Functions. A local data mode remains available for development and automated tests.

## Run

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-16\rental management\rental_facility_management"
flutter pub get
dart run tool/check_release_readiness.dart
flutter analyze
flutter test
flutter run
```

The Splitz group-bill experience is available in the web build at `/splitz/`.
It supports multiple contributors per item, equal participant splitting, and
optimized net settlements across multiple items.

If platform folders are missing because `flutter create` did not finish, run this inside the project folder:

```powershell
flutter create .
flutter run
```

## Release and operations

Pull requests and changes to `main` run analysis, tests, security/configuration checks, and a release web build. Web releases are manually dispatched to the protected `uat` or `production` GitHub environment and deploy only after all gates pass.

- UAT: https://facility-billing-management.pages.dev
- Production: https://homeops360.app
- Release runbook: `docs/release-operations.md`
- Security review: `docs/security-review-2026-10-24.md`
- Pilot plan: `docs/pilot-test-plan.md`
