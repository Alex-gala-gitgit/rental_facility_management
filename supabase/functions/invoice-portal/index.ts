import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { serveMonitored } from '../_shared/api_monitor.ts'

const bucket = 'rentflow-test-files'
const maximumProofBytes = 2 * 1024 * 1024
const portalLifetimeDays = 3

function corsHeaders(request: Request) {
  const origin = request.headers.get('Origin') ?? ''
  const allowed = origin === 'https://homeops360.app' ||
    origin === 'https://www.homeops360.app' ||
    origin === 'https://facility-billing-management.pages.dev' ||
    origin.startsWith('http://127.0.0.1:') ||
    origin.startsWith('http://localhost:')
  return {
    'Access-Control-Allow-Origin': allowed ? origin : 'https://homeops360.app',
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

function text(value: unknown, field: string, maximum = 500) {
  const result = String(value ?? '').trim()
  if (!result || result.length > maximum) throw new Error(`${field} is invalid.`)
  return result
}

function optionalText(value: unknown, maximum = 1000) {
  const result = String(value ?? '').trim()
  return result ? result.slice(0, maximum) : null
}

function amount(value: unknown, field: string) {
  const result = Number(value ?? 0)
  if (!Number.isFinite(result) || result < 0 || result > 10_000_000) {
    throw new Error(`${field} is invalid.`)
  }
  return Math.round(result * 100) / 100
}

function electricityRate(value: unknown) {
  const result = Number(value ?? 0)
  if (!Number.isFinite(result) || result < 0 || result > 1000) {
    throw new Error('Electricity rate is invalid.')
  }
  return Math.round(result * 1_000_000) / 1_000_000
}

function randomToken() {
  // 144 bits remains far beyond brute-force feasibility while keeping the
  // tenant's WhatsApp URL compact enough to read and forward reliably.
  const bytes = crypto.getRandomValues(new Uint8Array(18))
  return btoa(String.fromCharCode(...bytes))
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '')
}

async function hashToken(token: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token))
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('')
}

function decodeBase64(value: string) {
  const normalized = value.includes(',') ? value.substring(value.indexOf(',') + 1) : value
  const binary = atob(normalized)
  const bytes = new Uint8Array(binary.length)
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index)
  return bytes
}

function safeFileName(value: string) {
  const cleaned = value.replace(/[^A-Za-z0-9._-]/g, '_').slice(-160)
  return cleaned || 'payment-proof.jpg'
}

function allowedMimeType(value: unknown) {
  const mime = String(value ?? '').toLowerCase()
  if (!['image/jpeg', 'image/png', 'application/pdf'].includes(mime)) {
    throw new Error('Payment proof must be a JPG, PNG or PDF file.')
  }
  return mime
}

function invoiceValues(input: Record<string, unknown>) {
  const status = String(input.status ?? 'sent')
  if (!['draft', 'sent', 'slipSubmitted', 'paid'].includes(status)) {
    throw new Error('Invoice status is invalid.')
  }
  const dueDate = new Date(text(input.due_date, 'Due date', 80))
  if (Number.isNaN(dueDate.getTime())) throw new Error('Due date is invalid.')
  return {
    id: text(input.id, 'Invoice id', 120),
    tenant_id: text(input.tenant_id, 'Tenant id', 120),
    tenant_name: text(input.tenant_name, 'Tenant name', 200),
    tenant_email: text(input.tenant_email, 'Tenant email', 320).toLowerCase(),
    tenant_phone: text(input.tenant_phone, 'Tenant phone', 40),
    property_name: text(input.property_name, 'Property name', 240),
    unit_name: text(input.unit_name, 'Unit name', 120),
    rent: amount(input.rent, 'Rent'),
    water: amount(input.water, 'Water'),
    internet: amount(input.internet, 'Internet'),
    general_electric: amount(input.general_electric, 'General electricity'),
    parking_rental: amount(input.parking_rental, 'Parking rental'),
    period: text(input.period, 'Invoice period', 80),
    usage_period: text(input.usage_period, 'Usage period', 80),
    previous_reading: amount(input.previous_reading, 'Previous reading'),
    current_reading: amount(input.current_reading, 'Current reading'),
    electricity_tariff_name: text(input.electricity_tariff_name ?? 'Owner tariff', 'Tariff name', 160),
    electricity_rate_per_kwh: electricityRate(input.electricity_rate_per_kwh),
    electricity_amount: amount(input.electricity_amount, 'Electricity amount'),
    electricity_tariff_summary: optionalText(input.electricity_tariff_summary, 1000),
    evidence_name: text(input.evidence_name ?? 'Meter evidence', 'Evidence name', 240),
    evidence_path: optionalText(input.evidence_path, 1000),
    pdf_path: optionalText(input.pdf_path, 1000),
    due_date: dueDate.toISOString(),
    status,
    bank_name: optionalText(input.bank_name, 160) ?? '',
    bank_account_number: optionalText(input.bank_account_number, 80) ?? '',
    bank_beneficiary: optionalText(input.bank_beneficiary, 200) ?? '',
    payment_qr_name: optionalText(input.payment_qr_name, 240),
    payment_qr_base64: optionalText(input.payment_qr_base64, 3_000_000),
    updated_at: new Date().toISOString(),
  }
}

async function authenticatedOwner(request: Request, supabaseUrl: string, publishableKey: string) {
  const authorization = request.headers.get('Authorization')
  if (!authorization) throw new Error('Owner authentication is required.')
  const caller = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
  })
  const { data: authData, error: authError } = await caller.auth.getUser()
  if (authError || !authData.user) throw new Error('The owner session is invalid or expired.')
  const { data: profile, error: profileError } = await caller
    .from('profiles')
    .select('role')
    .eq('id', authData.user.id)
    .single()
  if (profileError || profile?.role !== 'owner') throw new Error('Only an owner can publish invoices.')
  return authData.user
}

async function authenticatedTenant(request: Request, supabaseUrl: string, publishableKey: string) {
  const authorization = request.headers.get('Authorization')
  if (!authorization) throw new Error('Tenant authentication is required.')
  const caller = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
  })
  const { data: authData, error: authError } = await caller.auth.getUser()
  if (authError || !authData.user?.email) {
    throw new Error('The tenant session is invalid or expired.')
  }
  const { data: profile, error: profileError } = await caller
    .from('profiles')
    .select('role')
    .eq('id', authData.user.id)
    .single()
  if (profileError || profile?.role !== 'tenant') {
    throw new Error('Only the assigned tenant can retrieve this invoice.')
  }
  return {
    id: authData.user.id,
    email: authData.user.email.trim().toLowerCase(),
  }
}

async function safeInvoicePayload(admin: any, invoice: Record<string, any>) {
  let pdfUrl: string | null = null
  if (invoice.pdf_path) {
    const { data: signed, error: signedError } = await admin.storage
      .from(bucket)
      .createSignedUrl(invoice.pdf_path, 60 * 60)
    if (signedError) throw signedError
    pdfUrl = signed.signedUrl
  }
  const {
    owner_id: _ownerId,
    portal_token_hash: _tokenHash,
    portal_expires_at: _portalExpiry,
    slip_path: _slipPath,
    ...safeInvoice
  } = invoice
  return { ...safeInvoice, pdf_url: pdfUrl }
}

async function invoiceForToken(
  admin: any,
  invoiceId: string | null,
  token: string,
): Promise<Record<string, any>> {
  if (token.length < 20) throw new Error('This invoice link is invalid or expired.')
  const tokenHash = await hashToken(token)
  let query = admin
    .from('rentflow_test_invoices')
    .select('*')
    .eq('portal_token_hash', tokenHash)
    .gt('portal_expires_at', new Date().toISOString())
  if (invoiceId) query = query.eq('id', invoiceId)
  const { data, error } = await query
    .maybeSingle()
  if (error) throw error
  if (!data) throw new Error('This invoice link is invalid or expired.')
  return data as Record<string, any>
}

serveMonitored('invoice-portal', async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(request) })
  if (request.method !== 'POST') return json(request, { error: 'Method not allowed.' }, 405)

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const publishableKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const body = await request.json() as Record<string, unknown>
    const action = String(body.action ?? '')

    if (action === 'publish') {
      const owner = await authenticatedOwner(request, supabaseUrl, publishableKey)
      const input = invoiceValues((body.invoice ?? {}) as Record<string, unknown>)
      if (input.pdf_path && !input.pdf_path.startsWith(`${owner.id}/invoices/`)) {
        throw new Error('The invoice PDF path does not belong to this owner.')
      }
      if (input.evidence_path && !input.evidence_path.startsWith(`${owner.id}/`)) {
        throw new Error('The meter evidence path does not belong to this owner.')
      }
      const { data: existing, error: existingError } = await admin
        .from('rentflow_test_invoices')
        .select('owner_id,status,slip_name,slip_path,amount_paid,payment_date,payment_reference,slip_submitted_at')
        .eq('id', input.id)
        .maybeSingle()
      if (existingError) throw existingError
      if (existing?.owner_id && existing.owner_id !== owner.id) {
        return json(request, { error: 'This invoice id already belongs to another owner.' }, 409)
      }

      const token = randomToken()
      const tokenHash = await hashToken(token)
      const expiresAt = new Date(Date.now() + portalLifetimeDays * 24 * 60 * 60 * 1000)
      // Republishing refreshes invoice content and its access token, but must
      // never erase payment proof that a tenant has already submitted.
      const hasSubmittedPayment = existing?.status === 'slipSubmitted' ||
        existing?.status === 'paid'
      const protectedPayment = hasSubmittedPayment
        ? {
          status: existing.status,
          slip_name: existing.slip_name,
          slip_path: existing.slip_path,
          amount_paid: existing.amount_paid,
          payment_date: existing.payment_date,
          payment_reference: existing.payment_reference,
          slip_submitted_at: existing.slip_submitted_at,
        }
        : {}
      const { error } = await admin.from('rentflow_test_invoices').upsert({
        ...input,
        ...protectedPayment,
        owner_id: owner.id,
        portal_token_hash: tokenHash,
        portal_expires_at: expiresAt.toISOString(),
      }, { onConflict: 'id' })
      if (error) throw error

      let pdfUrl: string | null = null
      if (input.pdf_path) {
        const { data: signed, error: signedError } = await admin.storage
          .from(bucket)
          .createSignedUrl(input.pdf_path, portalLifetimeDays * 24 * 60 * 60)
        if (signedError) throw signedError
        pdfUrl = signed.signedUrl
      }
      return json(request, {
        invoiceId: input.id,
        portalToken: token,
        portalExpiresAt: expiresAt.toISOString(),
        pdfUrl,
      })
    }

    if (action === 'review-payment') {
      const owner = await authenticatedOwner(request, supabaseUrl, publishableKey)
      const invoiceId = text(body.invoiceId, 'Invoice id', 120)
      const decision = text(body.decision, 'Review decision', 20)
      if (decision !== 'approved' && decision !== 'rejected') {
        throw new Error('Review decision must be approved or rejected.')
      }
      const rejectionReason = decision === 'rejected'
        ? text(body.rejectionReason, 'Rejection reason', 300)
        : null
      const reviewedAt = new Date().toISOString()
      const { data: attempt, error: attemptLookupError } = await admin
        .from('rentflow_payment_attempts')
        .select('id')
        .eq('invoice_id', invoiceId)
        .eq('owner_id', owner.id)
        .eq('status', 'submitted')
        .order('submitted_at', { ascending: false })
        .limit(1)
        .maybeSingle()
      if (attemptLookupError) throw attemptLookupError
      if (!attempt) throw new Error('No submitted payment attempt is available for review.')
      const { error: attemptUpdateError } = await admin
        .from('rentflow_payment_attempts')
        .update({
          status: decision,
          reviewed_at: reviewedAt,
          rejection_reason: rejectionReason,
          updated_at: reviewedAt,
        })
        .eq('id', attempt.id)
        .eq('owner_id', owner.id)
      if (attemptUpdateError) throw attemptUpdateError
      const invoiceValues = decision === 'approved'
        ? { status: 'paid', updated_at: reviewedAt }
        : {
          status: 'sent',
          slip_name: null,
          slip_path: null,
          amount_paid: null,
          payment_date: null,
          payment_reference: null,
          slip_submitted_at: null,
          updated_at: reviewedAt,
        }
      const { error: invoiceUpdateError } = await admin
        .from('rentflow_test_invoices')
        .update(invoiceValues)
        .eq('id', invoiceId)
        .eq('owner_id', owner.id)
      if (invoiceUpdateError) throw invoiceUpdateError
      return json(request, { reviewed: true, decision, reviewedAt })
    }

    if (action === 'get-authenticated-tenant') {
      const tenant = await authenticatedTenant(request, supabaseUrl, publishableKey)
      const invoiceId = text(body.invoiceId, 'Invoice id', 120)
      const { data: invoice, error } = await admin
        .from('rentflow_test_invoices')
        .select('*')
        .eq('id', invoiceId)
        .maybeSingle()
      if (error) throw error
      const assignedEmail = typeof invoice?.tenant_email === 'string'
        ? invoice.tenant_email.trim().toLowerCase()
        : ''
      if (!invoice || assignedEmail !== tenant.email) {
        throw new Error('This invoice is not assigned to the signed-in tenant.')
      }
      return json(request, { invoice: await safeInvoicePayload(admin, invoice) })
    }

    const invoiceId = optionalText(body.invoiceId, 120)
    const token = text(body.token, 'Portal token', 200)
    const invoice = await invoiceForToken(admin, invoiceId, token)

    if (action === 'get') {
      return json(request, { invoice: await safeInvoicePayload(admin, invoice) })
    }

    if (action === 'submit-payment') {
      if (invoice.status === 'paid') throw new Error('This invoice is already paid.')
      if (invoice.status === 'slipSubmitted') {
        throw new Error('A payment proof has already been submitted for review.')
      }
      const fileName = safeFileName(text(body.fileName, 'Payment proof file name', 240))
      const mimeType = allowedMimeType(body.mimeType)
      const bytes = decodeBase64(text(body.base64, 'Payment proof', 4_000_000))
      if (bytes.length === 0 || bytes.length > maximumProofBytes) {
        throw new Error('Payment proof must be smaller than 2 MB.')
      }
      // The payable amount and submission date are authoritative invoice/server
      // values. A modified browser request cannot override either field.
      const amountPaid = amount(
        Number(invoice.rent ?? 0) + Number(invoice.water ?? 0) +
        Number(invoice.internet ?? 0) + Number(invoice.general_electric ?? 0) +
        Number(invoice.parking_rental ?? 0) + Number(invoice.electricity_amount ?? 0),
        'Amount paid',
      )
      if (amountPaid <= 0) throw new Error('Amount paid must be greater than zero.')
      const paymentDate = new Date()
      const path = `${invoice.owner_id}/slips/${invoice.id}/${crypto.randomUUID()}-${fileName}`
      const { error: uploadError } = await admin.storage.from(bucket).upload(path, bytes, {
        contentType: mimeType,
        upsert: false,
      })
      if (uploadError) throw uploadError
      const submittedAt = new Date().toISOString()
      const { data: attempt, error: attemptError } = await admin
        .from('rentflow_payment_attempts')
        .insert({
          invoice_id: invoice.id,
          owner_id: invoice.owner_id,
          slip_name: fileName,
          slip_path: path,
          amount_paid: amountPaid,
          payment_date: paymentDate.toISOString(),
          payment_reference: optionalText(body.paymentReference, 160),
          submitted_at: submittedAt,
          status: 'submitted',
          updated_at: submittedAt,
        })
        .select('id')
        .single()
      if (attemptError) {
        await admin.storage.from(bucket).remove([path])
        throw attemptError
      }
      const { error: updateError } = await admin.from('rentflow_test_invoices').update({
        slip_name: fileName,
        slip_path: path,
        amount_paid: amountPaid,
        payment_date: paymentDate.toISOString(),
        payment_reference: optionalText(body.paymentReference, 160),
        slip_submitted_at: submittedAt,
        status: 'slipSubmitted',
        updated_at: submittedAt,
      }).eq('id', invoice.id).eq('owner_id', invoice.owner_id)
      if (updateError) {
        await admin.from('rentflow_payment_attempts').delete().eq('id', attempt.id)
        await admin.storage.from(bucket).remove([path])
        throw updateError
      }
      return json(request, {
        submitted: true,
        status: 'slipSubmitted',
        submittedAt,
        attemptId: attempt.id,
      })
    }

    return json(request, { error: 'Unknown invoice portal action.' }, 400)
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : error && typeof error === 'object' && 'message' in error
      ? String(error.message)
      : 'Invoice portal request failed.'
    const status = message.includes('invalid or expired') ? 404 : 400
    return json(request, { error: message }, status)
  }
})
