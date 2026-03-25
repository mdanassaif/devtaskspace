import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';
import { verifySessionToken } from '@/lib/auth';
import { getSupabaseServerClient } from '@/lib/supabase-server';

const ALLOWED_RESOURCES = ['tasks', 'domains', 'subscriptions'] as const;
type Resource = (typeof ALLOWED_RESOURCES)[number];

function isAllowedResource(value: string): value is Resource {
  return ALLOWED_RESOURCES.includes(value as Resource);
}

function getSessionUsername() {
  const token = cookies().get('stacker_auth')?.value;
  const session = verifySessionToken(token);
  return session?.username || null;
}

function tableFor(resource: Resource): 'tasks' | 'domains' | 'subscriptions' {
  return resource;
}

function mapRowsToItems(resource: Resource, rows: Record<string, unknown>[]) {
  if (resource === 'tasks') {
    return rows.map(row => ({
      id: String(row.id),
      createdAt: (row.created_at as string | null) || undefined,
      updatedAt: (row.updated_at as string | null) || undefined,
      title: String(row.title || ''),
      description: (row.description as string | null) || '',
      status: String(row.status || 'todo'),
      priority: String(row.priority || 'medium'),
      category: String(row.category || 'other'),
      deadline: (row.deadline as string | null) || '',
      assignedTo: (row.assigned_to as string | null) || '',
      tags: Array.isArray(row.tags) ? row.tags : [],
      emailNotification: Boolean(row.email_notification),
    }));
  }

  if (resource === 'domains') {
    return rows.map(row => ({
      id: String(row.id),
      createdAt: (row.created_at as string | null) || undefined,
      name: String(row.name || ''),
      expiryDate: String(row.expiry_date || ''),
      registrar: (row.registrar as string | null) || '',
      autoRenew: Boolean(row.auto_renew),
      cost: row.cost === null || row.cost === undefined ? undefined : Number(row.cost),
      notes: (row.notes as string | null) || '',
    }));
  }

  return rows.map(row => ({
    id: String(row.id),
    createdAt: (row.created_at as string | null) || undefined,
    name: String(row.name || ''),
    website: (row.website as string | null) || '',
    price: Number(row.price || 0),
    currency: String(row.currency || 'USD'),
    billingCycle: String(row.billing_cycle || 'monthly'),
    nextBillingDate: String(row.next_billing_date || ''),
    category: String(row.category || 'tool'),
    notes: (row.notes as string | null) || '',
    isActive: Boolean(row.is_active),
  }));
}

function mapItemsToRows(resource: Resource, userId: string, items: Record<string, unknown>[]) {
  if (resource === 'tasks') {
    return items.map(item => ({
      user_id: userId,
      id: String(item.id),
      created_at: item.createdAt ? String(item.createdAt) : null,
      updated_at: item.updatedAt ? String(item.updatedAt) : null,
      title: String(item.title || ''),
      description: item.description ? String(item.description) : null,
      status: String(item.status || 'todo'),
      priority: String(item.priority || 'medium'),
      category: String(item.category || 'other'),
      deadline: item.deadline ? String(item.deadline) : null,
      assigned_to: item.assignedTo ? String(item.assignedTo) : null,
      tags: Array.isArray(item.tags) ? item.tags : [],
      email_notification: Boolean(item.emailNotification),
    }));
  }

  if (resource === 'domains') {
    return items.map(item => ({
      user_id: userId,
      id: String(item.id),
      created_at: item.createdAt ? String(item.createdAt) : null,
      name: String(item.name || ''),
      expiry_date: String(item.expiryDate || ''),
      registrar: item.registrar ? String(item.registrar) : null,
      auto_renew: Boolean(item.autoRenew),
      cost: item.cost === undefined || item.cost === null ? null : Number(item.cost),
      notes: item.notes ? String(item.notes) : null,
    }));
  }

  return items.map(item => ({
    user_id: userId,
    id: String(item.id),
    created_at: item.createdAt ? String(item.createdAt) : null,
    name: String(item.name || ''),
    website: item.website ? String(item.website) : null,
    price: Number(item.price || 0),
    currency: String(item.currency || 'USD'),
    billing_cycle: String(item.billingCycle || 'monthly'),
    next_billing_date: String(item.nextBillingDate || ''),
    category: String(item.category || 'tool'),
    notes: item.notes ? String(item.notes) : null,
    is_active: Boolean(item.isActive),
  }));
}

function dedupeRowsById(
  rows: Array<{ id: string } & Record<string, unknown>>
): Array<{ id: string } & Record<string, unknown>> {
  const byId = new Map<string, { id: string } & Record<string, unknown>>();
  for (const row of rows) {
    const id = String(row.id || '').trim();
    if (!id) continue;
    // Last write wins for duplicate ids.
    byId.set(id, { ...row, id });
  }
  return Array.from(byId.values());
}

function chunkArray<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

/**
 * Full-replace sync without delete-all + insert (avoids duplicate PK when two PUTs overlap).
 * Upsert payload rows, then remove DB rows for this user that are not in the payload.
 */
async function writeRows(
  resource: Resource,
  username: string,
  items: Record<string, unknown>[],
  supabase: ReturnType<typeof getSupabaseServerClient>
) {
  const table = tableFor(resource);

  const sanitized = items.filter(
    row => row && String(row.id ?? '').trim() !== '' && String(row.id) !== 'undefined'
  ) as Record<string, unknown>[];

  const rows = dedupeRowsById(
    mapItemsToRows(resource, username, sanitized) as Array<{ id: string } & Record<string, unknown>>
  );

  if (rows.length === 0) {
    const { error: deleteError } = await supabase.from(table).delete().eq('user_id', username);
    if (deleteError) throw new Error(deleteError.message);
    return;
  }

  const { error: upsertError } = await supabase
    .from(table)
    .upsert(rows, { onConflict: 'user_id,id' });
  if (upsertError) throw new Error(upsertError.message);

  const { data: existing, error: selectError } = await supabase
    .from(table)
    .select('id')
    .eq('user_id', username);
  if (selectError) throw new Error(selectError.message);

  const keepIds = new Set(rows.map(r => r.id));
  const toRemove = (existing ?? [])
    .map(r => String((r as { id: unknown }).id))
    .filter(id => id && !keepIds.has(id));

  for (const chunk of chunkArray(toRemove, 80)) {
    const { error: delChunkError } = await supabase
      .from(table)
      .delete()
      .eq('user_id', username)
      .in('id', chunk);
    if (delChunkError) throw new Error(delChunkError.message);
  }
}

export async function GET(
  _req: Request,
  { params }: { params: { resource: string } }
) {
  const username = getSessionUsername();
  if (!username) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const resource = params.resource;
  if (!isAllowedResource(resource)) {
    return NextResponse.json({ error: 'Unsupported resource' }, { status: 400 });
  }

  try {
    const supabase = getSupabaseServerClient();
    const table = tableFor(resource);
    const { data, error } = await supabase
      .from(table)
      .select('*')
      .eq('user_id', username);

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    const rows = Array.isArray(data) ? (data as Record<string, unknown>[]) : [];
    const items = mapRowsToItems(resource, rows);

    if (items.length === 0) {
      const { data: legacy, error: legacyError } = await supabase
        .from('synced_collections')
        .select('payload')
        .eq('user_id', username)
        .eq('resource', resource)
        .maybeSingle();

      if (!legacyError && Array.isArray(legacy?.payload) && legacy.payload.length > 0) {
        const legacyItems = legacy.payload as Record<string, unknown>[];
        await writeRows(resource, username, legacyItems, supabase);
        return NextResponse.json({ items: legacyItems });
      }
    }

    return NextResponse.json({ items });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Sync read failed';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

export async function PUT(
  req: Request,
  { params }: { params: { resource: string } }
) {
  const username = getSessionUsername();
  if (!username) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const resource = params.resource;
  if (!isAllowedResource(resource)) {
    return NextResponse.json({ error: 'Unsupported resource' }, { status: 400 });
  }

  let body: { items?: unknown };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
  }

  if (!Array.isArray(body.items)) {
    return NextResponse.json({ error: 'items must be an array' }, { status: 400 });
  }

  try {
    const supabase = getSupabaseServerClient();
    await writeRows(resource, username, body.items as Record<string, unknown>[], supabase);

    return NextResponse.json({ success: true });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Sync write failed';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

