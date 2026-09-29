import { createClient } from 'npm:@supabase/supabase-js@2.57.4'
import { serveMonitored } from '../_shared/api_monitor.ts'

function corsHeaders(request: Request) {
  const origin = request.headers.get('Origin') ?? ''
  const allowed = origin === 'https://homeops360.app' ||
    origin === 'https://www.homeops360.app' ||
    origin === 'https://admin.homeops360.app' ||
    origin === 'https://facility-billing-management.pages.dev' ||
    origin.startsWith('http://localhost:') ||
    origin.startsWith('http://127.0.0.1:')
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

serveMonitored('platform-event', async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(request) })
  if (request.method !== 'POST') return json(request, { error: 'Method not allowed.' }, 405)
  try {
    const body = await request.json() as Record<string, unknown>
    const eventType = String(body.eventType ?? '')
    const visitorKey = String(body.visitorKey ?? '').trim()
    const path = String(body.path ?? '/').trim().slice(0, 500)
    if (!['page_view', 'app_open', 'admin_open'].includes(eventType)) {
      throw new Error('Event type is invalid.')
    }
    if (!/^[A-Za-z0-9_-]{16,120}$/.test(visitorKey)) {
      throw new Error('Visitor key is invalid.')
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const publishableKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const secretKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    let userId: string | null = null
    let userRole: string | null = null
    const authorization = request.headers.get('Authorization')
    if (authorization) {
      const caller = createClient(supabaseUrl, publishableKey, {
        global: { headers: { Authorization: authorization } },
        auth: { persistSession: false, autoRefreshToken: false },
      })
      const { data } = await caller.auth.getUser()
      userId = data.user?.id ?? null
    }
    const adminClient = createClient(supabaseUrl, secretKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    if (userId) {
      const { data: profile } = await adminClient.from('profiles').select('role').eq('id', userId).maybeSingle()
      userRole = profile?.role ?? null
    }
    const minuteAgo = new Date(Date.now() - 60_000).toISOString()
    const { data: duplicate } = await adminClient.from('platform_events').select('id')
      .eq('event_type', eventType).eq('visitor_key', visitorKey).eq('path', path)
      .gte('occurred_at', minuteAgo).limit(1).maybeSingle()
    if (!duplicate) {
      const { error } = await adminClient.from('platform_events').insert({
        event_type: eventType,
        visitor_key: visitorKey,
        path,
        user_id: userId,
        user_role: userRole,
      })
      if (error) throw error
    }
    return json(request, { accepted: true })
  } catch (error) {
    return json(request, {
      error: error instanceof Error ? error.message : 'Event rejected.',
    }, 400)
  }
})
