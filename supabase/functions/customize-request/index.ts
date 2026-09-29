import { createClient } from 'npm:@supabase/supabase-js@2.57.4'
import { serveMonitored } from '../_shared/api_monitor.ts'

const allowedOrigins = new Set([
  'https://homeops360.app',
  'https://www.homeops360.app',
  'https://facility-billing-management.pages.dev',
])

function originAllowed(origin: string) {
  return allowedOrigins.has(origin) || origin.startsWith('http://localhost:') ||
    origin.startsWith('http://127.0.0.1:')
}

function headers(request: Request) {
  const origin = request.headers.get('Origin') ?? ''
  return {
    'Access-Control-Allow-Origin': originAllowed(origin) ? origin : 'https://homeops360.app',
    'Access-Control-Allow-Headers': 'content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  }
}

function text(value: unknown, field: string, max: number, required = true) {
  const result = String(value ?? '').trim()
  if (required && !result) throw new Error(`${field} is required.`)
  if (result.length > max) throw new Error(`${field} is too long.`)
  return result
}

serveMonitored('customize-request', async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: headers(request) })
  if (request.method !== 'POST') return Response.json({ error: 'Method not allowed.' }, { status: 405, headers: headers(request) })
  const origin = request.headers.get('Origin') ?? ''
  if (!originAllowed(origin)) return Response.json({ error: 'Origin is not allowed.' }, { status: 403, headers: headers(request) })

  try {
    const body = await request.json() as Record<string, unknown>
    // Invisible honeypot: automated submissions commonly populate it.
    if (String(body.website ?? '').trim()) return Response.json({ accepted: true }, { headers: headers(request) })
    const row = {
      name: text(body.name, 'Name', 120),
      company: text(body.company, 'Company', 160, false),
      phone: text(body.phone, 'WhatsApp number', 40),
      property_count: text(body.propertyCount, 'Property count', 40),
      interest: text(body.interest, 'Interest', 160),
      message: text(body.message, 'Requirement', 4000),
      language: body.language === 'zh' ? 'zh' : 'en',
      source_path: text(body.sourcePath || '/customize/', 'Source path', 300),
    }
    if (!/^[+0-9() .-]{6,40}$/.test(row.phone)) throw new Error('Enter a valid WhatsApp number.')
    const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const duplicateSince = new Date(Date.now() - 5 * 60 * 1000).toISOString()
    const { data: duplicate, error: duplicateError } = await client.from('customize_requests')
      .select('id,created_at').eq('phone', row.phone).eq('message', row.message)
      .gte('created_at', duplicateSince).maybeSingle()
    if (duplicateError) throw duplicateError
    if (duplicate) {
      return Response.json({ accepted: true, requestId: duplicate.id, createdAt: duplicate.created_at }, { status: 200, headers: headers(request) })
    }
    const { data, error } = await client.from('customize_requests').insert(row).select('id,created_at').single()
    if (error) throw error
    return Response.json({ accepted: true, requestId: data.id, createdAt: data.created_at }, { status: 201, headers: headers(request) })
  } catch (error) {
    return Response.json({ error: error instanceof Error ? error.message : 'The inquiry could not be saved.' }, { status: 400, headers: headers(request) })
  }
})
