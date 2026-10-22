import { getDocumentProxy } from 'unpdf';
export const officialIndex = 'https://www.kabinet.gov.my/hari-kelepasan-am/';
const codes = ['KL','LB','PJ','JH','KD','KT','MK','NS','PH','PK','PL','PN','SB','SW','SL','TG'];
const months = ['Januari','Februari','Mac','April','Mei','Jun','Julai','Ogos','September','Oktober','November','Disember'];

export function discoverSchedule(html, year) {
  for (const match of html.matchAll(/href=["']([^"']+\.pdf)["']/gi)) {
    const url = new URL(match[1], officialIndex);
    if (url.hostname === 'www.kabinet.gov.my' && new RegExp(`hka[-_]${year}\\.pdf$`, 'i').test(url.pathname)) return url.href;
  }
  return null;
}

export async function parseSchedule(bytes, year) {
  const pdf = await getDocumentProxy(bytes);
  const holidays = new Map();
  let tables = 0;
  try {
    if (pdf.numPages > 12) throw new Error('Unexpected document size');
    for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber++) {
      const page = await pdf.getPage(pageNumber);
      const items = (await page.getTextContent()).items.filter(i => i.str?.trim())
        .map(i => ({s:i.str.trim(), x:i.transform[4], y:i.transform[5]}));
      const lines = [];
      for (const item of items) {
        let line = lines.find(l=>Math.abs(l.y-item.y)<1.5);
        if (!line) {line={y:item.y,items:[]};lines.push(line);}
        line.items.push(item);
      }
      const title = lines.find(l => new RegExp(`JADUAL HARI KELEPASAN AM (PERSEKUTUAN|NEGERI) ${year}$`).test(l.items.sort((a,b)=>a.x-b.x).map(i=>i.s).join(' ')));
      if (!title) continue;
      const header = items.find(i => i.s === 'TARIKH');
      // Only the verified BKPP matrix layout is supported. Never guess new layouts.
      if (!header || header.x < 325 || header.x > 345 || Math.abs(page.getViewport({scale:1}).width - 792) > 5) throw new Error('Unsupported holiday matrix layout');
      tables++;
      const dates = lines.map(l => ({y:l.y, match:l.items.filter(i=>i.x>310 && i.x<380).sort((a,b)=>a.x-b.x).map(i=>i.s).join(' ').match(/^(\d{1,2}) (Januari|Februari|Mac|April|Mei|Jun|Julai|Ogos|September|Oktober|November|Disember)$/)}))
        .filter(i => i.match).sort((a,b) => b.y-a.y);
      for (let n = 0; n < dates.length; n++) {
        const row = dates[n];
        const top = n ? (dates[n-1].y+row.y)/2 : row.y+9;
        const bottom = n+1 < dates.length ? (dates[n+1].y+row.y)/2 : row.y-9;
        const name = items.filter(i => i.x >= 38 && i.x < 310 && i.y < top && i.y > bottom)
          .sort((a,b) => b.y-a.y || a.x-b.x).map(i=>i.s).join(' ').replace(/\s*\*\s*/g,' ').replace(/\s+/g,' ').trim();
        if (!name || name.length > 240) throw new Error('Invalid holiday row');
        const excluded = new Set();
        for (const item of items.filter(i => i.s === '-' && Math.abs(i.y-row.y)<4 && i.x > 435)) {
          const col = Math.round((item.x-445.5)/20.95);
          if (col < 0 || col >= codes.length || Math.abs(item.x-(445.5+20.95*col))>4) throw new Error('Unsupported state columns');
          excluded.add(col);
        }
        const states = codes.filter((_,i)=>!excluded.has(i));
        if (title.items.some(i=>i.s.includes('NEGERI')) && excluded.size === 0) throw new Error('State holiday scope missing');
        if (!states.length) throw new Error('No applicable states');
        const month = months.indexOf(row.match[2])+1, day = Number(row.match[1]);
        if (new Date(Date.UTC(year,month-1,day)).getUTCMonth()+1 !== month) throw new Error('Invalid date');
        const key = `${month}-${day}-${name}`;
        const existing = holidays.get(key);
        const scope = new Set([...(existing?.states ?? []),...states]);
        holidays.set(key,{year,month,day,name,states:[...scope]});
      }
    }
    if (tables < 3 || holidays.size < 40 || holidays.size > 90) throw new Error('Incomplete annual schedule');
    return [...holidays.values()].map(h=>({...h,states:h.states.length === 16 ? '' : h.states.join(',')}));
  } finally { await pdf.destroy(); }
}

async function officialFetch(url) {
  const response = await fetch(url, {signal:AbortSignal.timeout(15000), redirect:'manual'});
  if (!response.ok) throw new Error('Official schedule unavailable');
  const bytes = await response.arrayBuffer();
  if (bytes.byteLength > 5*1024*1024) throw new Error('Document too large');
  return bytes;
}

export async function onRequestGet({request,waitUntil}) {
  const url = new URL(request.url), year = Number(url.searchParams.get('year'));
  if (!Number.isInteger(year) || year < 2026 || year > new Date().getUTCFullYear()+2) return Response.json({error:'Invalid year'}, {status:400});
  const cache = caches.default;
  const cacheKey = new Request(`${url.origin}/api/malaysia-holidays?year=${year}`);
  const cached = await cache.match(cacheKey);
  if (cached) return cached;
  try {
    const html = new TextDecoder().decode(await officialFetch(officialIndex));
    const source = discoverSchedule(html,year);
    if (!source) return Response.json({status:'unpublished',year}, {headers:{'Cache-Control':'public, max-age=3600'}});
    const holidays = await parseSchedule(new Uint8Array(await officialFetch(source)),year);
    const result = Response.json({status:'verified',year,source,holidays,checkedAt:new Date().toISOString()},
      {headers:{'Cache-Control':'public, max-age=86400','Access-Control-Allow-Origin':'*'}});
    waitUntil(cache.put(cacheKey,result.clone()));
    return result;
  } catch (error) {
    console.warn('Official holiday feed unavailable:', error instanceof Error ? error.message : 'Unknown failure');
    return Response.json({status:'unavailable',year},{status:503});
  }
}
