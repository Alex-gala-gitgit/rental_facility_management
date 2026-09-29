import { createClient } from 'npm:@supabase/supabase-js@2.57.4'

type Handler = (request: Request) => Response | Promise<Response>

type EdgeRuntimeApi = {
  waitUntil(promise: Promise<unknown>): void
}

function errorCode(status: number): string | null {
  if (status < 400) return null
  if (status === 401) return 'unauthorized'
  if (status === 403) return 'forbidden'
  if (status === 404) return 'not_found'
  if (status === 409) return 'conflict'
  if (status === 429) return 'rate_limited'
  if (status >= 500) return 'server_error'
  return 'client_error'
}

async function saveMetric(metric: Record<string, unknown>) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const secretKey = Deno.env.get('SUPABASE_SECRET_KEY') ??
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !secretKey) {
    console.warn('API telemetry skipped because server credentials are unavailable.')
    return
  }
  const admin = createClient(supabaseUrl, secretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { error } = await admin.from('api_request_logs').insert(metric)
  if (error) console.error('API telemetry insert failed:', error.message)
}

function runInBackground(task: Promise<unknown>) {
  const guarded = task.catch((error) => {
    console.error('API telemetry background task failed:', error)
  })
  const runtime = (globalThis as typeof globalThis & {
    EdgeRuntime?: EdgeRuntimeApi
  }).EdgeRuntime
  if (runtime) {
    runtime.waitUntil(guarded)
  } else {
    void guarded
  }
}

export function serveMonitored(functionName: string, handler: Handler) {
  Deno.serve(async (request) => {
    if (request.method === 'OPTIONS') return handler(request)

    const started = performance.now()
    let response: Response
    try {
      response = await handler(request)
    } catch (error) {
      const durationMs = Math.max(0, Math.round(performance.now() - started))
      runInBackground(saveMetric({
        function_name: functionName,
        method: request.method,
        status_code: 500,
        duration_ms: durationMs,
        error_code: 'unhandled_exception',
      }))
      throw error
    }

    const durationMs = Math.max(0, Math.round(performance.now() - started))
    runInBackground(saveMetric({
      function_name: functionName,
      method: request.method,
      status_code: response.status,
      duration_ms: durationMs,
      error_code: errorCode(response.status),
    }))
    return response
  })
}
