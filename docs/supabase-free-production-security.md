# Supabase free production security setup

This setup is suitable for a small pilot with one owner and about five tenants.
It replaces the temporary public test policies with owner-only database access,
private file storage, and expiring tenant invoice links.

## Important before starting

1. Export the current Supabase data from the app's **Data & backup** page.
2. Keep `SUPABASE_SERVICE_ROLE_KEY` and `OPENAI_API_KEY` out of Flutter, GitHub,
   Cloudflare Pages, screenshots, and messages. They belong only in Supabase
   Edge Function secrets.
3. Existing old invoice links will stop working after the migration. Generate
   and send a new secure link for each invoice that a tenant still needs.

## Deployment order

### 1. Deploy the Edge Functions

Deploy these three folders from `supabase/functions`:

- `invoice-portal`
- `invite-tenant`
- `meter-reading-ocr`

For each function, turn **Verify JWT with legacy secret** off. The two owner
actions validate the signed-in user inside the function, while `invoice-portal`
also accepts a long, random, expiring tenant portal token.

In **Edge Functions > Secrets**, add `OPENAI_API_KEY` for meter reading. Supabase
provides `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
`SUPABASE_SERVICE_ROLE_KEY` automatically; do not add these to the web app.

### 2. Apply the database and storage migration

Open **SQL Editor > New query** and run these files in order (they are safe to
run when their columns already exist):

1. `supabase/migrations/202607180001_complete_invoice_payment_flow.sql`
2. `supabase/migrations/202607180002_secure_invoice_portal.sql`
3. `supabase/migrations/202607190001_owner_cloud_bootstrap.sql`
4. `supabase/migrations/202607190002_owner_realtime_notifications.sql`
5. `supabase/migrations/202607200001_owner_payment_details.sql`

Run it once. It will:

- remove anonymous invoice read/write policies;
- allow only a signed-in owner to read and change that owner's invoices;
- make the invoice file bucket private;
- isolate every owner's files under their own user ID folder;
- add hashed, expiring tenant portal tokens;
- prevent a tenant from changing their profile role to owner;
- prevent tenants from seeing facility-wide costs or another tenancy's files;
- store tenant-originated updates as durable owner notifications and deliver
  them immediately through Supabase Realtime while the owner app is open;
- retain the tenant payment details needed for payment-review history and
  expire invoice portal access after 72 hours.

The owner notification bell and unread counter update automatically for tenant
requests, tenant profile/workspace changes, and payment-proof submissions. If
the owner app is closed, the notification remains unread and appears at the
next sign-in. A true operating-system notification while the app is completely
closed additionally requires Android/iOS push credentials (FCM/APNs); do not
place those credentials in the Flutter application.

After it succeeds, check **Storage > rentflow-test-files** and confirm the bucket
is marked **Private**.

### 3. Configure Authentication

In **Authentication > URL Configuration** set:

- Site URL: `https://homeops360.app`
- Redirect URL: `https://homeops360.app/**`
- Fallback redirect URL: `https://facility-billing-management.pages.dev/**`

Keep public owner sign-up disabled once the first owner account exists. Tenant
accounts should continue to be created only from an owner invitation.

For real tenant invitations, configure a custom SMTP provider. The built-in
Supabase email sender is intended for testing and has low limits.

### 4. Deploy the matching Cloudflare web build

Upload the secure web deployment ZIP produced from `build/web`. Do not upload
an APK inside the Cloudflare Pages package. Cloudflare Pages should receive only
the web files such as `index.html`, `main.dart.js`, `assets`, and `canvaskit`.

### 5. Test before sending a real bill

Use a test invoice and verify all of these:

1. Owner signs in successfully.
2. Owner creates a utility invoice and opens its PDF.
3. WhatsApp contains an HTTPS link with both `invoice` and `token` parameters.
4. The tenant link opens in a private/incognito browser.
5. Tenant uploads one payment proof below 2 MB.
6. Owner receives the pending review and can open the proof.
7. An anonymous browser cannot list invoices or open a raw storage path.

## Free-plan operating routine

- Export a backup after every billing cycle and keep a second copy outside
  Supabase.
- Log in regularly; inactive free projects can be paused.
- Review **Database > Security Advisor** after every schema change.
- Upgrade before the app becomes business-critical or exceeds free quotas, so
  scheduled backups, higher email limits, and stronger operational support are
  available.
