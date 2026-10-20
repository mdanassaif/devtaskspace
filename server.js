// Anas HQ local server: serves the app, stores everything in one SQLite file,
// keeps a full change history, and writes a daily JSON backup.
'use strict';
process.removeAllListeners('warning'); // hide node:sqlite "experimental" notice

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { DatabaseSync } = require('node:sqlite');

const PORT = +process.env.ANASHQ_PORT || 4777;
const ROOT = __dirname;
const DATA_DIR = path.join(ROOT, 'data');
const BACKUP_DIR = path.join(os.homedir(), 'Documents', 'Anas HQ Backups');
const FILES_DIR = path.join(DATA_DIR, 'files'); // documents vault: the Mac app copies files here
const KINDS = ['tasks', 'domains', 'subs', 'revenue', 'spend', 'ideas', 'docs', 'goals', 'notes'];

fs.mkdirSync(DATA_DIR, { recursive: true });
fs.mkdirSync(BACKUP_DIR, { recursive: true });
fs.mkdirSync(FILES_DIR, { recursive: true });

const db = new DatabaseSync(path.join(DATA_DIR, 'anashq.db'));
db.exec(`
  PRAGMA journal_mode = WAL;
  CREATE TABLE IF NOT EXISTS records (
    kind TEXT NOT NULL, id TEXT NOT NULL, data TEXT NOT NULL, updated_at TEXT NOT NULL,
    PRIMARY KEY (kind, id)
  );
  CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
  CREATE TABLE IF NOT EXISTS history (
    seq INTEGER PRIMARY KEY AUTOINCREMENT, at TEXT NOT NULL, source TEXT NOT NULL,
    kind TEXT NOT NULL, id TEXT NOT NULL, action TEXT NOT NULL, before TEXT, after TEXT
  );
`);

const q = {
  all: db.prepare('SELECT id, data FROM records WHERE kind = ? ORDER BY id'),
  get: db.prepare('SELECT data FROM records WHERE kind = ? AND id = ?'),
  put: db.prepare('INSERT INTO records (kind, id, data, updated_at) VALUES (?, ?, ?, ?) ON CONFLICT(kind, id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at'),
  del: db.prepare('DELETE FROM records WHERE kind = ? AND id = ?'),
  log: db.prepare('INSERT INTO history (at, source, kind, id, action, before, after) VALUES (?, ?, ?, ?, ?, ?, ?)'),
  hist: db.prepare('SELECT seq, at, source, kind, id, action, before, after FROM history ORDER BY seq DESC LIMIT ?'),
  settings: db.prepare('SELECT key, value FROM settings'),
  setSetting: db.prepare('INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value'),
};

const now = () => new Date().toISOString();
const newId = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 8);

function list(kind) { return q.all.all(kind).map(r => Object.assign(JSON.parse(r.data), { id: r.id })); }
function getOne(kind, id) { const r = q.get.get(kind, id); return r ? Object.assign(JSON.parse(r.data), { id }) : null; }
function settings() { const o = {}; q.settings.all().forEach(r => { o[r.key] = JSON.parse(r.value); }); return o; }
function state() { const o = { settings: settings() }; KINDS.forEach(k => { o[k] = list(k); }); return o; }

function write(kind, id, body, source, merge) {
  const before = getOne(kind, id);
  const rec = Object.assign({}, merge && before ? before : {}, body);
  delete rec.id;
  if (!rec.created) rec.created = before && before.created || now();
  db.exec('BEGIN');
  try {
    q.put.run(kind, id, JSON.stringify(rec), now());
    q.log.run(now(), source, kind, id, before ? 'update' : 'create', before ? JSON.stringify(before) : null, JSON.stringify(rec));
    db.exec('COMMIT');
  } catch (e) { db.exec('ROLLBACK'); throw e; }
  return Object.assign(rec, { id });
}
function remove(kind, id, source) {
  const before = getOne(kind, id);
  if (!before) return false;
  db.exec('BEGIN');
  try {
    q.del.run(kind, id);
    q.log.run(now(), source, kind, id, 'delete', JSON.stringify(before), null);
    db.exec('COMMIT');
  } catch (e) { db.exec('ROLLBACK'); throw e; }
  return true;
}

/* ---------- live updates (Server-Sent Events) ---------- */
const clients = new Set();
function broadcast(msg) {
  const line = `data: ${JSON.stringify(msg)}\n\n`;
  clients.forEach(res => res.write(line));
}
setInterval(() => clients.forEach(res => res.write(': ping\n\n')), 25000);

/* ---------- daily backup ---------- */
function backup() {
  const day = now().slice(0, 10);
  const file = path.join(BACKUP_DIR, `anashq-${day}.json`);
  fs.writeFileSync(file, JSON.stringify(Object.assign({ exportedAt: now() }, state()), null, 2));
}
backup();
setInterval(backup, 6 * 3600 * 1000);

/* ---------- Dodo Payments → revenue ---------- */
// Key lives in data/.env (DODO_API_KEY=...), never in the page.
function envVar(name) {
  try {
    const line = fs.readFileSync(path.join(DATA_DIR, '.env'), 'utf8').split('\n').find(l => l.startsWith(name + '='));
    return line ? line.slice(name.length + 1).trim() : '';
  } catch (e) { return ''; }
}
const dodo = { lastSync: '', lastError: '', added: 0 };
const sleep = ms => new Promise(r => setTimeout(r, ms));
async function dodoGet(key, p) {
  for (let attempt = 0; ; attempt++) {
    const r = await fetch('https://live.dodopayments.com' + p, { headers: { Authorization: 'Bearer ' + key } });
    if (r.status === 429 && attempt < 6) { await sleep(2000 * (attempt + 1)); continue; }
    if (!r.ok) throw new Error(`Dodo ${p} → HTTP ${r.status}`);
    await sleep(150); // stay under Dodo's rate limit
    return r.json();
  }
}
// Dodo brand name → the project name used everywhere else in HQ.
const BRAND_PROJECT = {
  'ScreenRecorder': 'Smooth Recorder', 'SEOMade': 'SEOmade', 'BESTDIRECTORIES': 'bestdirectories',
  'Alternativeto site': 'alternativeto.site', 'BruhGrow Tools': 'bruhgrow',
};
// Amounts are stored in the app's currency; other currencies are converted at that day's ECB rate.
const fxCache = new Map();
async function toBase(amount, cur, day) {
  const base = settings().currency || 'USD';
  if (!amount || cur === base) return amount;
  const k = `${cur}>${base}@${day}`;
  if (!fxCache.has(k)) {
    const r = await fetch(`https://api.frankfurter.app/${day}?from=${cur}&to=${base}`);
    if (!r.ok) throw new Error(`No exchange rate for ${cur} on ${day}`);
    fxCache.set(k, (await r.json()).rates[base]);
  }
  return Math.round(amount * fxCache.get(k) * 100) / 100;
}
async function dodoAll(key, p) {
  const out = [];
  for (let page = 0; page < 100; page++) {
    const d = await dodoGet(key, `${p}?page_size=100&page_number=${page}`);
    const items = d.items || [];
    out.push(...items);
    if (items.length < 100) break;
  }
  return out;
}
const productNames = new Map();
async function productName(key, id) {
  if (!productNames.has(id)) {
    try { productNames.set(id, (await dodoGet(key, '/products/' + id)).name || ''); } catch (e) { productNames.set(id, ''); }
  }
  return productNames.get(id);
}
// Day in local time, matching how the app buckets revenue.
const localDay = iso => { const d = new Date(iso); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; };

let dodoRun = null;
function syncDodo() {
  if (!dodoRun) dodoRun = runDodo().finally(() => { dodoRun = null; });
  return dodoRun;
}
async function runDodo() {
  const key = envVar('DODO_API_KEY');
  if (!key) return;
  try {
    const brands = new Map();
    try { (await dodoGet(key, '/brands')).items?.forEach?.(b => brands.set(b.brand_id, b.name)); } catch (e) {}
    let added = 0;
    for (const p of await dodoAll(key, '/payments')) {
      if (p.status !== 'succeeded' || !p.total_amount) continue; // skip free claims
      const id = 'dodo-' + p.payment_id;
      if (getOne('revenue', id)) continue; // imported already; leave any edits alone
      const detail = await dodoGet(key, '/payments/' + p.payment_id);
      const names = [];
      for (const it of detail.product_cart || []) { const n = await productName(key, it.product_id); if (n) names.push(n); }
      const settled = detail.settlement_amount != null;
      const day = localDay(p.created_at), brand = brands.get(p.brand_id) || '';
      write('revenue', id, {
        amount: await toBase((settled ? detail.settlement_amount : p.total_amount) / 100, settled ? detail.settlement_currency : p.currency, day),
        paidAmount: p.total_amount / 100, paidCurrency: p.currency,
        date: day,
        project: BRAND_PROJECT[brand] || brand,
        source: 'Dodo Payments',
        customer: (p.customer && p.customer.name) || '',
        note: [names.join(', ').replace(/\s+/g, ' ').replace(/ – /g, ' · '), p.subscription_id ? (p.charge_type === 'renewal' ? 'Renewal' : 'Subscription') : ''].filter(Boolean).join(' · '),
        dodoId: p.payment_id,
      }, 'dodo', false);
      added++;
    }
    for (const r of await dodoAll(key, '/refunds')) {
      if (r.status !== 'succeeded') continue;
      const id = 'dodo-' + r.refund_id;
      if (getOne('revenue', id)) continue;
      const orig = getOne('revenue', 'dodo-' + r.payment_id);
      // Refund amounts come in the payment currency; scale like the original payment.
      const ratio = orig && orig.paidAmount ? orig.amount / orig.paidAmount : 1;
      write('revenue', id, {
        amount: orig ? -Math.round((r.amount || 0) * ratio) / 100 : -(await toBase((r.amount || 0) / 100, r.currency, localDay(r.created_at))),
        date: localDay(r.created_at),
        project: orig ? orig.project : '',
        source: 'Dodo Payments',
        customer: orig ? orig.customer : '',
        note: 'Refund' + (r.reason ? ' · ' + r.reason : ''),
        dodoId: r.refund_id,
      }, 'dodo', false);
      added++;
    }
    Object.assign(dodo, { lastSync: now(), lastError: '', added: dodo.added + added });
    if (added) broadcast({ kind: 'revenue', source: 'dodo' });
  } catch (e) {
    dodo.lastError = String(e.message || e);
    console.error('Dodo sync failed:', dodo.lastError);
  }
}
syncDodo();
setInterval(syncDodo, 15 * 60 * 1000);

/* ---------- http ---------- */
function send(res, code, body) {
  res.writeHead(code, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(body));
}
function readJson(req) {
  return new Promise((resolve, reject) => {
    let s = '';
    req.on('data', c => { s += c; if (s.length > 2e6) req.destroy(); });
    req.on('end', () => { try { resolve(s ? JSON.parse(s) : {}); } catch (e) { reject(e); } });
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  // Only answer requests addressed to this machine (blocks DNS-rebinding tricks).
  const host = String(req.headers.host || '').replace(/:\d+$/, '');
  if (!['localhost', '127.0.0.1'].includes(host)) return send(res, 403, { error: 'forbidden' });

  const url = new URL(req.url, 'http://localhost');
  const parts = url.pathname.split('/').filter(Boolean);

  if (!url.pathname.startsWith('/api/')) {
    if (req.method !== 'GET') return send(res, 405, { error: 'method not allowed' });
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
    return res.end(fs.readFileSync(path.join(ROOT, 'public', 'index.html')));
  }

  // Writes must be JSON; browsers can't send that cross-site without a CORS preflight we never approve.
  if (req.method !== 'GET' && !String(req.headers['content-type'] || '').startsWith('application/json')) {
    return send(res, 415, { error: 'send JSON' });
  }
  const source = req.headers['x-source'] === 'claude' ? 'claude' : 'app';

  try {
    const [, a, b] = parts;
    if (req.method === 'GET' && a === 'events') {
      res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-store', Connection: 'keep-alive' });
      res.write(': hi\n\n');
      clients.add(res);
      return req.on('close', () => clients.delete(res));
    }
    if (req.method === 'GET' && a === 'state') return send(res, 200, state());
    if (req.method === 'GET' && a === 'info') return send(res, 200, { filesDir: FILES_DIR });
    if (a === 'dodo' && b === 'sync' && req.method === 'POST') { await syncDodo(); return send(res, 200, dodo); }
    if (a === 'dodo' && req.method === 'GET') return send(res, 200, dodo);
    if (req.method === 'GET' && a === 'history') return send(res, 200, q.hist.all(Math.min(+url.searchParams.get('limit') || 50, 500)));
    if (a === 'settings' && req.method === 'PUT') {
      const body = await readJson(req);
      Object.entries(body).forEach(([k, v]) => q.setSetting.run(k, JSON.stringify(v)));
      broadcast({ kind: 'settings', source });
      return send(res, 200, settings());
    }
    if (!KINDS.includes(a)) return send(res, 404, { error: `unknown kind; use one of ${KINDS.join(', ')}` });

    if (req.method === 'GET' && !b) return send(res, 200, list(a));
    if (req.method === 'GET' && b) { const r = getOne(a, b); return r ? send(res, 200, r) : send(res, 404, { error: 'not found' }); }
    if (req.method === 'POST' && !b) {
      const rec = write(a, newId(), await readJson(req), source, false);
      broadcast({ kind: a, id: rec.id, source });
      return send(res, 201, rec);
    }
    if ((req.method === 'PUT' || req.method === 'PATCH') && b) {
      if (req.method === 'PATCH' && !getOne(a, b)) return send(res, 404, { error: 'not found' });
      const rec = write(a, b, await readJson(req), source, req.method === 'PATCH');
      broadcast({ kind: a, id: b, source });
      return send(res, 200, rec);
    }
    if (req.method === 'DELETE' && b) {
      if (!remove(a, b, source)) return send(res, 404, { error: 'not found' });
      broadcast({ kind: a, id: b, source, deleted: true });
      return send(res, 200, { ok: true });
    }
    send(res, 405, { error: 'method not allowed' });
  } catch (e) {
    send(res, 400, { error: String(e && e.message || e) });
  }
});

server.listen(PORT, '127.0.0.1', () => console.log(`Anas HQ running at http://localhost:${PORT}`));
