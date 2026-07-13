import 'jsr:@supabase/functions-js/edge-runtime.d.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const { base64, mimeType, fileName } = await request.json()
    if (!base64 || !mimeType) throw new Error('The attachment is missing.')
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
    const payload = await result.json()
    if (!result.ok) throw new Error(payload?.error?.message ?? 'AI reading failed.')
    const outputText = payload.output_text ?? payload.output
      ?.flatMap((item) => item.content ?? [])
      ?.find((item) => item.type === 'output_text')?.text
    if (!outputText) throw new Error('AI returned no readable meter result.')
    const reading = JSON.parse(outputText)
    if (reading.usageKwh == null || reading.confidence < 0.65) {
      throw new Error('The reading is unclear. Please upload a sharper photo.')
    }
    return new Response(JSON.stringify(reading), {
      headers: { ...cors, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }
})
