import assert from 'node:assert/strict';
import { discoverSchedule, parseSchedule } from '../functions/api/malaysia-holidays.js';
assert.equal(discoverSchedule('<a href="https://evil.test/HKA_2027.pdf">',2027),null);
assert.equal(discoverSchedule('<a href="../storage/2026/08/HKA_2027.pdf">',2027),'https://www.kabinet.gov.my/storage/2026/08/HKA_2027.pdf');
for (const [year,url] of [[2026,'https://www.kabinet.gov.my/storage/2025/08/HKA-2026.pdf'],[2027,'https://www.kabinet.gov.my/storage/2026/08/HKA_2027.pdf']]) {
  const bytes = new Uint8Array(await (await fetch(url)).arrayBuffer());
  const rows = await parseSchedule(bytes,year);
  assert(rows.length >= 40);
  const deepavali = rows.find(h=>h.name.includes('Deepavali'));
  assert(!deepavali.states.split(',').includes('SW'));
  assert(rows.some(h=>h.name.includes('Hari Malaysia') && h.month===9 && h.day===16 && h.states===''));
  assert(rows.some(h=>h.name.includes('Sarawak') && h.states==='SW'));
  console.log(`${year}: ${rows.length} official rows verified`);
}
