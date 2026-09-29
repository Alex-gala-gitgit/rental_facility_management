import { createClient } from 'npm:@supabase/supabase-js@2.57.4'
import { serveMonitored } from '../_shared/api_monitor.ts'

const allowedOrigins = new Set([
  'https://admin.homeops360.app',
  'https://homeops360.app',
  'https://www.homeops360.app',
  'https://facility-billing-management.pages.dev',
])

const founderEmails = new Set([
  'lauyikfei@gmail.com',
  'just4u_alex@yahoo.co.uk',
])

function isFounderEmail(value: unknown) {
  return founderEmails.has(String(value ?? '').trim().toLowerCase())
}

function isFounderAdmin(email: unknown, role: unknown) {
  return isFounderEmail(email) && String(role ?? '') === 'founder'
}

function corsHeaders(request: Request) {
  const origin = request.headers.get('Origin') ?? ''
  const allowed = allowedOrigins.has(origin) ||
    origin.startsWith('http://localhost:') ||
    origin.startsWith('http://127.0.0.1:')
  return {
    'Access-Control-Allow-Origin': allowed ? origin : 'https://admin.homeops360.app',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  }
}

function json(request: Request, body: unknown, status = 200) {
  return Response.json(body, {
    status,
    headers: { ...corsHeaders(request), 'Content-Type': 'application/json' },
  })
}

function records(value: unknown): Record<string, unknown>[] {
  return Array.isArray(value)
    ? value.filter((item): item is Record<string, unknown> => Boolean(item) && typeof item === 'object')
    : []
}

function numberValue(value: unknown) {
  const result = Number(value ?? 0)
  return Number.isFinite(result) ? result : 0
}

function currentMonthStart() {
  const now = new Date()
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-01`
}

function subscriptionExpiry(period: string, from = new Date()) {
  const expires = new Date(from)
  if (period === 'annual') expires.setUTCFullYear(expires.getUTCFullYear() + 1)
  else expires.setUTCMonth(expires.getUTCMonth() + 1)
  return expires.toISOString()
}

function monthKey(value: unknown) {
  const text = String(value ?? '')
  return text.length >= 7 ? text.substring(0, 7) : ''
}

function billTotal(bill: Record<string, unknown>) {
  return numberValue(bill.rentAmount) +
    numberValue(bill.electricityAmount) +
    numberValue(bill.generalElectricAmount) +
    numberValue(bill.waterAmount) +
    numberValue(bill.internetAmount) +
    numberValue(bill.parkingRentalAmount)
}

function monthNumber(reportMonth: string) {
  const result = Number(reportMonth.substring(5, 7))
  return Number.isInteger(result) && result >= 1 && result <= 12 ? result : 1
}

function effectiveMonthKey(value: unknown) {
  const key = monthKey(value)
  return /^\d{4}-\d{2}$/.test(key) ? key : ''
}

function latestEffectiveRecord(
  values: unknown,
  reportMonth: string,
  fallback: Record<string, unknown>,
) {
  const eligible = records(values).filter((item) => {
    const effective = effectiveMonthKey(item.effectiveMonth)
    return effective && effective <= reportMonth
  })
  if (!eligible.length) return fallback
  return eligible.reduce((current, next) => {
    const currentMonth = effectiveMonthKey(current.effectiveMonth)
    const nextMonth = effectiveMonthKey(next.effectiveMonth)
    if (nextMonth !== currentMonth) return nextMonth > currentMonth ? next : current
    const currentRecorded = String(current.recordedAt ?? '')
    const nextRecorded = String(next.recordedAt ?? '')
    if (current.initial === true || nextRecorded > currentRecorded) return next
    return current
  })
}

function commitmentIsDue(frequency: unknown, firstDueMonth: unknown, month: number) {
  const first = Math.max(1, Math.min(12, Math.trunc(numberValue(firstDueMonth) || 1)))
  const offset = ((month - first) % 12 + 12) % 12
  switch (String(frequency ?? 'monthly')) {
    case 'quarterly': return offset % 3 === 0
    case 'halfYearly': return offset % 6 === 0
    case 'yearly': return offset === 0
    default: return true
  }
}

function commitmentAmountForMonth(
  commitment: Record<string, unknown>,
  reportMonth: string,
) {
  const history = records(commitment.history)
  const firstEffective = history
    .map((item) => effectiveMonthKey(item.effectiveMonth))
    .filter(Boolean)
    .sort()[0]
  if (firstEffective && reportMonth < firstEffective) return 0
  const version = latestEffectiveRecord(history, reportMonth, commitment)
  return commitmentIsDue(version.frequency, version.firstDueMonth, monthNumber(reportMonth))
    ? numberValue(version.amount)
    : 0
}

function facilityExpenseForMonth(
  facility: Record<string, unknown>,
  additionalExpenses: Record<string, unknown>[],
  reportMonth: string,
) {
  const facilityId = String(facility.id ?? '')
  const oneTimeExpenses = additionalExpenses
    .filter((expense) =>
      String(expense.facilityId ?? '') === facilityId &&
      monthKey(expense.month) === reportMonth)
    .reduce((sum, expense) => sum + numberValue(expense.amount), 0)
  const cost = latestEffectiveRecord(facility.costHistory, reportMonth, facility)
  const month = monthNumber(reportMonth)
  const insuranceDueMonth = Math.max(1, Math.min(12, Math.trunc(numberValue(cost.insuranceDueMonth) || 1)))
  const insuranceDue = month === insuranceDueMonth ||
    (String(cost.insuranceFrequency ?? 'yearly') === 'halfYearly' &&
      month === ((insuranceDueMonth + 5) % 12) + 1)
  const insurance = insuranceDue ? numberValue(cost.insuranceFee) : 0
  const commitments = records(facility.extraCommitments)

  if (String(facility.status ?? 'ready') === 'developing') {
    const progression = commitments.filter((item) => String(item.name ?? '') === 'Progression Fee')
    const developmentCost = progression.length
      ? progression.reduce((sum, item) => sum + commitmentAmountForMonth(item, reportMonth), 0)
      : numberValue(facility.progressionFee)
    return developmentCost + insurance + oneTimeExpenses
  }

  const recurringCommitments = commitments.reduce(
    (sum, item) => sum + commitmentAmountForMonth(item, reportMonth),
    0,
  )
  return numberValue(cost.installmentAmount) +
    numberValue(cost.extraInstallmentPayment) +
    numberValue(cost.maintenanceFee) +
    insurance +
    recurringCommitments +
    oneTimeExpenses
}

function booleanValue(value: unknown, field: string) {
  if (typeof value !== 'boolean') throw new Error(`${field} must be true or false.`)
  return value
}

function integerLimit(value: unknown, field: string, maximum: number) {
  const result = Number(value)
  if (!Number.isInteger(result) || result < 0 || result > maximum) {
    throw new Error(`${field} must be a whole number from 0 to ${maximum}.`)
  }
  return result
}

function stringField(value: unknown, field: string, maximum = 300, required = true) {
  const result = String(value ?? '').trim()
  if (required && !result) throw new Error(`${field} is required.`)
  if (result.length > maximum) throw new Error(`${field} is too long.`)
  return result
}

function moneyValue(value: unknown, field: string) {
  const result = Number(value)
  if (!Number.isFinite(result) || result < 0 || result > 100000000) {
    throw new Error(`${field} must be a valid non-negative amount.`)
  }
  return Math.round(result * 100) / 100
}

function replaceRecord(
  payload: Record<string, unknown>,
  collection: string,
  id: string,
  transform: (record: Record<string, unknown>) => Record<string, unknown>,
) {
  const list = records(payload[collection])
  const index = list.findIndex((item) => String(item.id ?? '') === id)
  if (index < 0) throw new Error(`The selected ${collection} record could not be found.`)
  const before = { ...list[index] }
  list[index] = transform({ ...list[index] })
  payload[collection] = list
  return { before, after: list[index] }
}

async function listAllAuthUsers(adminClient: any) {
  const output: Record<string, unknown>[] = []
  for (let page = 1; page <= 100; page++) {
    const { data, error } = await adminClient.auth.admin.listUsers({ page, perPage: 1000 })
    if (error) throw error
    const users = data.users as unknown as Record<string, unknown>[]
    output.push(...users)
    if (users.length < 1000) break
  }
  return output
}

async function requireAdmin(request: Request) {
  const authorization = request.headers.get('Authorization')
  if (!authorization) throw new Error('Administrator authentication is required.')

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const publishableKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const secretKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const caller = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: authData, error: authError } = await caller.auth.getUser()
  if (authError || !authData.user?.email) {
    throw new Error('The administrator session is invalid or expired.')
  }

  const adminClient = createClient(supabaseUrl, secretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: adminUser, error: adminError } = await adminClient
    .from('admin_users')
    .select('user_id,email,display_name,admin_role,enabled')
    .eq('user_id', authData.user.id)
    .maybeSingle()
  if (adminError) throw adminError
  if (!adminUser?.enabled || String(adminUser.email).toLowerCase() !== authData.user.email.toLowerCase()) {
    return { denied: true as const, adminClient, authUser: authData.user }
  }
  return { denied: false as const, adminClient, authUser: authData.user, adminUser }
}

async function audit(
  adminClient: any,
  adminUserId: string,
  action: string,
  targetType: string,
  targetId: string | null,
  beforeValue?: unknown,
  afterValue?: unknown,
) {
  const { error } = await adminClient.from('admin_audit_logs').insert({
    admin_user_id: adminUserId,
    action,
    target_type: targetType,
    target_id: targetId,
    before_value: beforeValue ?? null,
    after_value: afterValue ?? null,
  })
  if (error) throw error
}

function defaultOwnerConfig(ownerId: string) {
  return {
    owner_id: ownerId,
    property_limit: 1,
    tenant_limit: 2,
    explore_listing_limit: 0,
    electricity_tariff_enabled: false,
    explore_promotion_enabled: false,
    advanced_export_enabled: true,
    meter_hardware_enabled: false,
    membership_tier: 'free',
    subscription_status: 'active',
    unlimited_access: false,
    announcements_enabled: false,
    marketplace_enabled: false,
    priority_support_enabled: false,
    effective_from: currentMonthStart(),
  }
}

function ownerSummary(
  profile: Record<string, unknown>,
  authUser: Record<string, unknown> | undefined,
  snapshot: Record<string, unknown> | undefined,
  configRow: Record<string, unknown> | undefined,
  reportMonth: string,
) {
  const ownerId = String(profile.id ?? '')
  const payload = snapshot?.payload as Record<string, unknown> | undefined
  const allFacilities = records(payload?.facilities)
  const facilities = allFacilities.filter((item) => String(item.status ?? '') !== 'sold')
  const users = records(payload?.users)
  const tenantUsers = users.filter((item) => String(item.role ?? '') === 'tenant')
  const allTenancies = records(payload?.tenancies)
  const tenancies = allTenancies.filter((item) => item.active !== false)
  const bills = records(payload?.bills).filter((item) => monthKey(item.month) === reportMonth)
  const additionalExpenses = records(payload?.additionalExpenses)
  const facilityById = new Map(allFacilities.map((facility) => [String(facility.id), facility]))
  const userById = new Map(users.map((user) => [String(user.id), user]))
  const invoiceTotal = bills.reduce((sum, bill) => sum + billTotal(bill), 0)
  const amountPaid = bills.reduce((sum, bill) => sum + numberValue(bill.amountPaid), 0)
  const facilityExpenses = new Map(facilities.map((facility) => [
    String(facility.id),
    facilityExpenseForMonth(facility, additionalExpenses, reportMonth),
  ]))
  const expenses = Array.from(facilityExpenses.values()).reduce((sum, amount) => sum + amount, 0)
  const completeBills = bills.filter((bill) => String(bill.status ?? '') === 'approved').length
  const reviewBills = bills.filter((bill) => String(bill.status ?? '') === 'pendingApproval').length
  const config = { ...defaultOwnerConfig(ownerId), ...(configRow ?? {}) }
  const userMetadata = (authUser?.user_metadata ?? {}) as Record<string, unknown>
  return {
    id: ownerId,
    email: String(profile.email ?? authUser?.email ?? ''),
    name: String(profile.full_name ?? userMetadata.full_name ?? 'Owner'),
    status: authUser?.banned_until ? 'suspended' : 'active',
    createdAt: authUser?.created_at ?? profile.created_at,
    lastLoginAt: authUser?.last_sign_in_at ?? null,
    properties: facilities.length,
    tenants: tenantUsers.length || tenancies.length,
    invoices: bills.length,
    completeBills,
    reviewBills,
    billed: Math.round(invoiceTotal * 100) / 100,
    collected: Math.round(amountPaid * 100) / 100,
    expenses: Math.round(expenses * 100) / 100,
    netCashFlow: Math.round((amountPaid - expenses) * 100) / 100,
    expenseCoverage: expenses > 0 ? Math.round((amountPaid / expenses) * 1000) / 10 : null,
    collectionRate: invoiceTotal > 0 ? Math.round((amountPaid / invoiceTotal) * 1000) / 10 : null,
    workspaceUpdatedAt: snapshot?.updated_at ?? null,
    config,
    propertyRecords: allFacilities.map((facility) => {
      const facilityBills = bills.filter((bill) => String(bill.facilityId) === String(facility.id))
      const facilityBilled = facilityBills.reduce((sum, bill) => sum + billTotal(bill), 0)
      const facilityCollected = facilityBills.reduce((sum, bill) => sum + numberValue(bill.amountPaid), 0)
      return {
        id: facility.id,
        name: facility.name,
        addressLine: facility.addressLine ?? '',
        postcode: facility.postcode ?? '',
        city: facility.city ?? '',
        state: facility.state ?? '',
        address: [facility.addressLine, facility.postcode, facility.city, facility.state].filter(Boolean).join(', '),
        status: facility.status ?? 'ready',
        invoices: facilityBills.length,
        billed: Math.round(facilityBilled * 100) / 100,
        collected: Math.round(facilityCollected * 100) / 100,
        expenses: Math.round((facilityExpenses.get(String(facility.id)) ?? 0) * 100) / 100,
      }
    }),
    tenantRecords: allTenancies.map((tenancy) => {
      const tenant = userById.get(String(tenancy.tenantId))
      const facility = facilityById.get(String(tenancy.facilityId))
      return {
        id: tenancy.id,
        userId: tenancy.tenantId,
        name: tenant?.name ?? 'Tenant',
        email: tenant?.email ?? '',
        phoneNumber: tenant?.phoneNumber ?? '',
        accountStatus: tenant?.accountStatus ?? 'Active',
        property: facility?.name ?? 'Unknown property',
        unit: tenancy.unitName ?? '',
        rent: numberValue(tenancy.monthlyRent),
        leaseEnd: tenancy.leaseEnd ?? null,
        leaseStart: tenancy.leaseStart ?? null,
        status: tenancy.active === false ? 'inactive' : 'active',
      }
    }),
    billRecords: bills.map((bill) => {
      const tenant = userById.get(String(bill.tenantId))
      const facility = facilityById.get(String(bill.facilityId))
      return {
        id: bill.id,
        month: bill.month,
        property: facility?.name ?? 'Unknown property',
        tenant: tenant?.name ?? 'Tenant',
        total: Math.round(billTotal(bill) * 100) / 100,
        rentAmount: numberValue(bill.rentAmount),
        electricityAmount: numberValue(bill.electricityAmount),
        generalElectricAmount: numberValue(bill.generalElectricAmount),
        waterAmount: numberValue(bill.waterAmount),
        internetAmount: numberValue(bill.internetAmount),
        parkingRentalAmount: numberValue(bill.parkingRentalAmount),
        paid: Math.round(numberValue(bill.amountPaid) * 100) / 100,
        status: bill.status ?? 'pending',
        paymentDate: bill.paymentDate ?? null,
        paymentReference: bill.paymentReference ?? null,
        editable: reportMonth === currentMonthStart().substring(0, 7),
      }
    }),
  }
}

async function buildConsoleData(
  adminClient: any,
  requestedMonth?: string,
  canViewOwnerDetails = false,
) {
  const reportMonth = /^\d{4}-\d{2}$/.test(requestedMonth ?? '')
    ? requestedMonth!
    : currentMonthStart().substring(0, 7)
  const apiWindowStart = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
  const [
    authUsers,
    profilesResult,
    adminUsersResult,
    snapshotsResult,
    configsResult,
    trafficResult,
    auditsResult,
    requestsResult,
    issuesResult,
    apiRequestsResult,
    apiFailuresResult,
    resourceUsageResult,
    membershipsResult,
    subscriptionRequestsResult,
    subscriptionPlansResult,
  ] = await Promise.all([
    listAllAuthUsers(adminClient),
    adminClient.from('profiles').select('id,email,full_name,role,created_at,updated_at'),
    adminClient.from('admin_users')
      .select('user_id,email,display_name,admin_role,enabled,created_by,created_at,updated_at,last_verified_at')
      .order('created_at'),
    adminClient.from('workspace_snapshots').select('owner_id,payload,updated_at'),
    adminClient.from('owner_access_configs').select('*'),
    adminClient.from('platform_events').select('event_type,visitor_key,path,user_id,user_role,occurred_at')
      .gte('occurred_at', `${new Date().toISOString().substring(0, 10)}T00:00:00.000Z`),
    adminClient.from('admin_audit_logs').select('id,admin_user_id,action,target_type,target_id,created_at')
      .order('created_at', { ascending: false }).limit(30),
    adminClient.from('customize_requests').select('*')
      .order('created_at', { ascending: false }).limit(500),
    adminClient.from('app_issue_reports').select(
      'id,reporter_id,reporter_email,reporter_name,reporter_role,category,title,description,severity,status,attachment_name,attachment_mime,app_language,source,admin_notes,created_at,updated_at'
    )
      .order('created_at', { ascending: false }).limit(500),
    adminClient.from('api_request_logs')
      .select('request_id,function_name,method,status_code,duration_ms,error_code,created_at', { count: 'exact' })
      .gte('created_at', apiWindowStart)
      .order('created_at', { ascending: false })
      .limit(1000),
    adminClient.from('api_request_logs')
      .select('id', { count: 'exact', head: true })
      .gte('created_at', apiWindowStart)
      .gte('status_code', 400),
    adminClient.rpc('admin_project_resource_usage'),
    adminClient.from('account_memberships').select('*'),
    adminClient.from('subscription_requests').select('*')
      .order('created_at', { ascending: false }).limit(500),
    adminClient.from('subscription_plans').select('*').order('monthly_price'),
  ])
  for (const result of [
    profilesResult,
    adminUsersResult,
    snapshotsResult,
    configsResult,
    trafficResult,
    auditsResult,
    requestsResult,
    issuesResult,
    apiRequestsResult,
    apiFailuresResult,
    resourceUsageResult,
    membershipsResult,
    subscriptionRequestsResult,
    subscriptionPlansResult,
  ]) {
    if (result.error) throw result.error
  }

  const profiles = (profilesResult.data ?? []) as Record<string, unknown>[]
  const snapshots = (snapshotsResult.data ?? []) as Record<string, unknown>[]
  const configs = (configsResult.data ?? []) as Record<string, unknown>[]
  const authById = new Map(authUsers.map((user) => [String(user.id), user]))
  const visibleProfiles = profiles.filter((profile) =>
    !authById.get(String(profile.id))?.deleted_at
  )
  const snapshotByOwner = new Map(snapshots.map((row) => [String(row.owner_id), row]))
  const configByOwner = new Map(configs.map((row) => [String(row.owner_id), row]))
  const membershipByUser = new Map(
    ((membershipsResult.data ?? []) as Record<string, unknown>[])
      .map((row) => [String(row.user_id), row]),
  )
  const adminMembers = ((adminUsersResult.data ?? []) as Record<string, unknown>[])
    .map((member) => {
      const authUser = authById.get(String(member.user_id))
      return {
        ...member,
        level: member.admin_role,
        status: member.enabled === true ? 'active' : 'revoked',
        lastLoginAt: authUser?.last_sign_in_at ?? null,
        emailConfirmedAt: authUser?.email_confirmed_at ?? null,
      }
    })
    .sort((a, b) => {
      const rank = (value: unknown) => String(value) === 'founder' ? 0 : 1
      return rank(a.level) - rank(b.level) || String(a.display_name).localeCompare(String(b.display_name))
    })
  const owners = visibleProfiles
    .filter((profile) => String(profile.role) === 'owner')
    .map((profile) => ownerSummary(
      profile,
      authById.get(String(profile.id)),
      snapshotByOwner.get(String(profile.id)),
      configByOwner.get(String(profile.id)),
      reportMonth,
    ))
    .sort((a, b) => a.name.localeCompare(b.name))

  const ownerNameById = new Map(owners.map((owner) => [owner.id, owner.name]))
  const workspaceActivity = snapshots.flatMap((snapshot) => {
    const payload = snapshot.payload as Record<string, unknown> | undefined
    return records(payload?.activityHistory).map((item) => ({
      id: `${snapshot.owner_id}:${item.id ?? item.timestamp ?? crypto.randomUUID()}`,
      action: String(item.action ?? 'Workspace updated'),
      target_type: 'workspace',
      target_id: String(snapshot.owner_id),
      actor: ownerNameById.get(String(snapshot.owner_id)) ?? 'Owner',
      created_at: item.timestamp ?? snapshot.updated_at,
      source: 'owner',
    }))
  })
  const adminActivity = ((auditsResult.data ?? []) as Record<string, unknown>[])
    .filter((item) => item.action !== 'admin.session.verified')
    .map((item) => ({ ...item, actor: 'Administrator', source: 'admin' }))
  const issueActivity = ((issuesResult.data ?? []) as Record<string, unknown>[])
    .map((item) => ({
      id: `issue:${item.id}`,
      action: `Issue reported: ${item.title ?? 'Untitled issue'}`,
      target_type: 'app_issue_report',
      target_id: item.id,
      actor: item.reporter_name ?? item.reporter_email ?? 'Application user',
      created_at: item.created_at,
      source: 'issue',
    }))
  const activityLogs = [...adminActivity, ...issueActivity, ...workspaceActivity]
    .filter((item) => item.created_at)
    .sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)))
    .slice(0, 100)

  const accounts = visibleProfiles.map((profile) => {
    const authUser = authById.get(String(profile.id))
    const membership = membershipByUser.get(String(profile.id))
    const eligible = isFounderEmail(profile.email) ||
      ['owner', 'property_agent', 'technician'].includes(String(profile.role))
    return {
      id: profile.id,
      email: profile.email,
      name: profile.full_name,
      role: profile.role,
      status: authUser?.banned_until ? 'suspended' : 'active',
      createdAt: authUser?.created_at ?? profile.created_at,
      lastLoginAt: authUser?.last_sign_in_at ?? null,
      emailConfirmedAt: authUser?.email_confirmed_at ?? null,
      membership: eligible ? membership?.membership_tier ?? 'free' : null,
      subscriptionStatus: eligible ? membership?.subscription_status ?? 'active' : null,
      subscriptionExpiresAt: eligible ? membership?.expires_at ?? null : null,
    }
  })

  for (const owner of owners) {
    const membership = membershipByUser.get(String(owner.id))
    Object.assign(owner, {
      membership: membership?.membership_tier ?? owner.config?.membership_tier ?? 'free',
      subscriptionStatus: membership?.subscription_status ?? owner.config?.subscription_status ?? 'active',
      subscriptionExpiresAt: membership?.expires_at ?? owner.config?.subscription_expires_at ?? null,
    })
  }

  const profileById = new Map(profiles.map((profile) => [String(profile.id), profile]))
  const subscriptionRequests = ((subscriptionRequestsResult.data ?? []) as Record<string, unknown>[])
    .map((item) => {
      const profile = profileById.get(String(item.user_id))
      return {
        ...item,
        userName: profile?.full_name ?? 'User',
        userEmail: profile?.email ?? '',
        userRole: profile?.role ?? '',
      }
    })

  const traffic = (trafficResult.data ?? []) as Record<string, unknown>[]
  const trafficByHour = Array.from({ length: 24 }, (_, hour) => ({ hour, views: 0 }))
  for (const event of traffic) {
    if (event.event_type !== 'page_view') continue
    const occurredAt = new Date(String(event.occurred_at))
    if (!Number.isNaN(occurredAt.valueOf())) {
      trafficByHour[(occurredAt.getUTCHours() + 8) % 24].views++
    }
  }
  const visitors = new Set(traffic.filter((event) => event.event_type === 'page_view').map((event) => event.visitor_key)).size
  const activeUsersToday = new Set(traffic.filter((event) => event.user_id).map((event) => event.user_id)).size
  const roleCounts = profiles.reduce<Record<string, number>>((counts, profile) => {
    const role = String(profile.role ?? 'unknown')
    counts[role] = (counts[role] ?? 0) + 1
    return counts
  }, {})
  const invoiceCount = owners.reduce((sum, owner) => sum + owner.invoices, 0)
  const completeCount = owners.reduce((sum, owner) => sum + owner.completeBills, 0)
  const billed = owners.reduce((sum, owner) => sum + owner.billed, 0)
  const collected = owners.reduce((sum, owner) => sum + owner.collected, 0)
  const expenses = owners.reduce((sum, owner) => sum + owner.expenses, 0)
  const currentMonth = currentMonthStart().substring(0, 7)
  const monthlyActiveUsers = authUsers.filter((user) =>
    monthKey(user.last_sign_in_at) === currentMonth
  ).length
  const resourceUsage = records(resourceUsageResult.data)[0] ?? {}
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const projectRef = (() => {
    try {
      return new URL(supabaseUrl).hostname.split('.')[0]
    } catch (_) {
      return ''
    }
  })()

  const apiRequests = (apiRequestsResult.data ?? []) as Record<string, unknown>[]
  const totalApiRequests = apiRequestsResult.count ?? apiRequests.length
  const failedApiRequests = apiFailuresResult.count ??
    apiRequests.filter((request) => numberValue(request.status_code) >= 400).length
  const durations = apiRequests
    .map((request) => numberValue(request.duration_ms))
    .sort((a, b) => a - b)
  const averageLatencyMs = durations.length
    ? Math.round(durations.reduce((sum, duration) => sum + duration, 0) / durations.length)
    : 0
  const p95LatencyMs = durations.length
    ? Math.round(durations[Math.min(durations.length - 1, Math.ceil(durations.length * .95) - 1)])
    : 0
  const endpointMetrics = new Map<string, {
    functionName: string
    requests: number
    failures: number
    totalDuration: number
    lastRequestAt: string | null
  }>()
  for (const request of apiRequests) {
    const functionName = String(request.function_name ?? 'unknown')
    const metric = endpointMetrics.get(functionName) ?? {
      functionName,
      requests: 0,
      failures: 0,
      totalDuration: 0,
      lastRequestAt: null,
    }
    metric.requests++
    metric.totalDuration += numberValue(request.duration_ms)
    if (numberValue(request.status_code) >= 400) metric.failures++
    const createdAt = String(request.created_at ?? '')
    if (!metric.lastRequestAt || createdAt > metric.lastRequestAt) metric.lastRequestAt = createdAt
    endpointMetrics.set(functionName, metric)
  }
  const apiEndpoints = Array.from(endpointMetrics.values())
    .map((metric) => ({
      functionName: metric.functionName,
      requests: metric.requests,
      failures: metric.failures,
      errorRate: metric.requests
        ? Math.round(metric.failures / metric.requests * 1000) / 10
        : 0,
      averageLatencyMs: metric.requests
        ? Math.round(metric.totalDuration / metric.requests)
        : 0,
      lastRequestAt: metric.lastRequestAt,
    }))
    .sort((a, b) => b.requests - a.requests || a.functionName.localeCompare(b.functionName))

  return {
    reportMonth,
    overview: {
      registeredUsers: accounts.length,
      roleCounts,
      visitorsToday: visitors,
      pageViewsToday: traffic.filter((event) => event.event_type === 'page_view').length,
      activeUsersToday,
      appOpensToday: traffic.filter((event) => event.event_type === 'app_open').length,
      trafficByHour,
      lastEventAt: traffic.length ? traffic.map((event) => String(event.occurred_at)).sort().at(-1) : null,
    },
    permissions: {
      level: canViewOwnerDetails ? 'founder' : 'super_admin',
      canManageAdmins: canViewOwnerDetails,
      canManageAccounts: canViewOwnerDetails,
      canViewOwnerDetails,
      canViewMonthlyReports: canViewOwnerDetails,
    },
    adminMembers,
    owners: canViewOwnerDetails ? owners : [],
    accounts,
    customizeRequests: requestsResult.data ?? [],
    issueReports: issuesResult.data ?? [],
    subscriptionPlans: subscriptionPlansResult.data ?? [],
    subscriptionRequests,
    report: canViewOwnerDetails ? {
      invoiceCount,
      completeCount,
      billed: Math.round(billed * 100) / 100,
      collected: Math.round(collected * 100) / 100,
      expenses: Math.round(expenses * 100) / 100,
      netCashFlow: Math.round((collected - expenses) * 100) / 100,
      expenseCoverage: expenses > 0 ? Math.round((collected / expenses) * 1000) / 10 : null,
      collectionRate: billed > 0 ? Math.round((collected / billed) * 1000) / 10 : null,
    } : null,
    apiMonitor: {
      windowHours: 24,
      totalRequests: totalApiRequests,
      successfulRequests: Math.max(0, totalApiRequests - failedApiRequests),
      failedRequests: failedApiRequests,
      errorRate: totalApiRequests
        ? Math.round(failedApiRequests / totalApiRequests * 1000) / 10
        : 0,
      averageLatencyMs,
      p95LatencyMs,
      slowRequests: apiRequests.filter((request) => numberValue(request.duration_ms) >= 1000).length,
      sampleSize: apiRequests.length,
      truncated: totalApiRequests > apiRequests.length,
      lastRequestAt: apiRequests.length ? apiRequests[0].created_at : null,
      endpoints: apiEndpoints,
      recentRequests: apiRequests.slice(0, 50),
    },
    supabaseUsage: {
      measuredAt: new Date().toISOString(),
      projectRef,
      scope: 'current_project',
      plan: 'free',
      databaseBytes: numberValue(resourceUsage.database_bytes),
      databaseLimitBytes: 500 * 1024 * 1024,
      storageBytes: numberValue(resourceUsage.storage_bytes),
      storageLimitBytes: 1024 * 1024 * 1024,
      storageObjects: numberValue(resourceUsage.storage_objects),
      monthlyActiveUsers,
      monthlyActiveUsersLimit: 50000,
      organizationWideMetrics: ['storage', 'monthly_active_users', 'egress', 'edge_function_invocations'],
    },
    activityLogs: canViewOwnerDetails
      ? activityLogs
      : activityLogs.filter((item) => item.source !== 'owner'),
  }
}

serveMonitored('admin-console', async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(request) })
  if (request.method !== 'POST') return json(request, { error: 'Method not allowed.' }, 405)

  try {
    const context = await requireAdmin(request)
    if (context.denied) return json(request, { error: 'This account is not authorized for administration.' }, 403)
    const { adminClient, authUser, adminUser } = context
    const body = await request.json().catch(() => ({})) as Record<string, unknown>
    const action = String(body.action ?? 'bootstrap')
    const founderAccess = isFounderAdmin(authUser.email, adminUser.admin_role)

    if (!founderAccess && [
      'update_account',
      'delete_account',
      'send_password_reset',
      'set_membership',
    ].includes(action)) {
      return json(request, { error: 'Founder access is required to manage accounts.' }, 403)
    }

    if (!founderAccess && ['update_owner_config', 'update_workspace_record'].includes(action)) {
      return json(request, { error: 'Founder access is required for owner workspace details.' }, 403)
    }

    if (action === 'bootstrap' || action === 'refresh') {
      await adminClient.from('admin_users').update({
        last_verified_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }).eq('user_id', authUser.id)
      if (action === 'bootstrap') {
        await audit(adminClient, authUser.id, 'admin.session.verified', 'admin_session', authUser.id)
      }
      const data = await buildConsoleData(
        adminClient,
        String(body.month ?? ''),
        founderAccess,
      )
      return json(request, { admin: adminUser, ...data })
    }

    if (action === 'grant_admin') {
      if (!founderAccess) {
        return json(request, { error: 'Only a founder can grant administrator access.' }, 403)
      }
      const email = stringField(body.email, 'Administrator email', 254).toLowerCase()
      const displayName = stringField(body.displayName, 'Display name', 120)
      if (!/^\S+@\S+\.\S+$/.test(email)) throw new Error('Enter a valid administrator email.')
      if (isFounderEmail(email)) throw new Error('This account already has permanent founder access.')

      const authUsers = await listAllAuthUsers(adminClient)
      let targetUser = authUsers.find((user) => String(user.email ?? '').toLowerCase() === email)
      let invited = false
      if (!targetUser) {
        const { data: invitation, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(email, {
          redirectTo: 'https://admin.homeops360.app/',
          data: { full_name: displayName, role: 'tenant' },
        })
        if (inviteError || !invitation.user) throw inviteError ?? new Error('The administrator invitation could not be created.')
        targetUser = invitation.user as unknown as Record<string, unknown>
        invited = true
      }

      const userId = String(targetUser.id)
      const { data: before, error: beforeError } = await adminClient.from('admin_users')
        .select('*').eq('user_id', userId).maybeSingle()
      if (beforeError) throw beforeError
      const now = new Date().toISOString()
      const { data: saved, error: saveError } = await adminClient.from('admin_users').upsert({
        user_id: userId,
        email,
        display_name: displayName,
        admin_role: 'super_admin',
        enabled: true,
        created_by: before?.created_by ?? authUser.id,
        updated_at: now,
      }).select('user_id,email,display_name,admin_role,enabled,created_by,created_at,updated_at,last_verified_at').single()
      if (saveError) throw saveError
      await audit(adminClient, authUser.id, 'admin.access.granted', 'admin_user', userId, before, saved)
      return json(request, { saved, invited })
    }

    if (action === 'set_admin_access') {
      if (!founderAccess) {
        return json(request, { error: 'Only a founder can change administrator access.' }, 403)
      }
      const userId = stringField(body.userId, 'Administrator id', 100)
      const enabled = booleanValue(body.enabled, 'Administrator access')
      const { data: before, error: beforeError } = await adminClient.from('admin_users')
        .select('*').eq('user_id', userId).maybeSingle()
      if (beforeError || !before) throw beforeError ?? new Error('The administrator was not found.')
      if (isFounderEmail(before.email) || before.admin_role === 'founder') {
        throw new Error('Founder administrator access is permanent.')
      }
      const { data: saved, error: saveError } = await adminClient.from('admin_users').update({
        enabled,
        admin_role: 'super_admin',
        updated_at: new Date().toISOString(),
      }).eq('user_id', userId)
        .select('user_id,email,display_name,admin_role,enabled,created_by,created_at,updated_at,last_verified_at')
        .single()
      if (saveError) throw saveError
      await audit(
        adminClient,
        authUser.id,
        enabled ? 'admin.access.restored' : 'admin.access.revoked',
        'admin_user',
        userId,
        before,
        saved,
      )
      return json(request, { saved })
    }

    if (action === 'subscription_payment_url') {
      const requestId = stringField(body.requestId, 'Subscription request id', 100)
      const { data: subscription, error } = await adminClient.from('subscription_requests')
        .select('id,payment_slip_path').eq('id', requestId).maybeSingle()
      if (error || !subscription) throw error ?? new Error('Subscription request not found.')
      const { data: signed, error: signedError } = await adminClient.storage
        .from('subscription-payment-slips').createSignedUrl(subscription.payment_slip_path, 600)
      if (signedError) throw signedError
      await audit(adminClient, authUser.id, 'subscription.receipt.viewed', 'subscription_request', requestId)
      return json(request, { url: signed.signedUrl })
    }

    if (action === 'review_subscription_request') {
      const requestId = stringField(body.requestId, 'Subscription request id', 100)
      const decision = String(body.decision ?? '')
      const notes = stringField(body.notes, 'Admin notes', 1000, false)
      if (!['approved', 'rejected'].includes(decision)) throw new Error('Invalid review decision.')
      const { data: subscription, error } = await adminClient.from('subscription_requests')
        .select('*').eq('id', requestId).maybeSingle()
      if (error || !subscription) throw error ?? new Error('Subscription request not found.')
      if (subscription.status !== 'pending_verification') {
        throw new Error('This subscription request was already reviewed.')
      }
      const { data: membership, error: membershipError } = await adminClient.from('account_memberships')
        .select('*').eq('user_id', subscription.user_id).maybeSingle()
      if (membershipError) throw membershipError
      if (membership?.membership_tier === 'diamond') {
        throw new Error('Diamond founder membership cannot be changed.')
      }
      const now = new Date().toISOString()
      const { data: reviewed, error: reviewError } = await adminClient.from('subscription_requests')
        .update({ status: decision, admin_notes: notes, reviewed_at: now, reviewed_by: authUser.id, updated_at: now })
        .eq('id', requestId).eq('status', 'pending_verification').select().single()
      if (reviewError) throw reviewError
      if (decision === 'approved') {
        const { error: saveMembershipError } = await adminClient.from('account_memberships').upsert({
          user_id: subscription.user_id,
          membership_tier: 'premium',
          subscription_status: 'active',
          billing_period: subscription.billing_period,
          started_at: now,
          expires_at: subscriptionExpiry(String(subscription.billing_period)),
          updated_by: authUser.id,
          updated_at: now,
        })
        if (saveMembershipError) throw saveMembershipError
      } else {
        const { error: restoreError } = await adminClient.from('account_memberships')
          .update({ subscription_status: 'active', updated_by: authUser.id, updated_at: now })
          .eq('user_id', subscription.user_id).eq('membership_tier', 'free')
        if (restoreError) throw restoreError
      }
      await audit(adminClient, authUser.id, `subscription.${decision}`, 'subscription_request', requestId, subscription, reviewed)
      return json(request, { saved: reviewed })
    }

    if (action === 'set_membership') {
      const userId = stringField(body.userId, 'User id', 100)
      const tier = String(body.tier ?? '')
      const billingPeriod = String(body.billingPeriod ?? 'monthly')
      if (!['free', 'premium'].includes(tier)) throw new Error('Only Free or Premium may be selected.')
      if (!['monthly', 'annual'].includes(billingPeriod)) throw new Error('Invalid billing period.')
      const { data: profile } = await adminClient.from('profiles').select('id,email,role').eq('id', userId).maybeSingle()
      const { data: before } = await adminClient.from('account_memberships').select('*').eq('user_id', userId).maybeSingle()
      if (!profile || (!isFounderEmail(profile.email) &&
          !['owner', 'property_agent', 'technician'].includes(profile.role))) {
        throw new Error('Membership is not applicable to this account.')
      }
      if (isFounderEmail(profile.email) || before?.membership_tier === 'diamond') {
        throw new Error('Diamond founder membership cannot be downgraded or removed.')
      }
      const now = new Date().toISOString()
      const next = {
        user_id: userId,
        membership_tier: tier,
        subscription_status: 'active',
        billing_period: tier === 'premium' ? billingPeriod : null,
        started_at: now,
        expires_at: tier === 'premium' ? subscriptionExpiry(billingPeriod) : null,
        updated_by: authUser.id,
        updated_at: now,
      }
      const { data: saved, error: saveError } = await adminClient.from('account_memberships')
        .upsert(next).select().single()
      if (saveError) throw saveError
      await audit(adminClient, authUser.id, 'membership.updated', 'user', userId, before, saved)
      return json(request, { saved })
    }

    if (action === 'update_owner_config') {
      const ownerId = String(body.ownerId ?? '')
      if (!ownerId) throw new Error('Owner id is required.')
      const { data: ownerProfile } = await adminClient.from('profiles').select('id,role,email').eq('id', ownerId).maybeSingle()
      if (ownerProfile?.role !== 'owner') throw new Error('The selected account is not an owner.')
      const { data: ownerMembership } = await adminClient.from('account_memberships')
        .select('membership_tier').eq('user_id', ownerId).maybeSingle()
      if (ownerMembership?.membership_tier === 'diamond' || isFounderEmail(ownerProfile.email)) {
        throw new Error('Diamond founder access is permanent and cannot be restricted.')
      }
      const { data: before } = await adminClient.from('owner_access_configs').select('*').eq('owner_id', ownerId).maybeSingle()
      const next = {
        owner_id: ownerId,
        property_limit: integerLimit(body.propertyLimit, 'Property limit', 1000),
        tenant_limit: integerLimit(body.tenantLimit, 'Tenant limit', 10000),
        explore_listing_limit: integerLimit(body.exploreListingLimit, 'Explore listing limit', 1000),
        electricity_tariff_enabled: booleanValue(body.electricityTariffEnabled, 'Electricity tariff access'),
        explore_promotion_enabled: booleanValue(body.explorePromotionEnabled, 'Explore promotion access'),
        advanced_export_enabled: booleanValue(body.advancedExportEnabled, 'Advanced export access'),
        meter_hardware_enabled: booleanValue(body.meterHardwareEnabled, 'Meter hardware access'),
        effective_from: currentMonthStart(),
        updated_by: authUser.id,
        updated_at: new Date().toISOString(),
      }
      const { data: saved, error } = await adminClient.from('owner_access_configs').upsert(next).select().single()
      if (error) throw error
      await audit(adminClient, authUser.id, 'owner.config.updated', 'owner', ownerId, before, saved)
      return json(request, { config: saved })
    }

    if (action === 'delete_account') {
      const userId = stringField(body.userId, 'User id', 100)
      if (userId === authUser.id) {
        throw new Error('You cannot delete the administrator session currently in use.')
      }
      const { data: before, error: beforeError } = await adminClient.from('profiles')
        .select('id,email,full_name,role').eq('id', userId).maybeSingle()
      if (beforeError || !before) throw beforeError ?? new Error('The selected account was not found.')
      if (!['owner', 'tenant', 'property_agent', 'technician'].includes(String(before.role))) {
        throw new Error('This account type cannot be deleted here.')
      }
      const [{ data: membership }, { data: targetAdmin }] = await Promise.all([
        adminClient.from('account_memberships')
          .select('membership_tier').eq('user_id', userId).maybeSingle(),
        adminClient.from('admin_users')
          .select('admin_role').eq('user_id', userId).maybeSingle(),
      ])
      if (membership?.membership_tier === 'diamond' ||
          targetAdmin?.admin_role === 'founder' || isFounderEmail(before.email)) {
        throw new Error('Diamond founder accounts cannot be suspended or deleted.')
      }

      await audit(adminClient, authUser.id, 'account.delete.requested', 'user', userId, before)
      const { error: banError } = await adminClient.auth.admin.updateUserById(userId, {
        ban_duration: '876000h',
      })
      if (banError) throw banError
      const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId, true)
      if (deleteError) throw deleteError
      await adminClient.from('admin_users').update({
        enabled: false,
        updated_at: new Date().toISOString(),
      }).eq('user_id', userId)

      const { data: snapshots } = await adminClient.from('workspace_snapshots')
        .select('owner_id,payload')
      for (const row of snapshots ?? []) {
        const payload = (row.payload ?? {}) as Record<string, unknown>
        let changed = false
        payload.users = records(payload.users).map((user) => {
          if (String(user.id) !== userId) return user
          changed = true
          return { ...user, accountStatus: 'Deleted' }
        })
        if (changed) {
          await adminClient.from('workspace_snapshots')
            .update({ payload, updated_at: new Date().toISOString() }).eq('owner_id', row.owner_id)
        }
      }
      await audit(adminClient, authUser.id, 'account.deleted', 'user', userId, before, {
        deleted: true,
        historicalRecordsRetained: true,
      })
      return json(request, { deleted: true })
    }

    if (action === 'update_account') {
      const userId = stringField(body.userId, 'User id', 100)
      const name = stringField(body.name, 'Name', 120)
      const email = stringField(body.email, 'Email', 254).toLowerCase()
      const status = String(body.status ?? 'active')
      if (!/^\S+@\S+\.\S+$/.test(email)) throw new Error('Enter a valid email address.')
      if (!['active', 'suspended'].includes(status)) throw new Error('Invalid account status.')
      if (userId === authUser.id && status === 'suspended') {
        throw new Error('You cannot suspend the administrator session currently in use.')
      }
      const { data: before, error: beforeError } = await adminClient.from('profiles')
        .select('id,email,full_name,role').eq('id', userId).maybeSingle()
      if (beforeError || !before) throw beforeError ?? new Error('The selected account was not found.')
      const { data: protectedMembership } = await adminClient.from('account_memberships')
        .select('membership_tier').eq('user_id', userId).maybeSingle()
      if ((protectedMembership?.membership_tier === 'diamond' || isFounderEmail(before.email)) &&
          (status !== 'active' || email !== String(before.email).toLowerCase())) {
        throw new Error('The Diamond founder account cannot be suspended or reassigned.')
      }
      const { error: authUpdateError } = await adminClient.auth.admin.updateUserById(userId, {
        email,
        user_metadata: { full_name: name },
        ban_duration: status === 'suspended' ? '876000h' : 'none',
      })
      if (authUpdateError) throw authUpdateError
      const { data: saved, error: profileError } = await adminClient.from('profiles')
        .update({ email, full_name: name, updated_at: new Date().toISOString() })
        .eq('id', userId).select('id,email,full_name,role').single()
      if (profileError) throw profileError
      const { error: adminIdentityError } = await adminClient.from('admin_users')
        .update({ email, display_name: name, updated_at: new Date().toISOString() })
        .eq('user_id', userId)
      if (adminIdentityError) throw adminIdentityError

      // Keep the workspace-side profile in sync when this user is represented
      // inside an owner's operational snapshot.
      const { data: snapshots, error: snapshotsError } = await adminClient.from('workspace_snapshots')
        .select('owner_id,payload')
      if (snapshotsError) throw snapshotsError
      for (const row of snapshots ?? []) {
        const payload = (row.payload ?? {}) as Record<string, unknown>
        let changed = false
        payload.users = records(payload.users).map((user) => {
          if (String(user.id) !== userId) return user
          changed = true
          return { ...user, name, email, accountStatus: status === 'suspended' ? 'Inactive' : 'Active' }
        })
        if (changed) {
          const { error } = await adminClient.from('workspace_snapshots')
            .update({ payload, updated_at: new Date().toISOString() }).eq('owner_id', row.owner_id)
          if (error) throw error
        }
      }
      await audit(adminClient, authUser.id, 'account.details.updated', 'user', userId, before, { ...saved, status })
      return json(request, { saved: { ...saved, status } })
    }

    if (action === 'update_workspace_record') {
      const ownerId = stringField(body.ownerId, 'Owner id', 100)
      const recordType = String(body.recordType ?? '')
      const recordId = stringField(body.recordId, 'Record id', 160)
      const fields = body.fields && typeof body.fields === 'object'
        ? body.fields as Record<string, unknown>
        : {}
      const { data: snapshot, error: snapshotError } = await adminClient.from('workspace_snapshots')
        .select('owner_id,payload').eq('owner_id', ownerId).maybeSingle()
      if (snapshotError || !snapshot) throw snapshotError ?? new Error('The owner workspace was not found.')
      const payload = (snapshot.payload ?? {}) as Record<string, unknown>
      let change: { before: Record<string, unknown>; after: Record<string, unknown> }

      if (recordType === 'property') {
        change = replaceRecord(payload, 'facilities', recordId, (record) => ({
          ...record,
          name: stringField(fields.name, 'Property name', 120),
          addressLine: stringField(fields.addressLine, 'Address', 240),
          postcode: stringField(fields.postcode, 'Postcode', 20),
          city: stringField(fields.city, 'City', 100),
          state: stringField(fields.state, 'State', 100),
          status: ['ready', 'developing', 'sold'].includes(String(fields.status))
            ? String(fields.status)
            : String(record.status ?? 'ready'),
        }))
      } else if (recordType === 'tenant') {
        const tenancies = records(payload.tenancies)
        const tenancyIndex = tenancies.findIndex((item) => String(item.id) === recordId)
        if (tenancyIndex < 0) throw new Error('The selected tenant agreement could not be found.')
        const before = { ...tenancies[tenancyIndex] }
        const tenantId = String(before.tenantId ?? '')
        const monthlyRent = moneyValue(fields.monthlyRent, 'Monthly rent')
        const after = {
          ...before,
          unitName: stringField(fields.unitName, 'Unit', 120),
          monthlyRent,
          leaseStart: stringField(fields.leaseStart, 'Lease start', 40),
          leaseEnd: stringField(fields.leaseEnd, 'Lease end', 40),
          active: fields.active === true,
        }
        const history = records(before.contractHistory)
        history.push({
          effectiveMonth: currentMonthStart(),
          recordedAt: new Date().toISOString(),
          unitName: after.unitName,
          monthlyRent,
          leaseStart: after.leaseStart,
          leaseEnd: after.leaseEnd,
          electricityPackage: before.electricityPackage,
          electricityBillingMode: before.electricityBillingMode,
          waterPackage: before.waterPackage,
          internetPackage: before.internetPackage,
          carParkIncluded: before.carParkIncluded,
          carParkDetails: before.carParkDetails,
        })
        tenancies[tenancyIndex] = { ...after, contractHistory: history }
        payload.tenancies = tenancies
        payload.users = records(payload.users).map((user) => String(user.id) === tenantId ? {
          ...user,
          name: stringField(fields.name, 'Tenant name', 120),
          email: stringField(fields.email, 'Tenant email', 254).toLowerCase(),
          phoneNumber: stringField(fields.phoneNumber, 'Phone', 40, false),
          accountStatus: fields.active === true ? 'Active' : 'Inactive',
        } : user)
        change = { before, after: tenancies[tenancyIndex] }
      } else if (recordType === 'bill') {
        change = replaceRecord(payload, 'bills', recordId, (record) => {
          if (monthKey(record.month) !== currentMonthStart().substring(0, 7)) {
            throw new Error('Past-month financial records are permanently read-only.')
          }
          const status = String(fields.status ?? record.status ?? 'pending')
          if (!['pending', 'pendingApproval', 'approved', 'rejected'].includes(status)) {
            throw new Error('Invalid payment status.')
          }
          return {
            ...record,
            rentAmount: moneyValue(fields.rentAmount, 'Rent'),
            electricityAmount: moneyValue(fields.electricityAmount, 'Electricity'),
            generalElectricAmount: moneyValue(fields.generalElectricAmount, 'General electricity'),
            waterAmount: moneyValue(fields.waterAmount, 'Water'),
            internetAmount: moneyValue(fields.internetAmount, 'Internet'),
            parkingRentalAmount: moneyValue(fields.parkingRentalAmount, 'Parking'),
            amountPaid: moneyValue(fields.amountPaid, 'Amount paid'),
            status,
            paymentReference: stringField(fields.paymentReference, 'Payment reference', 160, false),
          }
        })
      } else {
        throw new Error('Unsupported record type.')
      }

      const { error: saveError } = await adminClient.from('workspace_snapshots')
        .update({ payload, updated_at: new Date().toISOString() }).eq('owner_id', ownerId)
      if (saveError) throw saveError
      await audit(adminClient, authUser.id, `${recordType}.current_record.updated`, recordType, recordId, change.before, change.after)
      return json(request, { saved: true })
    }

    if (action === 'update_customize_request') {
      const requestId = stringField(body.requestId, 'Request id', 100)
      const status = String(body.status ?? '')
      if (!['new', 'contacted', 'closed'].includes(status)) throw new Error('Invalid request status.')
      const notes = stringField(body.notes, 'Notes', 4000, false)
      const { data: before, error: beforeError } = await adminClient.from('customize_requests')
        .select('*').eq('id', requestId).maybeSingle()
      if (beforeError || !before) throw beforeError ?? new Error('The inquiry was not found.')
      const { data: saved, error } = await adminClient.from('customize_requests').update({
        status,
        admin_notes: notes,
        updated_at: new Date().toISOString(),
      }).eq('id', requestId).select('*').single()
      if (error) throw error
      await audit(adminClient, authUser.id, 'customize_request.updated', 'customize_request', requestId, before, saved)
      return json(request, { request: saved })
    }

    if (action === 'update_issue_report') {
      const reportId = stringField(body.reportId, 'Issue report id', 100)
      const status = String(body.status ?? '')
      if (!['new', 'investigating', 'resolved', 'closed'].includes(status)) {
        throw new Error('Invalid issue status.')
      }
      const notes = stringField(body.notes, 'Admin reply', 4000, false)
      const { data: before, error: beforeError } = await adminClient.from('app_issue_reports')
        .select('*').eq('id', reportId).maybeSingle()
      if (beforeError || !before) throw beforeError ?? new Error('The issue report was not found.')
      const { data: saved, error } = await adminClient.from('app_issue_reports').update({
        status,
        admin_notes: notes,
        updated_at: new Date().toISOString(),
      }).eq('id', reportId).select('*').single()
      if (error) throw error
      await audit(adminClient, authUser.id, 'app_issue.updated', 'app_issue_report', reportId, before, saved)
      return json(request, { issue: saved })
    }

    if (action === 'send_password_reset') {
      const userId = String(body.userId ?? '')
      const { data: userResult, error: userError } = await adminClient.auth.admin.getUserById(userId)
      if (userError || !userResult.user?.email) throw new Error('The selected user could not be found.')
      const { error } = await adminClient.auth.resetPasswordForEmail(userResult.user.email, {
        redirectTo: 'https://homeops360.app/?password-recovery=1',
      })
      if (error) throw error
      await audit(adminClient, authUser.id, 'account.password_reset_sent', 'user', userId, null, {
        email: userResult.user.email,
      })
      return json(request, { sent: true })
    }

    return json(request, { error: 'Unsupported admin action.' }, 400)
  } catch (error) {
    return json(request, {
      error: error instanceof Error ? error.message : 'The admin request failed.',
    }, 400)
  }
})
