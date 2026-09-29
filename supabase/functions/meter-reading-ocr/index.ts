import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { serveMonitored } from '../_shared/api_monitor.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serveMonitored('meter-reading-ocr', async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const authorization = request.headers.get('Authorization')
    if (!authorization) throw new Error('Owner authentication is required.')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const publishableKey = Deno.env.get('SUPABASE_ANON_KEY')!
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
    if (profileError || profile?.role !== 'owner') {
      throw new Error('Only an owner can process meter readings.')
    }

    const { base64, mimeType, fileName } = await request.json()
    if (!base64 || !mimeType) throw new Error('The attachment is missing.')
    if (String(base64).length > 3_000_000) {
      throw new Error('The meter photo must be compressed below 2 MB.')
    }
    if (mimeType === 'application/pdf') {
      throw new Error('Please upload a JPG or PNG meter photo for automatic reading.')
    }
    const apiKey = Deno.env.get('OPENAI_API_KEY')
    if (!apiKey) throw new Error('Meter-reading AI is not configured yet.')

    const result = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4.1-mini',
        input: [{
          role: 'user',
          content: [
            {
              type: 'input_text',
              text: `Read the electricity meter or electricity bill in ${fileName ?? 'this image'}. Return previousReading and currentReading when present. Return usageKwh directly when printed; otherwise calculate currentReading - previousReading. Never guess unreadable digits.`,
            },
            { type: 'input_image', image_url: `data:${mimeType};base64,${base64}` },
          ],
        }],
        text: {
          format: {
            type: 'json_schema',
            name: 'meter_reading',
            strict: true,
            schema: {
              type: 'object',
              properties: {
                previousReading: { type: ['number', 'null'] },
                currentReading: { type: ['number', 'null'] },
                usageKwh: { type: ['number', 'null'] },
                confidence: { type: 'number', minimum: 0, maximum: 1 },
              },
              required: ['previousReading', 'currentReading', 'usageKwh', 'confidence'],
              additionalProperties: false,
            },
          },
        },
      }),
    })
    const payload = await result.json() as Record<string, any>
    if (!result.ok) throw new Error(payload?.error?.message ?? 'AI reading failed.')
    const outputText = payload.output_text ?? payload.output
      ?.flatMap((item: any) => item.content ?? [])
      ?.find((item: any) => item.type === 'output_text')?.text
    if (!outputText) throw new Error('AI returned no readable meter result.')
    const reading = JSON.parse(outputText)
    if (reading.usageKwh == null || reading.confidence < 0.65) {
      throw new Error('The reading is unclear. Please upload a sharper photo.')
    }
    return new Response(JSON.stringify(reading), {
      headers: { ...cors, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Meter reading failed.'
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }
})
