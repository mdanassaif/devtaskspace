create table if not exists public.tasks (
  id text not null,
  user_id text not null,
  title text not null,
  description text null,
  status text not null,
  priority text not null,
  category text not null,
  deadline text null,
  assigned_to text null,
  tags jsonb not null default '[]'::jsonb,
  email_notification boolean not null default false,
  created_at text null,
  updated_at text null,
  primary key (user_id, id)
);

create table if not exists public.domains (
  id text not null,
  user_id text not null,
  name text not null,
  expiry_date text not null,
  registrar text null,
  auto_renew boolean not null default false,
  cost numeric null,
  notes text null,
  created_at text null,
  primary key (user_id, id)
);

create table if not exists public.subscriptions (
  id text not null,
  user_id text not null,
  name text not null,
  website text null,
  price numeric not null default 0,
  currency text not null default 'USD',
  billing_cycle text not null,
  next_billing_date text not null,
  category text not null,
  notes text null,
  is_active boolean not null default true,
  created_at text null,
  primary key (user_id, id)
);

create table if not exists public.integration_settings (
  user_id text primary key,
  -- Legacy column; unused by app; left for existing DBs; saves clear it.
  anthropic_api_key_enc text null,
  resend_api_key_enc text null,
  alert_email_enc text null,
  from_email_enc text null,
  updated_at timestamptz not null default now()
);

alter table public.tasks enable row level security;
alter table public.domains enable row level security;
alter table public.subscriptions enable row level security;
alter table public.integration_settings enable row level security;

drop policy if exists "deny_all_tasks" on public.tasks;
create policy "deny_all_tasks"
on public.tasks
for all
using (false)
with check (false);

drop policy if exists "deny_all_domains" on public.domains;
create policy "deny_all_domains"
on public.domains
for all
using (false)
with check (false);

drop policy if exists "deny_all_subscriptions" on public.subscriptions;
create policy "deny_all_subscriptions"
on public.subscriptions
for all
using (false)
with check (false);

drop policy if exists "deny_all_integration_settings" on public.integration_settings;
create policy "deny_all_integration_settings"
on public.integration_settings
for all
using (false)
with check (false);

-- Legacy table kept for backward compatibility/migration fallback.
create table if not exists public.synced_collections (
  user_id text not null,
  resource text not null check (resource in ('tasks', 'domains', 'subscriptions')),
  payload jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, resource)
);

