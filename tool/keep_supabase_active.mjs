const url = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
const key = process.env.SUPABASE_PUBLISHABLE_KEY || '';
const projectName = process.env.SUPABASE_PROJECT_NAME || 'Supabase project';

if (!url || !key) {
  throw new Error(
    `${projectName} keep-alive is not configured. ` +
      'Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
  );
}

// This performs a real, read-only PostgREST database query. RLS remains in
// force, so an unauthenticated request returns no invoice rows or user data.
// Use this table because its policy does not invoke authenticated-only helper
// functions when PostgREST evaluates an anonymous request.
const endpoint = `${url}/rest/v1/rentflow_test_invoices?select=id&limit=1`;
const response = await fetch(endpoint, {
  headers: {
    apikey: key,
  },
  signal: AbortSignal.timeout(15_000),
});

if (!response.ok) {
  throw new Error(
    `${projectName} keep-alive failed with HTTP ${response.status}.`,
  );
}

const rows = await response.json();
if (!Array.isArray(rows)) {
  throw new Error(`${projectName} keep-alive returned an unexpected response.`);
}

console.log(
  `${projectName} database activity recorded at ${new Date().toISOString()}.`,
);
