# Centralized move-out settlement records

Settlement metadata and attachment bytes are retained in the owner-scoped
`move_out_settlements.payload` record. The generated PDF, including its evidence
pages, is stored in the private `move-out-settlements` Storage bucket. Tenant,
tenancy and facility identifiers accompany records saved by the app.

Cloud reads are authoritative. Opening a tenant profile or settlement from the
original browser migrates its existing local snapshot only if no cloud record
exists. Local backups are retained. A network error does not fall back to a
potentially stale local record and does not claim that a cloud save succeeded.

Concurrent updates use revision checks. Reopen the settlement after a conflict.
New PDFs are uploaded to immutable paths before the database pointer changes;
failed saves attempt to remove only the new unreferenced object. Previous PDF
versions remain private. Download/View uses the stored PDF rather than silently
regenerating a different invoice.

Access requires the authenticated owning account and the existing owner-role
check. The bucket is not public. Service-role keys are never used in the app.
This does not grant tenant or unrelated-owner access, or add staff sharing.

Production schema is configured. UAT's Supabase project is inactive; apply the
migration after it is restored. Frontend deployment is a separate release step.
After release, open existing profiles on the original device to migrate their
records, then verify retrieval while signed into that same owner account on a
second device. Do not clear browser data before migration succeeds.
