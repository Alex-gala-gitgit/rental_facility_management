# HomeOps360 admin portal deployment

The admin portal is part of the same Flutter web build and switches to the
administration application when the host is `admin.homeops360.app`. During
local development it is also available at `/admin`.

## Security model

- The user first authenticates with a Supabase email one-time password.
- The `admin-console` Edge Function validates the access token and checks the
  server-managed `admin_users` allowlist for every privileged request.
- Service-role credentials are available only inside Edge Functions.
- Owner configuration is readable by that owner through RLS, but can only be
  changed through the audited admin function.
- Admin audit rows cannot be updated or deleted.
- The portal exposes no action for changing historical bills or payments.

## Deployment order

From the linked Supabase project:

```powershell
npx supabase db push
npx supabase functions deploy admin-console
npx supabase functions deploy platform-event --no-verify-jwt
npx supabase functions deploy invoice-portal --no-verify-jwt
npx supabase functions deploy invite-tenant --no-verify-jwt
npx supabase functions deploy meter-reading-ocr --no-verify-jwt
npx supabase functions deploy tenant-profile-invitation --no-verify-jwt
```

Then build and deploy the Flutter web application through the existing
Cloudflare Pages workflow:

```powershell
flutter build web --release
```

In Cloudflare Pages, add `admin.homeops360.app` as a custom domain for the same
Pages project that serves `homeops360.app`. The application chooses the admin
UI from the hostname; no separate build output is required.

## Supabase Auth settings

Add these redirect URLs in Authentication > URL Configuration:

- `https://admin.homeops360.app/`
- the local development URL used for `/admin`

For a six-digit email code, ensure the email OTP template includes
`{{ .Token }}`. If the project keeps the magic-link template, opening the link
still establishes the session and the admin allowlist check runs afterward.

## Bootstrap the administrator

The migration automatically enables `just4u_alex@yahoo.co.uk` when that email
already exists in `profiles`. If the account is created later, run this once in
the Supabase SQL editor after the user confirms their email:

```sql
insert into public.admin_users (user_id, email, display_name, admin_role)
select id, email, coalesce(nullif(full_name, ''), 'Alex Lau'), 'super_admin'
from public.profiles
where lower(email) = 'just4u_alex@yahoo.co.uk'
on conflict (user_id) do update
set email = excluded.email,
    display_name = excluded.display_name,
    admin_role = 'super_admin',
    enabled = true,
    updated_at = now();
```

## Verification checklist

1. An email not present in `admin_users` can authenticate but receives a 403
   and cannot load portal data.
2. The administrator can search multiple owners and open each control centre.
3. Password-reset actions create an immutable audit entry.
4. An owner sees their updated limits/features after signing in again or
   refreshing their cloud workspace.
5. Attempting to add a property, tenant, or Explore listing beyond its limit
   displays an account-limit message.
6. Monthly reports can change month/year but offer no historical edit action.
7. Visits to `homeops360.app` appear in the Overview traffic cards and hourly
   chart after the `platform-event` function is deployed.
8. Calls to every deployed Edge Function appear in **API monitor** after the
   next admin refresh, with endpoint, method, status code and execution time.
9. Browser clients cannot select, insert, update or delete
   `public.api_request_logs`; telemetry access remains server-side.
