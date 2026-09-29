-- Tenant onboarding is completed directly from the secure 72-hour invitation.
-- "pending" means the owner has prepared/sent access; "granted" means the
-- tenant confirmed the profile and created login credentials.
alter table public.tenant_profile_invitations
  drop constraint if exists tenant_profile_invitations_status_check;

alter table public.tenant_profile_invitations
  add constraint tenant_profile_invitations_status_check
  check (status in (
    'invited', 'pending', 'granted',
    'submitted', 'approved', 'rejected'
  ));

comment on column public.tenant_profile_invitations.status is
  'Current onboarding state. New workflow uses pending and granted; older states remain readable for migration compatibility.';
