const url = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
const key = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const webhook = process.env.ALERT_WEBHOOK_URL || '';
const windowMinutes = Number(process.env.MONITOR_WINDOW_MINUTES || 20);
const maxFailureRate = Number(process.env.MONITOR_FAILURE_RATE_PERCENT || 5);
const maxLatency = Number(process.env.MONITOR_MAX_LATENCY_MS || 5000);

if (!url || !key) {
  console.log('Monitor is not configured; add production Supabase secrets to enable it.');
  process.exit(0);
}

const since = new Date(Date.now() - windowMinutes * 60_000).toISOString();
const endpoint = `${url}/rest/v1/api_request_logs?select=function_name,status_code,duration_ms,created_at&created_at=gte.${encodeURIComponent(since)}&order=created_at.desc&limit=5000`;
const response = await fetch(endpoint, {
  headers: { apikey: key, Authorization: `Bearer ${key}` },
  signal: AbortSignal.timeout(15000),
});
if (!response.ok) throw new Error(`Health query failed with HTTP ${response.status}`);
const rows = await response.json();
const failures = rows.filter((row) => Number(row.status_code) >= 500);
const slow = rows.filter((row) => Number(row.duration_ms) >= maxLatency);
const failureRate = rows.length === 0 ? 0 : failures.length * 100 / rows.length;
const lifecycleSeen = rows.some((row) => row.function_name === 'tenant-lifecycle');
const unhealthy = failures.length > 0 && failureRate >= maxFailureRate || slow.length > 0;
const summary = {
  checkedAt: new Date().toISOString(), windowMinutes, requests: rows.length,
  failures: failures.length, failureRatePercent: Number(failureRate.toFixed(2)),
  slowRequests: slow.length, tenantLifecycleObserved: lifecycleSeen,
};
console.log(JSON.stringify(summary));

if (unhealthy && webhook) {
  const alert = await fetch(webhook, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ text: `HomeOps360 production alert: ${JSON.stringify(summary)}`, summary }),
    signal: AbortSignal.timeout(15000),
  });
  if (!alert.ok) throw new Error(`Alert webhook failed with HTTP ${alert.status}`);
}
if (unhealthy) process.exitCode = 1;
