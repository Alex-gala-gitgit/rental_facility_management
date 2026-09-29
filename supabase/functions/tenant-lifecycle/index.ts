import { createClient } from 'npm:@supabase/supabase-js@2.57.4'
import { serveMonitored } from '../_shared/api_monitor.ts'

type JsonRecord = Record<string, unknown>

function response(body: unknown, status = 200) {
  return Response.json(body, {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function lifecycleTenancy(payload: JsonRecord): JsonRecord | null {
  const tenancies = Array.isArray(payload.tenancies)
    ? payload.tenancies as JsonRecord[]
    : []
  return tenancies.find((item) => String(item.lastActiveDate ?? '').length >= 10) ?? null
}

function singaporeMidnightAfter(dateValue: unknown): Date | null {
  const match = String(dateValue ?? '').match(/^(\d{4})-(\d{2})-(\d{2})/)
  if (!match) return null
  const [, year, month, day] = match
  return new Date(Date.UTC(Number(year), Number(month) - 1, Number(day) + 1, -8))
}

serveMonitored('tenant-lifecycle', async (request) => {
  if (request.method !== 'POST') return response({ error: 'Method not allowed.' }, 405)

  const configuredSecret = Deno.env.get('TENANT_LIFECYCLE_CRON_SECRET') ?? ''
  const suppliedSecret = request.headers.get('x-lifecycle-secret') ?? ''
  if (!configuredSecret || suppliedSecret !== configuredSecret) {
    return response({ error: 'Unauthorized.' }, 401)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: assignments, error } = await admin
    .from('tenant_workspace_snapshots')
    .select('owner_id,tenant_id,payload')
    .not('tenant_id', 'is', null)
  if (error) return response({ error: error.message }, 500)

  const now = new Date()
  let reviewed = 0
  let suspended = 0
  let restored = 0
  const failures: string[] = []

  for (const assignment of assignments ?? []) {
    const tenantId = String(assignment.tenant_id ?? '')
    if (!tenantId) continue
    reviewed += 1
    try {
      const tenancy = lifecycleTenancy(assignment.payload as JsonRecord)
      const inactiveFrom = tenancy == null
        ? null
        : singaporeMidnightAfter(tenancy.lastActiveDate)
      const { data: authData, error: authError } =
        await admin.auth.admin.getUserById(tenantId)
      if (authError || !authData.user) throw authError ?? new Error('Auth user not found.')

      const appMetadata = authData.user.app_metadata ?? {}
      const lifecycleSuspended = appMetadata.tenant_lifecycle_suspended === true
      const activeAgain = tenancy == null ||
        tenancy.active === true && inactiveFrom != null && now < inactiveFrom

      if (activeAgain && lifecycleSuspended) {
        const nextMetadata = { ...appMetadata }
        delete nextMetadata.tenant_lifecycle_suspended
        delete nextMetadata.tenant_lifecycle_owner_id
        await admin.auth.admin.updateUserById(tenantId, {
          ban_duration: 'none',
          app_metadata: nextMetadata,
        })
        restored += 1
        continue
      }

      if (inactiveFrom == null || now < inactiveFrom || lifecycleSuspended) continue
      const lastSignIn = authData.user.last_sign_in_at
        ? new Date(authData.user.last_sign_in_at)
        : null
      const sevenDaysAfter = new Date(inactiveFrom.getTime() + 7 * 86_400_000)
      const oneMonthAfter = new Date(Date.UTC(
        inactiveFrom.getUTCFullYear(),
        inactiveFrom.getUTCMonth() + 1,
        inactiveFrom.getUTCDate(),
        inactiveFrom.getUTCHours(),
      ))
      const missedGraceLogin = now >= sevenDaysAfter &&
        (lastSignIn == null || lastSignIn < inactiveFrom)
      const reactivationExpired = now >= oneMonthAfter
      if (!missedGraceLogin && !reactivationExpired) continue

      const { error: suspendError } = await admin.auth.admin.updateUserById(
        tenantId,
        {
          ban_duration: '876000h',
          app_metadata: {
            ...appMetadata,
            tenant_lifecycle_suspended: true,
            tenant_lifecycle_owner_id: assignment.owner_id,
          },
        },
      )
      if (suspendError) throw suspendError
      suspended += 1
    } catch (caught) {
      console.error('Tenant lifecycle processing failed:', tenantId, caught)
      failures.push(tenantId)
    }
  }

  return response({ reviewed, suspended, restored, failures })
})
