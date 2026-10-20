// MCP server (stdio) so Claude can read and update Anas HQ.
// It talks to the local server, so every change shows up in the open app instantly.
'use strict';

const BASE = `http://localhost:${+process.env.ANASHQ_PORT || 4777}/api/`;
const KINDS = ['tasks', 'domains', 'subs', 'revenue', 'spend', 'ideas', 'docs', 'goals', 'notes'];

const FIELDS = `Record fields by kind (dates are YYYY-MM-DD, money is a plain number):
- tasks: title, notes, project, due, pri (urgent|high|normal|low), repeat (none|daily|weekly|monthly|yearly), tags [string], subtasks [{t: text, d: done bool}], done (bool), doneAt (ISO time)
- domains: name (e.g. example.com), project, registrar, dns, expires, cost (per year), autoRenew (bool), parked (bool), notes
- subs: name, plan, project, category, amount, cycle (weekly|monthly|quarterly|yearly), renews (next charge date), status (active|trial|paused|cancelled), notes
- revenue: amount (negative for refunds), date, project, source (e.g. Stripe), customer, note
- spend: personal/business spending per month, entered by hand: month (YYYY-MM), amount, category (e.g. Total, Rent, Food), project, note
- ideas: title, type (weekend|app|article|video), status (idea|planned|done), date (optional, e.g. the weekend), link (URL), notes, project
- docs: important documents (files live in the vault; you can read/update metadata only): title, category (Identity|Finance|Business|Legal|Health|Education|Other), expires (optional), notes, file (stored filename, don't change)
- goals: title, type (goal|habit|promise), status (active|done|dropped), notes, why; goal: target (number), current (number), unit (e.g. $ MRR, articles), due; habit and promise: checks [YYYY-MM-DD days done/kept], since (start date)
- notes: title, body (text), type (note|journal), date (YYYY-MM-DD; one journal entry per day), pinned (bool), tags [string]
"project" is the product name, e.g. "Smooth Recorder". Rows with example:true are placeholders.`;

const kindProp = { type: 'string', enum: KINDS, description: 'tasks, domains, subs (subscriptions), revenue, spend (monthly spending), ideas (weekend plans, apps, article and video ideas), docs (documents vault), goals (goals, habits, promises to self) or notes (notes and daily journal)' };
const TOOLS = [
  {
    name: 'hq_overview',
    description: "Snapshot of Anas HQ: today's and overdue tasks, renewals in the next 30 days, monthly subscription burn, revenue for the last 30 days. Start here.",
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'hq_list',
    description: 'List records of one kind, optionally filtered by project or a search word.\n' + FIELDS,
    inputSchema: {
      type: 'object', required: ['kind'],
      properties: {
        kind: kindProp,
        project: { type: 'string', description: 'Only this project (case-insensitive)' },
        search: { type: 'string', description: 'Only records containing this text' },
        include_done: { type: 'boolean', description: 'tasks only: include completed tasks (default false)' },
      },
    },
  },
  {
    name: 'hq_add',
    description: 'Add a record. Returns it with its new id.\n' + FIELDS,
    inputSchema: {
      type: 'object', required: ['kind', 'fields'],
      properties: { kind: kindProp, fields: { type: 'object', description: 'The record fields' } },
    },
  },
  {
    name: 'hq_update',
    description: 'Change some fields of an existing record; fields you leave out stay as they are. Find the id with hq_list.\n' + FIELDS,
    inputSchema: {
      type: 'object', required: ['kind', 'id', 'fields'],
      properties: { kind: kindProp, id: { type: 'string' }, fields: { type: 'object', description: 'Only the fields to change' } },
    },
  },
  {
    name: 'hq_delete',
    description: 'Delete one record by id. It stays recoverable in hq_history.',
    inputSchema: { type: 'object', required: ['kind', 'id'], properties: { kind: kindProp, id: { type: 'string' } } },
  },
  {
    name: 'hq_history',
    description: 'Recent changes (newest first) with before/after values, from the app and from Claude. Use it to undo a mistake.',
    inputSchema: { type: 'object', properties: { limit: { type: 'number', description: 'Default 20' } } },
  },
];

async function api(method, path, body) {
  let r;
  try {
    r = await fetch(BASE + path, {
      method,
      headers: { 'Content-Type': 'application/json', 'X-Source': 'claude' },
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch (e) {
    throw new Error('The Anas HQ server is not running. Start it with: launchctl kickstart -k gui/$(id -u)/com.anashq.server');
  }
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(data.error || 'HTTP ' + r.status);
  return data;
}

const ymd = d => d.toISOString().slice(0, 10);
const addDays = (s, n) => { const d = new Date(s + 'T00:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return ymd(d); };
function localToday() { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; }
const monthly = s => { const a = +s.amount || 0; return s.cycle === 'yearly' ? a / 12 : s.cycle === 'quarterly' ? a / 3 : s.cycle === 'weekly' ? a * 52 / 12 : a; };
const r2 = n => Math.round(n * 100) / 100;

async function overview() {
  const st = await api('GET', 'state');
  const t0 = localToday(), in30 = addDays(t0, 30), ago30 = addDays(t0, -29);
  const open = st.tasks.filter(t => !t.done);
  const liveSubs = st.subs.filter(s => ['active', 'trial', undefined, ''].includes(s.status));
  return {
    today: t0,
    currency: st.settings.currency || 'USD',
    overdue_tasks: open.filter(t => t.due && t.due < t0),
    due_today: open.filter(t => t.due === t0),
    open_task_count: open.length,
    renewals_next_30_days: [
      ...st.domains.filter(d => !d.parked && d.expires && d.expires <= in30).map(d => ({ kind: 'domains', id: d.id, name: d.name, date: d.expires, cost: d.cost, autoRenew: d.autoRenew })),
      ...liveSubs.filter(s => s.renews && s.renews <= in30).map(s => ({ kind: 'subs', id: s.id, name: s.name, date: s.renews, amount: s.amount, cycle: s.cycle })),
    ].sort((a, b) => a.date.localeCompare(b.date)),
    monthly_burn: r2(liveSubs.reduce((a, s) => a + monthly(s), 0)),
    revenue_last_30_days: r2(st.revenue.filter(e => e.date >= ago30 && e.date <= t0).reduce((a, e) => a + (+e.amount || 0), 0)),
    projects: [...new Set(KINDS.flatMap(k => st[k].map(r => r.project)).filter(Boolean))].sort(),
    example_rows: KINDS.reduce((a, k) => a + st[k].filter(r => r.example).length, 0),
  };
}

async function callTool(name, a) {
  const kindOk = () => { if (!KINDS.includes(a.kind)) throw new Error('kind must be one of ' + KINDS.join(', ')); };
  switch (name) {
    case 'hq_overview': return overview();
    case 'hq_list': {
      kindOk();
      let rows = await api('GET', a.kind);
      if (a.kind === 'tasks' && !a.include_done) rows = rows.filter(t => !t.done);
      if (a.project) rows = rows.filter(r => String(r.project || '').toLowerCase() === a.project.toLowerCase());
      if (a.search) { const s = a.search.toLowerCase(); rows = rows.filter(r => JSON.stringify(r).toLowerCase().includes(s)); }
      return rows;
    }
    case 'hq_add': {
      kindOk();
      const fields = Object.assign({}, a.fields);
      delete fields.example;
      return api('POST', a.kind, fields);
    }
    case 'hq_update': {
      kindOk();
      const fields = Object.assign({}, a.fields);
      if (fields.done === true && !fields.doneAt) fields.doneAt = new Date().toISOString();
      fields.example = false; // editing a placeholder makes it real, same as in the app
      return api('PATCH', `${a.kind}/${encodeURIComponent(a.id)}`, fields);
    }
    case 'hq_delete': kindOk(); return api('DELETE', `${a.kind}/${encodeURIComponent(a.id)}`);
    case 'hq_history': return api('GET', `history?limit=${Math.min(+a.limit || 20, 200)}`);
  }
  throw new Error('Unknown tool ' + name);
}

/* ---------- JSON-RPC over stdio ---------- */
const out = msg => process.stdout.write(JSON.stringify(msg) + '\n');
async function handle(msg) {
  const { id, method, params = {} } = msg;
  if (id === undefined) return; // notification
  try {
    if (method === 'initialize') {
      return out({ jsonrpc: '2.0', id, result: {
        protocolVersion: params.protocolVersion || '2025-06-18',
        capabilities: { tools: {} },
        serverInfo: { name: 'anas-hq', version: '1.0.0' },
        instructions: 'Anas HQ is the owner\'s personal dashboard of tasks, domains, subscriptions and revenue, stored on this Mac. Call hq_overview first. Prefer hq_update over delete+add.',
      } });
    }
    if (method === 'ping') return out({ jsonrpc: '2.0', id, result: {} });
    if (method === 'tools/list') return out({ jsonrpc: '2.0', id, result: { tools: TOOLS } });
    if (method === 'tools/call') {
      try {
        const res = await callTool(params.name, params.arguments || {});
        return out({ jsonrpc: '2.0', id, result: { content: [{ type: 'text', text: JSON.stringify(res, null, 2) }] } });
      } catch (e) {
        return out({ jsonrpc: '2.0', id, result: { isError: true, content: [{ type: 'text', text: e.message }] } });
      }
    }
    out({ jsonrpc: '2.0', id, error: { code: -32601, message: 'Method not found' } });
  } catch (e) {
    out({ jsonrpc: '2.0', id, error: { code: -32603, message: e.message } });
  }
}

let buf = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => {
  buf += chunk;
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
    if (line) { try { handle(JSON.parse(line)); } catch (e) {} }
  }
});
