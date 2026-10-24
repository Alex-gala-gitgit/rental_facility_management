const baseUrl = (process.env.HOMEOPS_BASE_URL || 'https://facility-billing-management.pages.dev').replace(/\/$/, '');
const supabaseUrl = (process.env.HOMEOPS_SUPABASE_URL || 'https://yvyvbjtgfmpvvbnmzinq.supabase.co').replace(/\/$/, '');
const apiKey = process.env.HOMEOPS_SUPABASE_KEY || '';
const accessToken = process.env.HOMEOPS_UAT_ACCESS_TOKEN || '';

async function check(name, url, options = {}, validate = () => true) {
  const response = await fetch(url, { signal: AbortSignal.timeout(15000), ...options });
  const body = await response.text();
  if (!response.ok || !validate(body, response)) {
    throw new Error(`${name} failed with HTTP ${response.status}`);
  }
  console.log(`PASS ${name} (${response.status})`);
}

await check('web application', baseUrl);
await check('release metadata', `${baseUrl}/updates/version.json`, {}, (body) => {
  const value = JSON.parse(body);
  return typeof value.versionName === 'string' && Number.isInteger(value.versionCode);
});

if (apiKey) {
  await check('Supabase Auth health', `${supabaseUrl}/auth/v1/health`, {
    headers: { apikey: apiKey },
  });
  if (accessToken) {
    await check('authenticated UAT session', `${supabaseUrl}/auth/v1/user`, {
      headers: { apikey: apiKey, Authorization: `Bearer ${accessToken}` },
    });
  } else {
    console.log('SKIP authenticated session: HOMEOPS_UAT_ACCESS_TOKEN is not configured.');
  }
} else {
  console.log('SKIP Supabase checks: HOMEOPS_SUPABASE_KEY is not configured.');
}
