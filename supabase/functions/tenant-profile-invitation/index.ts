import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { serveMonitored } from '../_shared/api_monitor.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) =>
  Response.json(body, {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

const base64Url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes))
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '')

const newToken = () => base64Url(crypto.getRandomValues(new Uint8Array(32)))

const tokenHash = async (token: string) => {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(token),
  )
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

const invitationJson = (
  row: Record<string, unknown>,
  token?: string,
  initialDraft?: Record<string, unknown>,
) => ({
  id: row.id,
  ownerId: row.owner_id,
  tenantId: row.tenant_id,
  tenantEmail: row.tenant_email,
  status: row.status,
  expiresAt: row.expires_at,
  token,
  draft:
    Object.keys((row.draft as Record<string, unknown> | null) ?? {}).length > 0
      ? row.draft
      : initialDraft ?? {},
  rejectionReason: row.rejection_reason,
  submittedAt: row.submitted_at,
})

const requireOwner = async (
  request: Request,
  publishableKey: string,
  supabaseUrl: string,
) => {
  const authorization = request.headers.get('Authorization')
  if (!authorization) throw new Error('Owner authentication is required.')
  const caller = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
  })
  const { data, error } = await caller.auth.getUser()
  if (error || !data.user) throw new Error('Your owner session is invalid.')
  return data.user
}

const profileDraft = (user: Record<string, unknown>) => ({
  fullName: user.name ?? '',
  email: user.email ?? '',
  phoneNumber: user.phoneNumber ?? '',
  addressLine1: user.originAddress ?? '',
  addressLine2: '',
  state: user.originState ?? '',
  city: user.originCity ?? '',
  postcode: user.originPostcode ?? '',
  dateOfBirth: user.dateOfBirth ?? '',
  sex: user.sex ?? '',
})

const validateDraft = (value: unknown) => {
  const draft = (value ?? {}) as Record<string, unknown>
  const required = [
    'fullName',
    'email',
    'phoneNumber',
    'addressLine1',
    'state',
    'city',
    'postcode',
    'dateOfBirth',
    'sex',
  ]
  for (const field of required) {
    if (String(draft[field] ?? '').trim().length === 0) {
      throw new Error(`Complete the ${field} field before submitting.`)
    }
  }
  if (!/^\d{5}$/.test(String(draft.postcode))) {
    throw new Error('Enter a valid 5-digit Malaysian postcode.')
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(draft.email).trim())) {
    throw new Error('Enter a valid email address for tenant login.')
  }
  if (!/^[0-9+()\-\s]{8,20}$/.test(String(draft.phoneNumber))) {
    throw new Error('Enter a valid WhatsApp or phone number.')
  }
  if (!['Male', 'Female'].includes(String(draft.sex))) {
    throw new Error('Select Male or Female.')
  }
  return draft
}

serveMonitored('tenant-profile-invitation', async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const publishableKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const admin = createClient(supabaseUrl, serviceRoleKey)
    const body = await request.json()
    const action = String(body.action ?? '')

    if (action === 'create') {
      const owner = await requireOwner(request, publishableKey, supabaseUrl)
      const tenantId = String(body.tenantId ?? '').trim()
      const tenantEmail = String(body.tenantEmail ?? '').trim().toLowerCase()
      if (!tenantId) {
        return json({ error: 'A valid tenant assignment is required.' }, 400)
      }
      const { data: workspace } = await admin
        .from('workspace_snapshots')
        .select('payload')
        .eq('owner_id', owner.id)
        .maybeSingle()
      const assignedUser = ((workspace?.payload?.users ?? []) as Record<string, unknown>[])
        .find((user) => String(user.id) === tenantId)
      if (!workspace || !assignedUser || String(assignedUser.role ?? '') !== 'tenant') {
        return json({ error: 'This tenant is not assigned to the signed-in owner.' }, 403)
      }
      const resolvedTenantEmail = tenantEmail ||
        String(assignedUser.email ?? '').trim().toLowerCase()
      const initialDraft = profileDraft(assignedUser)
      const token = newToken()
      const expiresAt = new Date(Date.now() + 72 * 60 * 60 * 1000).toISOString()
      const { data, error } = await admin
        .from('tenant_profile_invitations')
        .upsert(
          {
            owner_id: owner.id,
            tenant_id: tenantId,
            tenant_email: resolvedTenantEmail,
            token_hash: await tokenHash(token),
            status: 'pending',
            draft: initialDraft,
            rejection_reason: null,
            expires_at: expiresAt,
            updated_at: new Date().toISOString(),
          },
          { onConflict: 'owner_id,tenant_id' },
        )
        .select()
        .single()
      if (error) throw error
      return json(invitationJson(data, token, initialDraft))
    }

    if (action === 'load' || action === 'submit') {
      const token = String(body.token ?? '')
      if (token.length < 20) return json({ error: 'This invitation link is invalid.' }, 400)
      const { data: invitation, error } = await admin
        .from('tenant_profile_invitations')
        .select('*')
        .eq('token_hash', await tokenHash(token))
        .maybeSingle()
      if (error) throw error
      if (!invitation) return json({ error: 'This invitation link is invalid.' }, 404)
      if (new Date(invitation.expires_at).getTime() < Date.now()) {
        return json({ error: 'This invitation link has expired. Ask the owner to resend it.' }, 410)
      }
      const { data: snapshot } = await admin
        .from('tenant_workspace_snapshots')
        .select('payload')
        .eq('owner_id', invitation.owner_id)
        .eq('tenant_email', invitation.tenant_email)
        .maybeSingle()
      const snapshotAssignedUser = ((snapshot?.payload?.users ?? []) as Record<string, unknown>[])
        .find((user) => String(user.id) === invitation.tenant_id)
      const initialDraft = snapshotAssignedUser ? profileDraft(snapshotAssignedUser) : {}
      if (action === 'load') {
        return json(invitationJson(invitation, undefined, initialDraft))
      }
      if (invitation.status === 'granted' || invitation.status === 'approved') {
        return json({ error: 'Tenant access has already been granted.' }, 409)
      }
      const draft = validateDraft(body.draft)
      const loginEmail = String(draft.email).trim().toLowerCase()
      const password = String(body.password ?? '')
      if (
        password.length < 8 ||
        password.length > 72 ||
        !/[A-Za-z]/.test(password) ||
        !/[0-9]/.test(password)
      ) {
        return json({
          error: 'Use 8 or more characters with at least one letter and one number.',
        }, 400)
      }

      const { data: ownerSnapshot, error: ownerSnapshotError } = await admin
        .from('workspace_snapshots')
        .select('payload')
        .eq('owner_id', invitation.owner_id)
        .single()
      if (ownerSnapshotError || !ownerSnapshot?.payload) {
        throw new Error('The owner workspace could not be loaded safely.')
      }
      const assignedUser = ((ownerSnapshot.payload.users ?? []) as Record<string, unknown>[])
        .find((user) => String(user.id) === invitation.tenant_id)
      if (!assignedUser || String(assignedUser.role ?? '') !== 'tenant') {
        return json({ error: 'This invitation is no longer assigned to a tenant.' }, 403)
      }

      const grantedAt = new Date().toISOString()
      const applyDraft = (payload: Record<string, unknown>) => {
        const users = ((payload.users ?? []) as Record<string, unknown>[]).map((user) =>
          String(user.id) === invitation.tenant_id
            ? {
                ...user,
                name: String(draft.fullName).trim(),
                email: loginEmail,
                phoneNumber: String(draft.phoneNumber).trim(),
                originAddress: [draft.addressLine1, draft.addressLine2]
                  .map((item) => String(item ?? '').trim())
                  .filter(Boolean)
                  .join(', '),
                originState: String(draft.state).trim(),
                originCity: String(draft.city).trim(),
                originPostcode: String(draft.postcode).trim(),
                dateOfBirth: String(draft.dateOfBirth),
                sex: String(draft.sex),
                profileComplete: true,
                accountStatus: 'Granted',
                accountCreatedAt: grantedAt,
              }
            : user
        )
        return { ...payload, users }
      }
      const updatedOwnerPayload = applyDraft(ownerSnapshot.payload)
      const tenantOnlyPayload = (payload: Record<string, unknown>) => {
        const records = (key: string) =>
          Array.isArray(payload[key]) ? payload[key] as Record<string, unknown>[] : []
        const tenantTenancies = records('tenancies').filter((item) =>
          String(item.tenantId ?? '') === String(invitation.tenant_id)
        )
        const tenancyIds = new Set(tenantTenancies.map((item) => String(item.id ?? '')))
        const facilityIds = new Set(tenantTenancies.map((item) => String(item.facilityId ?? '')))
        const tenantBills = records('bills').filter((item) =>
          String(item.tenantId ?? '') === String(invitation.tenant_id)
        )
        const billIds = new Set(tenantBills.map((item) => String(item.id ?? '')))
        return {
          ...payload,
          users: records('users').filter((item) =>
            String(item.id ?? '') === String(invitation.tenant_id)
          ),
          facilities: records('facilities').filter((item) =>
            facilityIds.has(String(item.id ?? ''))
          ),
          tenancies: tenantTenancies,
          bills: tenantBills,
          tenantRequests: records('tenantRequests').filter((item) =>
            String(item.tenantId ?? '') === String(invitation.tenant_id)
          ),
          paymentReviewHistory: records('paymentReviewHistory').filter((item) =>
            billIds.has(String(item.billId ?? ''))
          ),
          notifications: [],
          activityHistory: [],
          additionalIncomes: [],
          additionalExpenses: [],
        }
      }
      const tenantPayload = tenantOnlyPayload(updatedOwnerPayload)

      const { data: existingProfile } = await admin
        .from('profiles')
        .select('id,role')
        .ilike('email', loginEmail)
        .maybeSingle()
      if (existingProfile) {
        const { data: existingAssignments } = await admin
          .from('tenant_workspace_snapshots')
          .select('owner_id')
          .eq('tenant_email', loginEmail)
        const belongsToThisOwner = (existingAssignments ?? [])
          .some((item) => String(item.owner_id) === String(invitation.owner_id))
        if (existingProfile.role !== 'tenant' || !belongsToThisOwner) {
          return json({ error: 'This email is already used by another account.' }, 409)
        }
      }

      // Stage the exact owner/tenant relationship before Auth creates the
      // account. The database signup trigger uses this row as its invitation
      // boundary, so possession of an arbitrary email is never sufficient.
      const { error: stageError } = await admin
        .from('tenant_workspace_snapshots')
        .upsert({
          owner_id: invitation.owner_id,
          tenant_email: loginEmail,
          payload: tenantPayload,
          invited_at: grantedAt,
          invitation_sent_by: invitation.owner_id,
          updated_at: grantedAt,
        }, { onConflict: 'owner_id,tenant_email' })
      if (stageError) throw stageError

      let createdUserId: string | undefined
      if (existingProfile) {
        const { error: authUpdateError } = await admin.auth.admin.updateUserById(
          String(existingProfile.id),
          {
            password,
            email_confirm: true,
            user_metadata: { full_name: String(draft.fullName).trim(), role: 'tenant' },
          },
        )
        if (authUpdateError) throw authUpdateError
      } else {
        const { data: created, error: createError } = await admin.auth.admin.createUser({
          email: loginEmail,
          password,
          email_confirm: true,
          user_metadata: { full_name: String(draft.fullName).trim(), role: 'tenant' },
        })
        if (createError) throw createError
        createdUserId = created.user?.id
      }

      try {
        const { error: ownerUpdateError } = await admin
          .from('workspace_snapshots')
          .update({ payload: updatedOwnerPayload, updated_at: grantedAt })
          .eq('owner_id', invitation.owner_id)
        if (ownerUpdateError) throw ownerUpdateError
        const previousEmail = String(invitation.tenant_email ?? '').trim().toLowerCase()
        if (previousEmail && previousEmail !== loginEmail) {
          const { error: oldSnapshotError } = await admin
            .from('tenant_workspace_snapshots')
            .delete()
            .eq('owner_id', invitation.owner_id)
            .eq('tenant_email', previousEmail)
          if (oldSnapshotError) throw oldSnapshotError
        }
        const { data: updated, error: updateError } = await admin
          .from('tenant_profile_invitations')
          .update({
            tenant_email: loginEmail,
            draft,
            status: 'granted',
            rejection_reason: null,
            submitted_at: grantedAt,
            reviewed_at: grantedAt,
            updated_at: grantedAt,
          })
          .eq('id', invitation.id)
          .select()
          .single()
        if (updateError) throw updateError
        await admin.from('owner_notifications').insert({
          owner_id: invitation.owner_id,
          category: 'tenant_profile',
          title: 'Tenant access granted',
          message: `${draft.fullName} completed registration and can now log in.`,
          source_table: 'tenant_profile_invitations',
          source_id: invitation.id,
        })
        return json(invitationJson(updated))
      } catch (error) {
        if (createdUserId) await admin.auth.admin.deleteUser(createdUserId)
        throw error
      }
    }

    if (action === 'list') {
      const owner = await requireOwner(request, publishableKey, supabaseUrl)
      const { data, error } = await admin
        .from('tenant_profile_invitations')
        .select('*')
        .eq('owner_id', owner.id)
        .order('updated_at', { ascending: false })
      if (error) throw error
      return json({ items: (data ?? []).map((row) => invitationJson(row)) })
    }

    if (action === 'review') {
      const owner = await requireOwner(request, publishableKey, supabaseUrl)
      const invitationId = String(body.invitationId ?? '')
      const decision = String(body.decision ?? '')
      const reason = String(body.reason ?? '').trim()
      const { data: invitation, error } = await admin
        .from('tenant_profile_invitations')
        .select('*')
        .eq('id', invitationId)
        .eq('owner_id', owner.id)
        .single()
      if (error) throw error
      if (invitation.status !== 'submitted') {
        return json({ error: 'Only a submitted profile can be reviewed.' }, 409)
      }
      if (decision === 'reject') {
        if (reason.length < 3) {
          return json({ error: 'Enter a clear rejection reason.' }, 400)
        }
        const token = newToken()
        const reviewedAt = new Date().toISOString()
        const { data: rejected, error: rejectError } = await admin
          .from('tenant_profile_invitations')
          .update({
            status: 'rejected',
            rejection_reason: reason,
            token_hash: await tokenHash(token),
            expires_at: new Date(Date.now() + 72 * 60 * 60 * 1000).toISOString(),
            reviewed_at: reviewedAt,
            updated_at: reviewedAt,
          })
          .eq('id', invitation.id)
          .select()
          .single()
        if (rejectError) throw rejectError
        return json(invitationJson(rejected, token))
      }
      if (decision !== 'approve') return json({ error: 'Invalid review decision.' }, 400)

      const draft = validateDraft(invitation.draft)
      const applyDraft = (payload: Record<string, unknown>) => {
        const users = ((payload.users ?? []) as Record<string, unknown>[]).map((user) =>
          String(user.id) === invitation.tenant_id
            ? {
                ...user,
                name: String(draft.fullName).trim(),
                email: invitation.tenant_email,
                phoneNumber: String(draft.phoneNumber).trim(),
                originAddress: [draft.addressLine1, draft.addressLine2]
                  .map((item) => String(item ?? '').trim())
                  .filter(Boolean)
                  .join(', '),
                originState: String(draft.state).trim(),
                originCity: String(draft.city).trim(),
                originPostcode: String(draft.postcode).trim(),
                dateOfBirth: String(draft.dateOfBirth),
                sex: String(draft.sex),
                profileComplete: true,
                accountStatus: 'Active',
                accountCreatedAt: new Date().toISOString(),
              }
            : user
        )
        return { ...payload, users }
      }
      const { data: ownerSnapshot, error: ownerSnapshotError } = await admin
        .from('workspace_snapshots')
        .select('payload')
        .eq('owner_id', owner.id)
        .single()
      const { data: tenantSnapshot, error: tenantSnapshotError } = await admin
        .from('tenant_workspace_snapshots')
        .select('payload')
        .eq('owner_id', owner.id)
        .eq('tenant_email', invitation.tenant_email)
        .single()
      if (ownerSnapshotError || !ownerSnapshot?.payload) {
        throw new Error('The owner workspace could not be loaded safely.')
      }
      if (tenantSnapshotError || !tenantSnapshot?.payload) {
        throw new Error('The tenant assignment could not be loaded safely.')
      }
      const { error: ownerUpdateError } = await admin
        .from('workspace_snapshots')
        .update({ payload: applyDraft(ownerSnapshot.payload) })
        .eq('owner_id', owner.id)
      if (ownerUpdateError) throw ownerUpdateError
      const { error: tenantUpdateError } = await admin
        .from('tenant_workspace_snapshots')
        .update({ payload: applyDraft(tenantSnapshot.payload) })
        .eq('owner_id', owner.id)
        .eq('tenant_email', invitation.tenant_email)
      if (tenantUpdateError) throw tenantUpdateError
      const reviewedAt = new Date().toISOString()
      const { data: approved, error: approveError } = await admin
        .from('tenant_profile_invitations')
        .update({
          status: 'approved',
          rejection_reason: null,
          reviewed_at: reviewedAt,
          updated_at: reviewedAt,
        })
        .eq('id', invitation.id)
        .select()
        .single()
      if (approveError) throw approveError
      return json(invitationJson(approved))
    }

    return json({ error: 'Unsupported invitation action.' }, 400)
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : 'Invitation failed.' },
      400,
    )
  }
})
